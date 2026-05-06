`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     goldschmidt_iter_unit
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado
// 
// Description:
//   This module performs one iteration of the Goldschmidt division algorithm.
//
//   One iteration consists of:
//     1. Compute factor = 2.0 - current_divisor
//     2. Update dividend = dividend × factor
//     3. Update divisor  = divisor  × factor
//
//   The unit is split into two pipeline stages controlled by the FSM:
//     - load_factor : compute factor and pipeline inputs
//     - load_mult   : perform multiplications and register results
//////////////////////////////////////////////////////////////////////////////////

module goldschmidt_iter_unit #(
    parameter W      = 32,
    parameter FRAC_W = 16
)(
    input wire clk,
    input wire rst,
    input wire load_factor,      // Stage 1 enable
    input wire load_mult,        // Stage 2 enable
    
    input wire [W-1:0] dividend_in,
    input wire [W-1:0] divisor_in,
    
    output reg [W-1:0] factor_reg,
    output reg [W-1:0] dividend_pipe_reg,
    output reg [W-1:0] divisor_pipe_reg,
    output reg [W-1:0] dividend_out_reg,
    output reg [W-1:0] divisor_out_reg
);
    // Constant 2.0 in fixed-point (1 << (FRAC_W + 1))
    localparam [W-1:0] TWO_FIX = ({{(W-1){1'b0}}, 1'b1} << (FRAC_W + 1));

    wire [W-1:0] factor_next;
    wire [W-1:0] dividend_mult_wire;
    wire [W-1:0] divisor_mult_wire;

    // Compute next factor = 2.0 - divisor
    assign factor_next = TWO_FIX - divisor_in;

    // Exact multipliers (replaces Mitchell approximation from the paper)
    fixed_mult_exact #(
        .W(W),
        .FRAC_W(FRAC_W)
    ) u_mult_dividend (
        .a(dividend_pipe_reg),
        .b(factor_reg),
        .p(dividend_mult_wire)
    );

    fixed_mult_exact #(
        .W(W),
        .FRAC_W(FRAC_W)
    ) u_mult_divisor (
        .a(divisor_pipe_reg),
        .b(factor_reg),
        .p(divisor_mult_wire)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            factor_reg       <= 0;
            dividend_pipe_reg <= 0;
            divisor_pipe_reg  <= 0;
            dividend_out_reg  <= 0;
            divisor_out_reg   <= 0;
        end
        else begin
            // Stage 1: Compute factor and pipeline current values
            if (load_factor) begin
                factor_reg       <= factor_next;
                dividend_pipe_reg <= dividend_in;
                divisor_pipe_reg  <= divisor_in;
            end

            // Stage 2: Register the multiplication results
            if (load_mult) begin
                dividend_out_reg <= dividend_mult_wire;
                divisor_out_reg  <= divisor_mult_wire;
            end
        end
    end
endmodule