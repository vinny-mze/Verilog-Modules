`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     normalization_shifter
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado
//
// Description:
//   This module normalizes the divisor so that its leading '1' is aligned 
//   to bit position (FRAC_W - 1). This makes the divisor close to 1.0 in 
//   fixed-point representation, which is essential for fast convergence 
//   in the Goldschmidt algorithm.
//
//   Both dividend and divisor are shifted by the same amount.
//   The shift amount is also output for potential external use.
//////////////////////////////////////////////////////////////////////////////////

module normalization_shifter #(
    parameter W      = 32,
    parameter FRAC_W = 16
)(
    input wire [W-1:0] dividend_in,
    input wire [W-1:0] divisor_in,
    
    output reg [W-1:0] dividend_fix,
    output reg [W-1:0] divisor_fix,
    output reg signed [$clog2(W):0] shift_amt   // signed shift value applied
);
    integer i;
    integer lead_pos;     // position of leading 1 in divisor
    integer target_pos;   // desired position = FRAC_W - 1
    integer s;

    always @(*) begin
        dividend_fix = 0;
        divisor_fix  = 0;
        shift_amt    = 0;
        lead_pos     = -1;
        target_pos   = FRAC_W - 1;

        // Find highest set bit (leading 1) in divisor_in
        for (i = W-1; i >= 0; i = i - 1) begin
            if ((lead_pos == -1) && divisor_in[i]) begin
                lead_pos = i;
            end
        end

        if (lead_pos == -1) begin
            // Divisor is zero → no normalization
            dividend_fix = 0;
            divisor_fix  = 0;
            shift_amt    = 0;
        end else begin
            s = target_pos - lead_pos;          // required shift amount
            shift_amt = s;

            if (s >= 0) begin
                dividend_fix = dividend_in << s;
                divisor_fix  = divisor_in  << s;
            end else begin
                dividend_fix = dividend_in >> (-s);
                divisor_fix  = divisor_in  >> (-s);
            end
        end
    end
endmodule
