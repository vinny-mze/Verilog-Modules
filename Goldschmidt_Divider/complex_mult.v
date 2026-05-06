`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 09:14:04 AM
// Design Name: 
// Module Name: complex_mult
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module complex_mult #
(
    parameter WIDTH = 16
)
(
    input  signed [WIDTH-1:0] a_real, a_imag,
    input  signed [WIDTH-1:0] b_real, b_imag,
    output signed [2*WIDTH-1:0] p_real, p_imag
);

assign p_real = (a_real * b_real) - (a_imag * b_imag);
assign p_im = (a_real * b_imag) + (a_imag * b_real);

endmodule

