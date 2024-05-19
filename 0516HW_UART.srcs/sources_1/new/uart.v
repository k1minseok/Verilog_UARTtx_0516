`timescale 1ns / 1ps

module uart (
    input clk,
    input reset,
    input start,
    input [7:0] tx_data,

    output txd,
    output tx_done
);

    wire w_br_tick;

    baudrate_generator #(
        .HERZ(9600)
    ) U_BR_Gen (
        .clk  (clk),
        .reset(reset),

        .br_tick(w_br_tick)
    );

    transmitter U_TxD (
        .clk(clk),
        .reset(reset),
        .start(start),
        .br_tick(w_br_tick),
        .data(tx_data),

        .tx_bit (txd),
        .tx_done(tx_done)
    );

endmodule


module baudrate_generator #(
    parameter HERZ = 9600
) (
    input clk,
    input reset,

    output br_tick
);

    // reg [$clog2(100_000_000/9600)-1:0] counter_reg, counter_next;
    reg [$clog2(100_000_000/HERZ)-1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;

    assign br_tick = tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else begin
            counter_reg <= counter_next;
            tick_reg <= tick_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        // if (counter_reg == 100_000_000 / 9600 - 1) begin  // baudrate 9600Hz
        if (counter_reg == 100_000_000 / HERZ - 1) begin
            counter_next = 0;
            tick_next = 1'b1;
        end else begin
            counter_next = counter_reg + 1;
            tick_next = 1'b0;
        end
    end
endmodule


module transmitter (
    input clk,
    input reset,
    input start,
    input br_tick,
    input [7:0] data,

    output tx_bit,
    output tx_done
);

    localparam START = 2, STOP = 1, IDLE = 0;

    // reg [7:0] data_reg, data_next;
    reg tx_bit_reg, tx_bit_next, tx_done_reg, tx_done_next;
    reg [1:0] state_reg, state_next;
    reg [3:0] i_reg, i_next;



    // state rigister
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tx_bit_reg <= 1'b0;
            state_reg <= IDLE;
            tx_done_reg <= 1'b0;
            i_reg <= 4'd0;
        end else begin
            tx_bit_reg <= tx_bit_next;
            state_reg <= state_next;
            tx_done_reg <= tx_done_next;
            i_reg <= i_next;
        end
    end


    // next state logic
    // always @(data, start, br_tick, state_reg, tx_bit_reg, i_reg) begin
    always @(*) begin
        state_next = state_reg;
        i_next = i_reg;

        case (state_reg)
            IDLE: begin
                if (start) state_next = START;
                else state_next = IDLE;
            end

            STOP: begin
                if (br_tick) begin
                    state_next = IDLE;
                end
            end

            START: begin
                if (br_tick) begin
                    if (i_next == 4'd8) begin
                        state_next = STOP;
                        i_next = 4'd0;
                    end else begin
                        state_next = START;
                        i_next = i_next + 4'd1;
                    end
                end
            end
        endcase

    end


    // output logic
    //always @(start, br_tick, state_reg, tx_bit_reg) begin
    always @(*) begin
        tx_bit_next  = tx_bit_reg;
        tx_done_next = 1'b0;

        case (state_reg)
            IDLE: begin
                tx_bit_next = 1'b1;
            end

            STOP: begin
                tx_bit_next = 1'b1;
                if (state_next == IDLE) tx_done_next = 1'b1;
            end

            START: begin
                if (i_next == 4'd0) begin
                    tx_bit_next = 1'b0;
                end else begin
                    tx_bit_next = data[i_next-1];
                end
            end
        endcase

    end

    assign tx_bit  = tx_bit_reg;
    assign tx_done = tx_done_reg;

endmodule
