"""Optimize 8 by 8 GF(2) matrices and emit SystemVerilog.

``matrix`` is a sequence of eight bytes.  Byte *c* is column *c* of the
matrix, with its most-significant bit being row zero.  Therefore, for an
input byte ``x``, matrix column zero multiplies ``x[7]`` and output row zero
is assigned to ``y[7]``.  This is the same column-major representation used
by the basis-conversion matrices in :mod:`gf2`.

The optimizer is intentionally a linear (XOR-only) optimizer.  It discovers
pairs of signals used by two or more output equations and materializes those
pairs once as temporary wires.  This gives a deterministic, useful common
subexpression extraction without requiring external packages.
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from itertools import combinations
from typing import Sequence


# Kept as convenient examples for the AES basis-conversion matrices.
X2A = [0x64, 0x78, 0x6E, 0x8C, 0x68, 0x29, 0xDE, 0x60]
A2X = [0x98, 0xF3, 0xF2, 0x48, 0x09, 0x81, 0xA9, 0xFF]
X2S = [0x58, 0x2D, 0x9E, 0x0B, 0xDC, 0x04, 0x03, 0x24]
S2X = [0x8C, 0x79, 0x05, 0xEB, 0x12, 0x04, 0x51, 0x53]


@dataclass(frozen=True)
class XorNode:
    """A signal produced by a single two-input XOR gate."""

    name: str
    left: str
    right: str
    mask: int


@dataclass(frozen=True)
class OptimizedTransform:
    """An XOR network implementing one 8 by 8 binary matrix."""

    matrix: tuple[int, ...]
    nodes: tuple[XorNode, ...]
    outputs: tuple[tuple[str, ...], ...]  # output rows, most significant first
    xor_count: int

    def evaluate(self, value: int) -> int:
        """Evaluate the generated network; useful for independent checking."""
        if not 0 <= value <= 0xFF:
            raise ValueError("value must be an 8-bit integer")
        signals = {f"x{i}": (value >> (7 - i)) & 1 for i in range(8)}
        for node in self.nodes:
            signals[node.name] = signals[node.left] ^ signals[node.right]
        result = 0
        for row, terms in enumerate(self.outputs):
            bit = 0
            for term in terms:
                bit ^= signals[term]
            result |= bit << (7 - row)
        return result


def _validate_matrix(matrix: Sequence[int]) -> tuple[int, ...]:
    if len(matrix) != 8:
        raise ValueError("matrix must contain exactly 8 bytes (one per column)")
    result = tuple(matrix)
    if any(not isinstance(value, int) or not 0 <= value <= 0xFF for value in result):
        raise ValueError("every matrix element must be an integer in range 0..255")
    return result


def matrix_to_output_masks(matrix: Sequence[int]) -> tuple[int, ...]:
    """Return one input-bit mask per output row (rows are MSB first)."""
    columns = _validate_matrix(matrix)
    return tuple(
        sum(((columns[column] >> (7 - row)) & 1) << column for column in range(8))
        for row in range(8)
    )


def apply_matrix(matrix: Sequence[int], value: int) -> int:
    """Reference implementation of ``Y = M X`` over GF(2)."""
    if not isinstance(value, int) or not 0 <= value <= 0xFF:
        raise ValueError("value must be an 8-bit integer")
    input_mask = sum(((value >> (7 - col)) & 1) << col for col in range(8))
    result = 0
    for row, mask in enumerate(matrix_to_output_masks(matrix)):
        result |= ((mask & input_mask).bit_count() & 1) << (7 - row)
    return result


def optimize_matrix(matrix: Sequence[int]) -> OptimizedTransform:
    """Extract common XOR pairs from an 8 by 8 GF(2) matrix.

    Every output begins as an XOR of input signals.  A pair that appears in
    at least two remaining equations saves one XOR gate overall, so it is
    emitted as a temporary and substituted everywhere it occurs.  Ties are
    resolved by signal creation order, making generated RTL reproducible.
    """
    columns = _validate_matrix(matrix)
    masks = matrix_to_output_masks(columns)
    expressions: list[list[str]] = [
        [f"x{column}" for column in range(8) if mask & (1 << column)]
        for mask in masks
    ]
    signal_masks = {f"x{i}": 1 << i for i in range(8)}
    nodes: list[XorNode] = []

    while True:
        occurrences: Counter[tuple[str, str]] = Counter()
        for expression in expressions:
            occurrences.update(combinations(expression, 2))
        candidates = [
            (count, pair)
            for pair, count in occurrences.items()
            if count >= 2
            and (signal_masks[pair[0]] ^ signal_masks[pair[1]]) not in signal_masks.values()
        ]
        if not candidates:
            break

        # Counter preserves insertion order; max therefore gives deterministic
        # first-seen tie breaking after the count comparison.
        _, (left, right) = max(candidates, key=lambda item: item[0])
        name = f"t{len(nodes)}"
        mask = signal_masks[left] ^ signal_masks[right]
        signal_masks[name] = mask
        nodes.append(XorNode(name, left, right, mask))
        for expression in expressions:
            if left in expression and right in expression:
                expression.remove(left)
                expression.remove(right)
                expression.append(name)

    xor_count = len(nodes) + sum(max(0, len(expression) - 1) for expression in expressions)
    return OptimizedTransform(columns, tuple(nodes), tuple(tuple(expr) for expr in expressions), xor_count)


def emit_systemverilog(
    transform: OptimizedTransform, function_name: str = "linear_transform"
) -> str:
    """Emit a synthesizable SystemVerilog function for ``transform``."""
    if not function_name.isidentifier():
        raise ValueError("function_name must be a valid SystemVerilog identifier")

    def rtl_signal(name: str) -> str:
        """Translate the optimizer's MSB-first input names to SV indexing."""
        if name.startswith("x") and name[1:].isdigit():
            index = int(name[1:])
            if 0 <= index < 8:
                return f"x[{7 - index}]"
        return name

    lines = [
        f"// {transform.xor_count} two-input XOR gates after common-subexpression extraction.",
        f"function automatic logic [7:0] {function_name}(input logic [7:0] x);",
    ]
    if transform.nodes:
        lines.append("  logic " + ", ".join(node.name for node in transform.nodes) + ";")
    lines.append("  begin")
    for node in transform.nodes:
        lines.append(
            f"    {node.name} = {rtl_signal(node.left)} ^ {rtl_signal(node.right)};"
        )
    for row, terms in enumerate(transform.outputs):
        destination = f"{function_name}[{7 - row}]"
        expression = " ^ ".join(rtl_signal(term) for term in terms) if terms else "1'b0"
        lines.append(f"    {destination} = {expression};")
    lines.extend(["  end", "endfunction"])
    return "\n".join(lines)


def main(matrix: Sequence[int], function_name: str = "linear_transform") -> str:
    """Optimize ``matrix`` and return its SystemVerilog function source."""
    return emit_systemverilog(optimize_matrix(matrix), function_name)


def _parse_matrix(text: str) -> list[int]:
    values = [value.strip() for value in text.split(",")]
    try:
        return [int(value, 0) for value in values]
    except ValueError as exc:
        raise argparse.ArgumentTypeError("matrix bytes must be comma-separated integers") from exc


def cli(argv: Sequence[str] | None = None) -> int:
    """Command-line entry point, e.g. ``--matrix 0x64,0x78,...``."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", required=True, type=_parse_matrix,
                        help="eight comma-separated bytes; accepts 0x notation")
    parser.add_argument("--function-name", default="linear_transform")
    args = parser.parse_args(argv)
    print(main(args.matrix, args.function_name))
    return 0


if __name__ == "__main__":
    raise SystemExit(cli())
