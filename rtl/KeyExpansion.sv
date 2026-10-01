
module KeyExpansion (
    input       clk,
    input       rst_n,
    // general input of key data, from outside or key00, 20, 60
    input  byte i_key,
    // output from the register data
    output byte o_key00,
    output byte o_key20,
    output byte o_key60,
    output byte o_key70,
    output byte o_key71
);

// wires for register output
byte key00, key01, key02, key03;
byte key10, key11, key12, key13;
byte key20, key21, key22, key23;
byte key30, key31, key32, key33;
byte key40, key41, key42, key43;
byte key50, key51, key52, key53;
byte key60, key61, key62, key63;
byte key70, key71, key72, key73;

// column 0
EnableFF    i_key00 ( .clk(clk), .rst_n(rst_n), .en(), .d(key01), .q(key00) );
EnableFF    i_key01 ( .clk(clk), .rst_n(rst_n), .en(), .d(key02), .q(key01) );
EnableFF    i_key02 ( .clk(clk), .rst_n(rst_n), .en(), .d(key03), .q(key02) );
MuxEnableFF i_key03 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(),
    .d0(key10), .d1(), .q(key03)
);

// column 1
EnableFF    i_key10 ( .clk(clk), .rst_n(rst_n), .en(), .d(key11), .q(key10) );
EnableFF    i_key11 ( .clk(clk), .rst_n(rst_n), .en(), .d(key12), .q(key11) );
EnableFF    i_key12 ( .clk(clk), .rst_n(rst_n), .en(), .d(key13), .q(key12) );
EnableFF    i_key13 ( .clk(clk), .rst_n(rst_n), .en(), .d(), .q(key13) );

// column 2
EnableFF    i_key20 ( .clk(clk), .rst_n(rst_n), .en(), .d(key21), .q(key20) );
EnableFF    i_key21 ( .clk(clk), .rst_n(rst_n), .en(), .d(key22), .q(key21) );
EnableFF    i_key22 ( .clk(clk), .rst_n(rst_n), .en(), .d(key23), .q(key22) );
EnableFF    i_key23 ( .clk(clk), .rst_n(rst_n), .en(), .d(), .q(key23) );

// column 3
EnableFF    i_key30 ( .clk(clk), .rst_n(rst_n), .en(), .d(key31), .q(key30) );
EnableFF    i_key31 ( .clk(clk), .rst_n(rst_n), .en(), .d(key32), .q(key31) );
EnableFF    i_key32 ( .clk(clk), .rst_n(rst_n), .en(), .d(key33), .q(key32) );
EnableFF    i_key33 ( .clk(clk), .rst_n(rst_n), .en(), .d(), .q(key33) );

// column 4
EnableFF    i_key40 ( .clk(clk), .rst_n(rst_n), .en(), .d(key41), .q(key40) );
EnableFF    i_key41 ( .clk(clk), .rst_n(rst_n), .en(), .d(key42), .q(key41) );
EnableFF    i_key42 ( .clk(clk), .rst_n(rst_n), .en(), .d(key43), .q(key42) );
EnableFF    i_key43 ( .clk(clk), .rst_n(rst_n), .en(), .d(key50), .q(key43) );

// column 5
EnableFF    i_key50 ( .clk(clk), .rst_n(rst_n), .en(), .d(key51), .q(key50) );
EnableFF    i_key51 ( .clk(clk), .rst_n(rst_n), .en(), .d(key52), .q(key51) );
EnableFF    i_key52 ( .clk(clk), .rst_n(rst_n), .en(), .d(key53), .q(key52) );
EnableFF    i_key53 ( .clk(clk), .rst_n(rst_n), .en(), .d(key60), .q(key53) );

// column 6
EnableFF    i_key60 ( .clk(clk), .rst_n(rst_n), .en(), .d(key61), .q(key60) );
EnableFF    i_key61 ( .clk(clk), .rst_n(rst_n), .en(), .d(key62), .q(key61) );
EnableFF    i_key62 ( .clk(clk), .rst_n(rst_n), .en(), .d(key63), .q(key62) );
EnableFF    i_key63 ( .clk(clk), .rst_n(rst_n), .en(), .d(), .q(key63) );

// column 7
EnableFF    i_key70 ( .clk(clk), .rst_n(rst_n), .en(), .d(key71), .q(key70) );
EnableFF    i_key71 ( .clk(clk), .rst_n(rst_n), .en(), .d(key72), .q(key71) );
EnableFF    i_key72 ( .clk(clk), .rst_n(rst_n), .en(), .d(key73), .q(key72) );
EnableFF    i_key73 ( .clk(clk), .rst_n(rst_n), .en(), .d(), .q(key73) );

endmodule