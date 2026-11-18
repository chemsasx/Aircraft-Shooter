module player_bullet #(
    parameter integer PLAYER_BULLET_RELATIVE_X = 16,
    parameter integer PLAYER_BULLET_RELATIVE_Y = -8,
    parameter PLAYER_BULLET_WIDTH = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter BULLET_SPEED = 4,
    parameter BURST_GAP_TICKS = 6
)(
    input CLOCK_50,
    input resetn,
    input move_tick,
    input p_bullet_fire,
    input [9:0] p_x,
    input [8:0] p_y,
    input p_bullet_rest_1, p_bullet_rest_2, p_bullet_rest_3,
    output reg p_bullet_active_1, p_bullet_active_2, p_bullet_active_3,
    output reg [9:0] p_bullet_x_1, p_bullet_x_2, p_bullet_x_3,
    output reg [8:0] p_bullet_y_1, p_bullet_y_2, p_bullet_y_3
);

localparam IDLE = 2'd0,
           SECOND = 2'd1,
           THIRD = 2'd2,
           WAIT_CLEAR = 2'd3;

reg [1:0] state;
reg [31:0] gap_count;

wire signed [31:0] current_x, current_y;
wire signed [31:0] relative_x, relative_y;
wire [9:0] spawn_x;
wire [8:0] spawn_y;

assign current_x = p_x;
assign current_y = p_y;

// Spawn position before coordinate clamping.
assign relative_x = current_x + PLAYER_BULLET_RELATIVE_X;
assign relative_y = current_y + PLAYER_BULLET_RELATIVE_Y;

assign spawn_x = (relative_x < 0) ? 10'd0 :
                 (relative_x > 1023) ? 10'd1023 : relative_x[9:0];

assign spawn_y = (relative_y < 0) ? 9'd0 :
                 (relative_y > 511) ? 9'd511 : relative_y[8:0];

always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn) begin
        state <= IDLE;
        gap_count <= 0;

        p_bullet_active_1 <= 0;
        p_bullet_active_2 <= 0;
        p_bullet_active_3 <= 0;

        p_bullet_x_1 <= 0;
        p_bullet_x_2 <= 0;
        p_bullet_x_3 <= 0;

        p_bullet_y_1 <= 0;
        p_bullet_y_2 <= 0;
        p_bullet_y_3 <= 0;
    end
    else begin
        // Check the top edge before subtracting to prevent underflow.
        if (move_tick) begin
            if (p_bullet_active_1) begin
                if (p_bullet_y_1 < BULLET_SPEED)
                    p_bullet_active_1 <= 0;
                else
                    p_bullet_y_1 <= p_bullet_y_1 - BULLET_SPEED;
            end

            if (p_bullet_active_2) begin
                if (p_bullet_y_2 < BULLET_SPEED)
                    p_bullet_active_2 <= 0;
                else
                    p_bullet_y_2 <= p_bullet_y_2 - BULLET_SPEED;
            end

            if (p_bullet_active_3) begin
                if (p_bullet_y_3 < BULLET_SPEED)
                    p_bullet_active_3 <= 0;
                else
                    p_bullet_y_3 <= p_bullet_y_3 - BULLET_SPEED;
            end
        end

        case (state)
            IDLE: begin
                gap_count <= 0;
                if (p_bullet_fire) begin
                    p_bullet_active_1 <= 1;
                    p_bullet_x_1 <= spawn_x;
                    p_bullet_y_1 <= spawn_y;
                    state <= SECOND;
                end
            end

            SECOND: begin
                if (move_tick) begin
                    if (gap_count == BURST_GAP_TICKS - 1) begin
                        gap_count <= 0;
                        p_bullet_active_2 <= 1;
                        p_bullet_x_2 <= spawn_x;
                        p_bullet_y_2 <= spawn_y;
                        state <= THIRD;
                    end
                    else
                        gap_count <= gap_count + 1'b1;
                end
            end

            THIRD: begin
                if (move_tick) begin
                    if (gap_count == BURST_GAP_TICKS - 1) begin
                        gap_count <= 0;
                        p_bullet_active_3 <= 1;
                        p_bullet_x_3 <= spawn_x;
                        p_bullet_y_3 <= spawn_y;
                        state <= WAIT_CLEAR;
                    end
                    else
                        gap_count <= gap_count + 1'b1;
                end
            end

            WAIT_CLEAR: begin
                if (!p_bullet_active_1 &&
                    !p_bullet_active_2 &&
                    !p_bullet_active_3)
                    state <= IDLE;
            end

            default: state <= IDLE;
        endcase

        // Hit signals take priority over other active assignments.
        if (p_bullet_rest_1)
            p_bullet_active_1 <= 0;
        if (p_bullet_rest_2)
            p_bullet_active_2 <= 0;
        if (p_bullet_rest_3)
            p_bullet_active_3 <= 0;
    end
end

endmodule