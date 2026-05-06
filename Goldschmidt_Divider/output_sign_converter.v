`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     output_sign_converter
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado 
// 
// Description:
//   Restores the original sign to the final unsigned quotient.
//   If 'sign' is 1, performs two's complement negation.
//////////////////////////////////////////////////////////////////////////////////
module output_sign_converter #(
    parameter W = 32
)(
    input wire [W-1:0] quotient_unsigned,
    input wire sign,
    output wire signed [W-1:0] quotient_signed
);
    assign quotient_signed = sign ? (-$signed(quotient_unsigned)) 
                                  :  $signed(quotient_unsigned);
endmodule
