`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////////
// Company:         
// Engineer:        
// 
// Module Name:     cordic_rect_to_polar
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado
//
// Description: 
//   This module converts rectangular (cartesian) coordinates (x, y) to 
//   polar form (magnitude and phase) using the CORDIC algorithm in 
//   vectoring mode.
//
//   It computes:
//     - Magnitude = sqrt(x² + y²)
//     - Angle     = atan2(y, x)  in the full range [-π, +π]
//   Features:
//     - Built-in quadrant correction
//     - Pre-scaled 1/K gain compensation for accurate magnitude
//     - 16 CORDIC iterations (unrolled)
//
//   Note: This is a multi-cycle implementation (one sample every ~17 clocks).
//         The valid_in / valid_out handshake allows back-to-back operation.
//
//////////////////////////////////////////////////////////////////////////////////

module cordic_rect_to_polar #(
    parameter WIDTH = 20,      // I/O width
    parameter FRAC  = 17,      // Fractional bits
    parameter ITER  = 16
)(
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire signed [WIDTH-1:0] x_in,
    input wire signed [WIDTH-1:0] y_in,

    output reg signed [WIDTH-1:0] angle_out,
    output reg signed [WIDTH-1:0] mag_out,   // 
    output reg valid_out
);

    // Internal width (guard bits)
    localparam CORDIC_WIDTH = WIDTH + 2;

    // π in Q17
    localparam signed [WIDTH-1:0] PI = 20'sd411775;

    // 1/K ≈ 0.607252 * 2^17 ≈ 79600
    localparam signed [WIDTH-1:0] INV_K = 20'sd79600;

    // atan LUT
    function signed [WIDTH-1:0] atan_lut;
        input integer i;
        case(i)
            0: atan_lut = 20'sd102944;
            1: atan_lut = 20'sd60777;
            2: atan_lut = 20'sd32103;
            3: atan_lut = 20'sd16297;
            4: atan_lut = 20'sd8179;
            5: atan_lut = 20'sd4094;
            6: atan_lut = 20'sd2047;
            7: atan_lut = 20'sd1024;
            8: atan_lut = 20'sd512;
            9: atan_lut = 20'sd256;
            10: atan_lut = 20'sd128;
            11: atan_lut = 20'sd64;
            12: atan_lut = 20'sd32;
            13: atan_lut = 20'sd16;
            14: atan_lut = 20'sd8;
            15: atan_lut = 20'sd4;
            default: atan_lut = 0;
        endcase
    endfunction

    // Pipeline registers
    reg signed [CORDIC_WIDTH-1:0] X [0:ITER];
    reg signed [CORDIC_WIDTH-1:0] Y [0:ITER];
    reg signed [WIDTH-1:0] Z [0:ITER];
    reg [ITER:0] valid_pipe;

    integer i;

    // Wide multiply for magnitude
    reg signed [2*WIDTH-1:0] mult;

    always @(posedge clk) begin
        if (rst) begin
            valid_pipe <= 0;
            valid_out  <= 0;
            angle_out  <= 0;
            mag_out    <= 0;

            for (i = 0; i <= ITER; i = i + 1) begin
                X[i] <= 0;
                Y[i] <= 0;
                Z[i] <= 0;
            end

        end else begin

            // Shift valid pipeline
            valid_pipe <= {valid_pipe[ITER-1:0], valid_in};

            // -------------------------
            // Input stage (quadrant fix)
            // -------------------------
            if (valid_in) begin
                if (x_in < 0 && y_in >= 0) begin
                    X[0] <= -{{(CORDIC_WIDTH-WIDTH){x_in[WIDTH-1]}}, x_in};
                    Y[0] <= -{{(CORDIC_WIDTH-WIDTH){y_in[WIDTH-1]}}, y_in};
                    Z[0] <= PI;
                end else if (x_in < 0 && y_in < 0) begin
                    X[0] <= -{{(CORDIC_WIDTH-WIDTH){x_in[WIDTH-1]}}, x_in};
                    Y[0] <= -{{(CORDIC_WIDTH-WIDTH){y_in[WIDTH-1]}}, y_in};
                    Z[0] <= -PI;
                end else begin
                    X[0] <= {{(CORDIC_WIDTH-WIDTH){x_in[WIDTH-1]}}, x_in};
                    Y[0] <= {{(CORDIC_WIDTH-WIDTH){y_in[WIDTH-1]}}, y_in};
                    Z[0] <= 0;
                end
            end

            // -------------------------
            // CORDIC iterations 
            // -------------------------
            for (i = 0; i < ITER; i = i + 1) begin
                if (Y[i] >= 0) begin
                    X[i+1] <= X[i] + (Y[i] >>> i);
                    Y[i+1] <= Y[i] - (X[i] >>> i);
                    Z[i+1] <= Z[i] + atan_lut(i);
                end else begin
                    X[i+1] <= X[i] - (Y[i] >>> i);
                    Y[i+1] <= Y[i] + (X[i] >>> i);
                    Z[i+1] <= Z[i] - atan_lut(i);
                end
            end

            // -------------------------
            // Output stage
            // -------------------------
            valid_out <= valid_pipe[ITER];

            if (valid_pipe[ITER]) begin
                angle_out <= Z[ITER];

                // magnitude = X / K
                mult = X[ITER] * INV_K;
                mag_out <= mult >>> FRAC;
            end
        end
    end

endmodule
