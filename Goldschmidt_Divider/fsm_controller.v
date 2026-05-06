`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Sakon Semiconductors       
// Engineer:        Vincent Muzerengwa
// 
// Module Name:     fsm_controller
// Project:         WiFi HaLow
// Target Devices:  FPGA
// Tool Versions:   Vivado 
//
// Description:
//   Finite State Machine that controls the entire Goldschmidt division process.
//   Manages initialization, iteration sequencing, and completion signaling.
//
//   States:
//     IDLE → INIT → LOAD_FACTOR → LOAD_MULT → WRITEBACK → (repeat or DONE)
//////////////////////////////////////////////////////////////////////////////////

module fsm_controller #
(
    parameter ITER = 4
)
(
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire div_by_zero,

    output reg  busy,
    output reg  load_init,
    output reg  load_factor,
    output reg  load_mult,
    output reg  load_iter_result,
    output reg  done
);

    localparam S_IDLE        = 3'd0;
    localparam S_INIT        = 3'd1;
    localparam S_LOAD_FACTOR = 3'd2;
    localparam S_LOAD_MULT   = 3'd3;
    localparam S_WRITEBACK   = 3'd4;
    localparam S_DONE        = 3'd5;

    reg [2:0] state;
    reg [$clog2(ITER+1)-1:0] iter_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= S_IDLE;
            iter_cnt         <= 0;
            busy             <= 0;
            load_init        <= 0;
            load_factor      <= 0;
            load_mult        <= 0;
            load_iter_result <= 0;
            done             <= 0;
        end
        else begin
            load_init        <= 0;
            load_factor      <= 0;
            load_mult        <= 0;
            load_iter_result <= 0;
            done             <= 0;

            case (state)
                S_IDLE: begin
                    busy     <= 0;
                    iter_cnt <= 0;

                    if (start) begin
                        if (div_by_zero) begin
                            done  <= 1'b1;
                            state <= S_IDLE;
                        end
                        else begin
                            busy  <= 1'b1;
                            state <= S_INIT;
                        end
                    end
                end

                S_INIT: begin
                    busy      <= 1'b1;
                    load_init <= 1'b1;
                    state     <= S_LOAD_FACTOR;
                end

                S_LOAD_FACTOR: begin
                    busy        <= 1'b1;
                    load_factor <= 1'b1;
                    state       <= S_LOAD_MULT;
                end

                S_LOAD_MULT: begin
                    busy      <= 1'b1;
                    load_mult <= 1'b1;
                    state     <= S_WRITEBACK;
                end

                S_WRITEBACK: begin
                    busy             <= 1'b1;
                    load_iter_result <= 1'b1;

                    if (iter_cnt == ITER-1) begin
                        state <= S_DONE;
                    end
                    else begin
                        iter_cnt <= iter_cnt + 1'b1;
                        state    <= S_LOAD_FACTOR;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule