`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     goldschmidt_fixed_input_divider
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado 
//
// Description:
//   Top-level module that implements fixed-point division using the 
//   Goldschmidt (multiplicative normalization) algorithm.
//
//   This is a complete signed fixed-point divider built by connecting 
//   the sub-modules above. It uses exact multipliers (instead of Mitchell 
//   approximation from Yang's paper) for higher accuracy.
//
//   Latency: Approximately (ITER * 2 + 4) clock cycles.
//////////////////////////////////////////////////////////////////////////////////


module goldschmidt_fixed_input_divider #(
    parameter W      = 32,
    parameter FRAC_W = 14,
    parameter ITER   = 4
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [W-1:0] dividend_fix,
    input wire signed [W-1:0] divisor_fix,
    
    output wire busy,
    output wire done,
    output wire div_by_zero,
    output wire signed [W-1:0] quotient_fix
);

    // -------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------
    wire [W-1:0] dividend_unsigned_fix;
    wire [W-1:0] divisor_unsigned_fix;
    wire sign;

    wire [W-1:0] dividend_norm;
    wire [W-1:0] divisor_norm;
    wire signed [$clog2(W):0] shift_amt;

    wire [W-1:0] dividend_reg;
    wire [W-1:0] divisor_reg;

    wire [W-1:0] factor_reg;
    wire [W-1:0] dividend_pipe_reg;
    wire [W-1:0] divisor_pipe_reg;
    wire [W-1:0] dividend_out_reg;
    wire [W-1:0] divisor_out_reg;

    wire load_init;
    wire load_factor;
    wire load_mult;
    wire load_iter_result;

    // -------------------------------------------------------------------
    // Sub-module instantiations
    // -------------------------------------------------------------------
    fixed_input_sign_converter #(
        .W(W)
    ) u_sign_in (
        .dividend_fix(dividend_fix),
        .divisor_fix(divisor_fix),
        .dividend_unsigned_fix(dividend_unsigned_fix),
        .divisor_unsigned_fix(divisor_unsigned_fix),
        .sign(sign)
    );

    assign div_by_zero = (divisor_fix == 0);

    normalization_shifter #(
        .W(W),
        .FRAC_W(FRAC_W)
    ) u_norm (
        .dividend_in(dividend_unsigned_fix),
        .divisor_in(divisor_unsigned_fix),
        .dividend_fix(dividend_norm),
        .divisor_fix(divisor_norm),
        .shift_amt(shift_amt)
    );

    data_register #(
        .W(W)
    ) u_reg (
        .clk(clk),
        .rst(rst),
        .load_init(load_init),
        .load_iter_result(load_iter_result),
        .dividend_init(dividend_norm),
        .divisor_init(divisor_norm),
        .dividend_next(dividend_out_reg),
        .divisor_next(divisor_out_reg),
        .dividend_reg(dividend_reg),
        .divisor_reg(divisor_reg)
    );

    goldschmidt_iter_unit #(
        .W(W),
        .FRAC_W(FRAC_W)
    ) u_iter_pipe (
        .clk(clk),
        .rst(rst),
        .load_factor(load_factor),
        .load_mult(load_mult),
        .dividend_in(dividend_reg),
        .divisor_in(divisor_reg),
        .factor_reg(factor_reg),
        .dividend_pipe_reg(dividend_pipe_reg),
        .divisor_pipe_reg(divisor_pipe_reg),
        .dividend_out_reg(dividend_out_reg),
        .divisor_out_reg(divisor_out_reg)
    );

    fsm_controller #(
        .ITER(ITER)
    ) u_fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .div_by_zero(div_by_zero),
        .busy(busy),
        .load_init(load_init),
        .load_factor(load_factor),
        .load_mult(load_mult),
        .load_iter_result(load_iter_result),
        .done(done)
    );

    output_sign_converter #(
        .W(W)
    ) u_sign_out (
        .quotient_unsigned(dividend_reg),   // Final result after iterations
        .sign(sign),
        .quotient_signed(quotient_fix)
    );

endmodule