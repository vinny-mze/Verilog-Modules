`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     data_register
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado 
// 
// Description:
//   This is a simple register file that stores the current dividend and 
//   divisor values during the division process.
//
//   It supports two load modes:
//     - load_init:       loads initial normalized values
//     - load_iter_result: loads updated values from the current iteration
//////////////////////////////////////////////////////////////////////////////////

module data_register #(
    parameter W = 32
)(
    input wire clk,
    input wire rst,
    input wire load_init,
    input wire load_iter_result,
    input wire [W-1:0] dividend_init,
    input wire [W-1:0] divisor_init,
    input wire [W-1:0] dividend_next,
    input wire [W-1:0] divisor_next,
    
    output reg [W-1:0] dividend_reg,
    output reg [W-1:0] divisor_reg
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dividend_reg <= 0;
            divisor_reg  <= 0;
        end
        else if (load_init) begin
            dividend_reg <= dividend_init;
            divisor_reg  <= divisor_init;
        end
        else if (load_iter_result) begin
            dividend_reg <= dividend_next;
            divisor_reg  <= divisor_next;
        end
    end
endmodule