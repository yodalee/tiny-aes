ControlFsm
==========

# Overall behavior

The state machines is listed below, for each operation, it should go through:
1. loaddata
2. loadkey
3. for decryption from a first-round key, expand the key to the last-round key
4. init
5. some round states which may repeat and bounce back in state
6. final
7. output

There will be following states:

| round name | cycles | description                               |
|-----------:|-------:|------------------------------------------:|
| loaddata   |        | receive 16 cycle of input handshake       |
| loadkey    |        | receive 16/24/32 cycle of input handshake |
| d128key    |        | 10 key expansions, each followed by 12 key XOR cycles |
| d192key    |        | 7 iterations of 20 XOR + 4 key-only cycles; final iteration of 12 XOR + 4 key-only cycles |
| d256key1  |        | 7 ke0/ke1 expansions, each followed by 12 key XOR cycles |
| d256key2  |        | 6 ke2 expansions, each followed by 12 key XOR cycles |
| e128init   | 16     |                                           |
| e128round  | 23     | repeat 10 times                           |
| efinal     | 20     | shared by AES-128, AES-192, and AES-256    |
| d128init   | 20     |                                           |
| d128round  | 31     | repeat 10 times                           |
| d128final  | 16     |                                           |
| e192init   | 23     | Different to paper                        |
| e192round1 | 20     | round 1                                   |
| e192round2 | 23     | round 2, 5, 8, 11                         |
| e192round3 | 23     | round 3, 6, 9                             |
| e192round4 | 27     | round 4, 7, 10                            |
| d192init   | 27     |                                           |
| d192round1 | 35     | round 1, 4, 7, 10                         |
| d192round2 | 31     | round 2, 5, 8, 11                         |
| d192round3 | 31     | round 3, 6, 9                             |
| d192final  | 16     |                                           |
| e256init   | 52     |                                           |
| e256round1 | 23     | round 1, 2                                |
| e256round3 | 23     | round 3, 5, 7, 9, 11, 13                  |
| e256round4 | 23     | round 4, 6, 8, 10, 12                     |
| d256init   | 35     |                                           |
| d256round1 | 31     | round 1, 3, 5, 7, 9, 11                   |
| d256round2 | 31     | round 2, 4, 6, 8, 10, 12                  |
| d256final  | 16     |                                           |
| output     |        | receive 16 cycle of output handshake      |


# Implementation details
For each states, create a lookup table with width identical to all control signals,
and depth identical to cycles counts of the state

```
localparam CtrlSignals_t kE128initLut [0:kE128InitCycles - 1] = '{
    '{c_srow: 3'b111, default: '0}
    '{c_srow: 3'b110, default: '0}
    // .....
};
```

By this, we can hard-coded the control signal used in that state

`c_srow[2:0]` independently enables state rows 1, 2, and 3 (bits 0, 1,
and 2). The forward ShiftRows sequence is `3'b111`, `3'b110`, `3'b100`
(7, 6, 4); inverse ShiftRows uses `3'b111`, `3'b011`, `3'b001` (7, 3, 1).

# Some difference to the paper:
Below are some setting that is different to the paper

* E192init: since we first receive data and key into state and key buffer. There is no need for
extra 8 cycles of load and 16 cycles to rotate the fresh key to the front.
