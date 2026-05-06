`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     fixed_input_sign_converter
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado
//
// Description:
//   This module converts signed fixed-point inputs (dividend and divisor) 
//   into unsigned equivalents and extracts the result sign bit.
//
//   Operation:
//     - If input is negative, it performs two's complement negation.
//     - Result sign = dividend_sign XOR divisor_sign.
//
//   This is the first stage of signed division.
//////////////////////////////////////////////////////////////////////////////////


module fixed_input_sign_converter #(
    parameter W = 32
)(
    input wire signed [W-1:0] dividend_fix,
    input wire signed [W-1:0] divisor_fix,
    
    output wire [W-1:0] dividend_unsigned_fix,
    output wire [W-1:0] divisor_unsigned_fix,
    output wire sign                     // 1 = negative quotient
);
    // Convert to unsigned using two's complement negation if negative
    assign dividend_unsigned_fix = dividend_fix[W-1] ? (~dividend_fix + 1'b1) : dividend_fix;
    assign divisor_unsigned_fix  = divisor_fix[W-1]  ? (~divisor_fix  + 1'b1) : divisor_fix;

    // Sign of result = XOR of input signs
    assign sign = dividend_fix[W-1] ^ divisor_fix[W-1];
endmodule