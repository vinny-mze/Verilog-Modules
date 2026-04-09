`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Sakon Semiconductors
// Engineer: vinny mze
// 
// Create Date: 20.03.2026 10:34:21
// Design Name:  Fixed-Point Square Root Unit
// Module Name:  sqrt
// Project Name:  WiFi Halow
// Target Devices:  FPGA 
// Tool Versions:  Vivado
// Description: 
//   This module computes the square root of a fixed-point number using a 
//   digit-by-digit (restoring) algorithm. The input is interpreted as a 
//   Q0.WIDTH fixed-point value (range [0,1)), and the output is also in 
//   Q0.WIDTH format.
//
//   The design is iterative and takes WIDTH clock cycles to produce a result.
//   A valid_in signal starts computation, and valid_out indicates completion.
//
// Dependencies:  None
//////////////////////////////////////////////////////////////////////////////////

module sqrt #(
    parameter WIDTH = 20  // Bit width of input/output
)(
    input wire clk,                  // System clock
    input wire rst,                  // Synchronous reset
    input wire valid_in,             // Input valid signal
    input wire [WIDTH-1:0] radicand,// Input value (Q0.WIDTH fixed-point)
    output reg [WIDTH-1:0] root,    // Output square root (Q0.WIDTH)
    output reg valid_out            // Output valid signal
);

    // ============================================================
    // Internal Registers
    // ============================================================

    reg [2*WIDTH-1:0]   rad_shift;   // Shift register holding radicand (extended)
    reg [WIDTH-1:0]     root_reg;    // Intermediate root value
    reg [2*WIDTH+1:0]   remainder;   // Partial remainder during computation
    reg [5:0]           bit_cnt;     // Iteration counter (up to WIDTH)
    reg                 busy;        // Indicates computation in progress

    // Temporary variables for combinational steps inside sequential block
    reg [2*WIDTH+1:0]   trial;       // Trial divisor
    reg [2*WIDTH+1:0]   temp_rem;    // Temporary remainder
    reg [WIDTH-1:0]     temp_root;   // Temporary root
    reg [2*WIDTH-1:0]   temp_rad;    // Temporary radicand shift

    // ============================================================
    // Main Sequential Logic
    // ============================================================

    always @(posedge clk) begin
        if (rst) begin
            // Reset all outputs and control signals
            root       <= 0;
            valid_out  <= 0;
            busy       <= 0;

        end else begin
            // ====================================================
            // Start a new computation
            // ====================================================
            if (valid_in && !busy) begin
                remainder  <= 0;  // Initialize remainder
                root_reg   <= 0;  // Clear root register

                // Extend radicand by shifting left (adds fractional precision)
                rad_shift  <= {radicand, {WIDTH{1'b0}}};

                bit_cnt    <= WIDTH; // Number of iterations required
                busy       <= 1;     // Mark unit as busy
                valid_out  <= 0;

            // ====================================================
            // Iterative square root computation
            // ====================================================
            end else if (busy) begin

                // Step 1: Bring down next 2 bits from radicand
                temp_rem = (remainder << 2) | rad_shift[2*WIDTH-1:2*WIDTH-2];

                // Step 2: Shift radicand left by 2 bits for next cycle
                temp_rad = rad_shift << 2;

                // Step 3: Compute trial value (4 * current_root + 1)
                trial = (root_reg << 2) | 1;

                // Step 4: Compare and update
                if (temp_rem >= trial) begin
                    // Subtract trial value and set next root bit = 1
                    temp_rem  = temp_rem - trial;
                    temp_root = (root_reg << 1) | 1;
                end else begin
                    // Keep remainder, next root bit = 0
                    temp_root = root_reg << 1;
                end

                // Step 5: Update registers (non-blocking)
                remainder <= temp_rem;
                root_reg  <= temp_root;
                rad_shift <= temp_rad;

                // Step 6: Check if computation is complete
                if (bit_cnt == 1) begin
                    root      <= temp_root; // Final result
                    valid_out <= 1;         // Signal completion
                    busy      <= 0;         // Ready for next input
                end else begin
                    bit_cnt <= bit_cnt - 1; // Continue iterations
                end

            end else begin
                // No operation, clear valid_out
                valid_out <= 0;
            end
        end
    end

endmodule
