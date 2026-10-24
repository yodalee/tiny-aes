ControlFsm
==========

# Overall behavior

The state machines is listed below, for each operation, it should go through:
1. loaddata
2. loadkey
3. init
4. some round states which may repeat and bounce back in state
5. final
6. output

There will be following states:

| round name | cycles | description                               |
|-----------:|-------:|------------------------------------------:|
| loaddata   |        | receive 16 cycle of input handshake       |
| loadkey    |        | receive 16/24/32 cycle of input handshake |
| e128init   | 16     |                                           |
| e128round  | 23     | repeat 10 times                           |
| e128final  | 20     |                                           |
| d128init   | 20     |                                           |
| d128round  | 31     | repeat 10 times                           |
| d128final  | 16     |                                           |
| e192init   | 40     |                                           |
| e192round1 | 20     | round 1                                   |
| e192round2 | 23     | round 2, 5, 8, 11                         |
| e192round3 | 23     | round 3, 6, 9                             |
| e192round4 | 27     | round 4, 7, 10                            |
| e192final  | 20     |                                           |
| d192init   | 27     |                                           |
| d192round1 | 35     | round 1, 4, 7, 10                         |
| d192round2 | 31     | round 2, 5, 8, 11                         |
| d192round3 | 31     | round 3, 6, 9                             |
| d192final  | 16     |                                           |
| e256init   | 52     |                                           |
| e256round1 | 23     | round 1, 2                                |
| e256round3 | 23     | round 3, 5, 7, 9, 11, 13                  |
| e256round4 | 23     | round 4, 6, 8, 10, 12                     |
| e256final  | 20     |                                           |
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
    '{c_srow0: 1'b1, default: '0}
    '{c_srow1: 1'b1, default: '0}
    // .....
};
```

By this, we can hard-coded the control signal used in that state