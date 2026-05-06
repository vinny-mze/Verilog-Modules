`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 09:12:48 AM
// Design Name: 
// Module Name: mag_sq
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



module mag_sq #
(
    parameter WIDTH = 16
)
(
    input  signed [WIDTH-1:0] h_real, h_imag,
    output signed [2*WIDTH-1:0] mag2
);

assign mag2 = (h_real * h_real) + (h_imag * h_imag);

endmodule
