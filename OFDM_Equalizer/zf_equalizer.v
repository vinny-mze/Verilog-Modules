`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 09:42:06 AM
// Design Name: 
// Module Name: zf_equalizer
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

module zf_equalizer #(
    parameter W      = 32,
    parameter FRAC_W = 14,
    parameter ITER   = 4
)(
    input wire clk,
    input wire rst,

    input wire valid_in,

    input wire signed [W-1:0] y_re,
    input wire signed [W-1:0] y_im,
    input wire signed [W-1:0] h_re,
    input wire signed [W-1:0] h_im,

    output reg signed [W-1:0] xhat_re,
    output reg signed [W-1:0] xhat_im,
    output reg valid_out
);

    // ------------------------------------------------------------
    // Fixed-point 1.0
    // ------------------------------------------------------------
    localparam signed [W-1:0] ONE_FIXED = (1 <<< FRAC_W);

    // ------------------------------------------------------------
    // FSM states
    // ------------------------------------------------------------
    localparam IDLE       = 3'd0;
    localparam START_DIV  = 3'd1;
    localparam WAIT_DIV   = 3'd2;
    localparam MULT_OUT   = 3'd3;
    localparam DONE_STATE = 3'd4;

    reg [2:0] state;

    // ------------------------------------------------------------
    // 64-bit temporary multiply signals
    // ------------------------------------------------------------
    reg signed [2*W-1:0] mult_yre_hre;
    reg signed [2*W-1:0] mult_yim_him;
    reg signed [2*W-1:0] mult_yim_hre;
    reg signed [2*W-1:0] mult_yre_him;
    reg signed [2*W-1:0] mult_hre_hre;
    reg signed [2*W-1:0] mult_him_him;

    reg signed [2*W-1:0] num_re_full;
    reg signed [2*W-1:0] num_im_full;
    reg signed [2*W-1:0] mag_sq_full;

    // ------------------------------------------------------------
    // Scaled values back to Q(FRAC_W)
    // ------------------------------------------------------------
    reg signed [W-1:0] num_re_scaled;
    reg signed [W-1:0] num_im_scaled;
    reg signed [W-1:0] mag_sq_scaled;

    // ------------------------------------------------------------
    // Output multiply full precision
    // ------------------------------------------------------------
    reg signed [2*W-1:0] xhat_re_full;
    reg signed [2*W-1:0] xhat_im_full;

    // ------------------------------------------------------------
    // Divider signals
    // ------------------------------------------------------------
    reg start_div;
    wire busy;
    wire done;
    wire div_by_zero;
    wire signed [W-1:0] reciprocal;

    // ------------------------------------------------------------
    // Goldschmidt divider
    //
    // reciprocal = 1 / |H|^2
    // ------------------------------------------------------------
    goldschmidt_fixed_input_divider #(
        .W(W),
        .FRAC_W(FRAC_W),
        .ITER(ITER)
    ) divider_inst (
        .clk(clk),
        .rst(rst),
        .start(start_div),

        .dividend_fix(ONE_FIXED),
        .divisor_fix(mag_sq_scaled),

        .busy(busy),
        .done(done),
        .div_by_zero(div_by_zero),
        .quotient_fix(reciprocal)
    );

    // ------------------------------------------------------------
    // Main FSM
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;

            xhat_re  <= 0;
            xhat_im  <= 0;
            valid_out <= 0;

            start_div <= 0;

            num_re_scaled <= 0;
            num_im_scaled <= 0;
            mag_sq_scaled <= 0;

            xhat_re_full <= 0;
            xhat_im_full <= 0;

            mult_yre_hre <= 0;
            mult_yim_him <= 0;
            mult_yim_hre <= 0;
            mult_yre_him <= 0;
            mult_hre_hre <= 0;
            mult_him_him <= 0;

            num_re_full <= 0;
            num_im_full <= 0;
            mag_sq_full <= 0;
        end else begin

            start_div <= 0;
            valid_out <= 0;

            case (state)

                // ------------------------------------------------
                // IDLE:
                //
                // Capture valid input and compute:
                //
                //   num_re = Y_re*H_re + Y_im*H_im
                //   num_im = Y_im*H_re - Y_re*H_im
                //   mag_sq = H_re^2 + H_im^2
                //
                // Important:
                //   Use blocking assignments here for temporary
                //   internal calculations so scaled values use the
                //   current products, not old registered values.
                // ------------------------------------------------
                IDLE: begin
                    if (valid_in) begin

                        mult_yre_hre = $signed(y_re) * $signed(h_re);
                        mult_yim_him = $signed(y_im) * $signed(h_im);
                        mult_yim_hre = $signed(y_im) * $signed(h_re);
                        mult_yre_him = $signed(y_re) * $signed(h_im);

                        mult_hre_hre = $signed(h_re) * $signed(h_re);
                        mult_him_him = $signed(h_im) * $signed(h_im);

                        num_re_full = mult_yre_hre + mult_yim_him;
                        num_im_full = mult_yim_hre - mult_yre_him;
                        mag_sq_full = mult_hre_hre + mult_him_him;

                        num_re_scaled <= num_re_full >>> FRAC_W;
                        num_im_scaled <= num_im_full >>> FRAC_W;

                        if ((mag_sq_full >>> FRAC_W) == 0)
                            mag_sq_scaled <= {{(W-1){1'b0}}, 1'b1};
                        else
                            mag_sq_scaled <= mag_sq_full >>> FRAC_W;

                        state <= START_DIV;
                    end
                end

                // ------------------------------------------------
                // START_DIV:
                //
                // Start Goldschmidt reciprocal divider.
                // ------------------------------------------------
                START_DIV: begin
                    if (!busy) begin
                        start_div <= 1'b1;
                        state <= WAIT_DIV;
                    end
                end

                // ------------------------------------------------
                // WAIT_DIV:
                //
                // Wait until reciprocal is ready.
                // ------------------------------------------------
                WAIT_DIV: begin
                    if (done) begin
                        state <= MULT_OUT;
                    end
                end

                // ------------------------------------------------
                // MULT_OUT:
                //
                // Multiply numerator by reciprocal.
                //
                // Both num_*_scaled and reciprocal are Q(FRAC_W),
                // so product is Q(2*FRAC_W).
                // ------------------------------------------------
                MULT_OUT: begin
                    xhat_re_full <= $signed(num_re_scaled) * $signed(reciprocal);
                    xhat_im_full <= $signed(num_im_scaled) * $signed(reciprocal);

                    state <= DONE_STATE;
                end

                // ------------------------------------------------
                // DONE_STATE:
                //
                // Scale output back to Q(FRAC_W).
                // ------------------------------------------------
                DONE_STATE: begin
                    xhat_re <= xhat_re_full >>> FRAC_W;
                    xhat_im <= xhat_im_full >>> FRAC_W;

                    valid_out <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
