`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     fixed_mult_exact
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado 
// 
// Description:
//   Exact fixed-point multiplier with rounding.
//   Multiplies two W-bit fixed-point numbers and returns a W-bit result.
//
//   Rounding is performed by adding 0.5 ulp before truncating the fractional part.
//   This module is used instead of the approximate Mitchell multiplier from Yang's paper.
//////////////////////////////////////////////////////////////////////////////////


module fixed_mult_exact #(
    parameter W      = 32,
    parameter FRAC_W = 16
)(
    input wire [W-1:0] a,
    input wire [W-1:0] b,
    output wire [W-1:0] p
);
    wire [2*W-1:0] prod_full;
    wire [2*W-1:0] prod_rounded;

    assign prod_full = a * b;

    // Add 0.5 LSB for rounding
    assign prod_rounded = prod_full + ({{(2*W - FRAC_W){1'b0}}, 1'b1, {(FRAC_W-1){1'b0}}});

    // Truncate back to W bits
    assign p = prod_rounded >> FRAC_W;
endmodule