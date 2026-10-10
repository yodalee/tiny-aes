
// ControlFsm
//
// The centralized control state machine.

typedef enum logic [3:0] {
    kLoad,   // Include substate of LoadData, LoadKey, LoadExtraKey
    kOutput
} State;

module ControlFsm (
	input  logic       clk,
	input  logic       rst_n,
    // CSR
	input  logic       r_dec,
	input  logic [1:0] r_level,
    // data input
	input  logic       i_valid,
	output logic       i_ready,
    // data output
	input  logic       o_ready,
	output logic       o_valid,
    // control signals of AesState
	output logic       c_srow0,
	output logic       c_srow1,
	output logic       c_srow2,
	output logic       c_isrow0,
	output logic       c_isrow1,
	output logic       c_mixcol,
    // control signals of KeyExpansion
	output logic       c_ke0,
	output logic       c_ke1,
	output logic       c_ke2,
	output logic       c_kxor,
	output logic       c_ikxor,
    // Control signals of Sbox
	output logic       c_add,
    // Rc LUT
	output logic [7:0] c_rc_idx
);

// The configuration related constant
logic [5:0] load_end;
always_comb begin
case (r_level)
    2'b00 : load_end = 6'd32; // 16 key + 16 data
    2'b01 : load_end = 6'd40; // 24 key + 16 data
    2'b10 : load_end = 6'd48; // 32 key + 16 data
    2'b11 : load_end = 6'd32; // Use enc128 as default
endcase
end

logic [3:0] round_end;
always_comb begin
case (r_level)
    2'b00 : round_end = 4'd10;
    2'b01 : round_end = 4'd12;
    2'b10 : round_end = 4'd14;
    2'b11 : round_end = 4'd10; // Use enc128 as default
endcase
end

// The state_counter
// Probably the most important variable in this module
// All the control signal are hard-wire to assert in specific cycle according to state_counter
// Also, the input/output states use the counter to count i_valid and o_ready.

logic [5:0] state_counter;
logic change_state;
// Load counter and limit
always_ff @( posedge clk or negedge rst_n ) begin
if (!rst_n) begin
    state_counter <= 'd0;
end else begin
    if (change_state) begin
        state_counter <= 'd0;
    end
    if (state == kLoad && i_valid) begin
        state_counter <= state_counter + 1;
    end
    else if (state == kOutput && o_ready) begin
        state_counter <= state_counter + 1;
    end
    else begin
        state_counter <= state_counter + 1;
    end
end
end

State state;

always_ff @( posedge clk or negedge rst_n ) begin
if (!rst_n) begin
    state <= kLoad;
end
else begin
    state <= state;
end
end

logic [3:0] round;
always_ff @( posedge clk or negedge rst_n ) begin
if (!rst_n) begin
    round <= 'b0;
end else begin
    if (change_state) begin
        round <= round + 1;
    end
end
end

always_comb begin
	i_ready = 1'b1;
	o_valid = 1'b0;
	c_srow0 = 1'b0;
	c_srow1 = 1'b0;
	c_srow2 = 1'b0;
	c_isrow0 = 1'b0;
	c_isrow1 = 1'b0;
	c_mixcol = 1'b0;
	c_ke0 = 1'b0;
	c_ke1 = 1'b0;
	c_ke2 = 1'b0;
	c_kxor = 1'b0;
	c_ikxor = 1'b0;
	c_add = 1'b0;
	c_rc_idx = 8'b0;
end

endmodule