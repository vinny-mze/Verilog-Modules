`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors
// Engineer:        vinny mze
// 
// Module Name:     cordic_atan2
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado
//
// Description: 
//   This module computes the two-argument arctangent (atan2(y, x)) using 
//   the CORDIC algorithm in vectoring mode. It returns the angle in the 
//   range [-π, +π] with quadrant correction.
//
//   Based on standard CORDIC vectoring mode with quadrant handling.
//   Fully pipelined architecture (one iteration per stage).
//
//////////////////////////////////////////////////////////////////////////////////

module cordic_atan2 #(
    parameter WIDTH = 20,   // I/O width (signed fixed-point)
    parameter FRAC  = 17,   // Fractional bits for angle output
    parameter ITER  = 16    // Number of CORDIC iterations (higher = better accuracy)
)(
    input wire                      clk,
    input wire                      rst,
    input wire                      valid_in,
    input wire signed [WIDTH-1:0]   x_in,        // Real part (x-coordinate)
    input wire signed [WIDTH-1:0]   y_in,        // Imaginary part (y-coordinate)
    output reg signed [WIDTH-1:0]   angle_out,   // Output angle in radians (Q(3).FRAC)
    output reg                      valid_out
);

    //==========================================================================
    // Internal Parameters & Constants
    //==========================================================================
    
    // Extended internal width to prevent overflow during iterations
    localparam CORDIC_WIDTH = WIDTH + 2;
    
    // π in Q(3).17 format (3 integer bits, 17 fractional bits)
    localparam signed [WIDTH-1:0] PI = 20'sd411775;

    //==========================================================================
    // Arctangent Lookup Table
    // atan(2^(-i)) precomputed in Q(3).17 format
    //==========================================================================
    function signed [WIDTH-1:0] atan_lut;
        input integer i;
        begin
            case(i)
                0:  atan_lut = 20'sd102944;  // atan(1)         ≈ 0.785398 rad
                1:  atan_lut = 20'sd60777;   // atan(0.5)       ≈ 0.463648 rad
                2:  atan_lut = 20'sd32103;   // atan(0.25)      ≈ 0.244979 rad
                3:  atan_lut = 20'sd16297;   // atan(0.125)     ≈ 0.124355 rad
                4:  atan_lut = 20'sd8179;    // atan(0.0625)    ≈ 0.062419 rad
                5:  atan_lut = 20'sd4094;    // atan(0.03125)   ≈ 0.031239 rad
                6:  atan_lut = 20'sd2047;    // atan(0.015625)  ≈ 0.015623 rad
                7:  atan_lut = 20'sd1024;    // atan(0.0078125) ≈ 0.007812 rad
                8:  atan_lut = 20'sd512;
                9:  atan_lut = 20'sd256;
                10: atan_lut = 20'sd128;
                11: atan_lut = 20'sd64;
                12: atan_lut = 20'sd32;
                13: atan_lut = 20'sd16;
                14: atan_lut = 20'sd8;
                15: atan_lut = 20'sd4;
                default: atan_lut = 0;
            endcase
        end
    endfunction

    //==========================================================================
    // Pipeline Registers
    //==========================================================================
    reg signed [CORDIC_WIDTH-1:0] X [0:ITER];   // X path (decreases toward magnitude)
    reg signed [CORDIC_WIDTH-1:0] Y [0:ITER];   // Y path (driven toward zero)
    reg signed [WIDTH-1:0]        Z [0:ITER];   // Accumulated angle
    reg [ITER:0]                  valid_pipe;   // Valid signal pipeline

    integer i;

    //==========================================================================
    // Main CORDIC Process
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            // Reset all pipeline registers
            valid_pipe <= 0;
            valid_out  <= 1'b0;
            angle_out  <= '0;
            
            for (i = 0; i <= ITER; i = i + 1) begin
                X[i] <= '0;
                Y[i] <= '0;
                Z[i] <= '0;
            end
        end 
        else begin
            // Shift the valid pipeline
            valid_pipe <= {valid_pipe[ITER-1:0], valid_in};

            //==================================================================
            // Stage 0: Input & Quadrant Correction
            //==================================================================
            if (valid_in) begin
                if (x_in < 0 && y_in >= 0) begin
                    // Second quadrant: rotate by +π
                    X[0] <= -{{(CORDIC_WIDTH-WIDTH){x_in[WIDTH-1]}}, x_in};
                    Y[0] <= -{{(CORDIC_WIDTH-WIDTH){y_in[WIDTH-1]}}, y_in};
                    Z[0] <= PI;
                end 
                else if (x_in < 0 && y_in < 0) begin
                    // Third quadrant: rotate by -π
                    X[0] <= -{{(CORDIC_WIDTH-WIDTH){x_in[WIDTH-1]}}, x_in};
                    Y[0] <= -{{(CORDIC_WIDTH-WIDTH){y_in[WIDTH-1]}}, y_in};
                    Z[0] <= -PI;
                end 
                else begin
                    // First or Fourth quadrant: no adjustment
                    X[0] <= {{(CORDIC_WIDTH-WIDTH){x_in[WIDTH-1]}}, x_in};
                    Y[0] <= {{(CORDIC_WIDTH-WIDTH){y_in[WIDTH-1]}}, y_in};
                    Z[0] <= '0;
                end
            end

            //==================================================================
            // CORDIC Iterations (Vectoring Mode)
            // Each iteration drives Y toward zero while accumulating angle in Z
            //==================================================================
            for (i = 0; i < ITER; i = i + 1) begin
                if (valid_pipe[i]) begin
                    if (Y[i] >= 0) begin
                        // Rotate clockwise (negative direction)
                        X[i+1] <= X[i] + (Y[i] >>> i);
                        Y[i+1] <= Y[i] - (X[i] >>> i);
                        Z[i+1] <= Z[i] + atan_lut(i);
                    end else begin
                        // Rotate counter-clockwise (positive direction)
                        X[i+1] <= X[i] - (Y[i] >>> i);
                        Y[i+1] <= Y[i] + (X[i] >>> i);
                        Z[i+1] <= Z[i] - atan_lut(i);
                    end
                end
            end

            //==================================================================
            // Output Stage
            //==================================================================
            valid_out <= valid_pipe[ITER];
            if (valid_pipe[ITER]) begin
                angle_out <= Z[ITER];
            end
        end
    end

endmodule