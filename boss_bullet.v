module boss_bullet #(
    parameter SCREEN_WIDTH = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter BOSS_WIDTH = 64,
    parameter BOSS_HEIGHT = 48,
    parameter PLAYER_WIDTH = 36,
    parameter PLAYER_HEIGHT = 48,
    parameter BOSS_BULLET_WIDTH = 4,
    parameter BOSS_BULLET_HEIGHT = 8,
    parameter integer BOSS_BULLET_RELATIVE_X = (BOSS_WIDTH - BOSS_BULLET_WIDTH) / 2,
    parameter integer BOSS_BULLET_RELATIVE_Y = BOSS_HEIGHT,
    parameter BULLET_SPEED = 8,
    parameter MOVE_CYCLES = 833333,
    parameter BURST_GAP_TICKS = 6
)(
    input CLOCK_50,
    input resetn,
    input b_bullet_fire,
    input [9:0] b_x, p_x,
    input [8:0] b_y, p_y,
    input b_bullet_rest_1, b_bullet_rest_2, b_bullet_rest_3,
    output b_bullet_active_1, b_bullet_active_2, b_bullet_active_3,
    output [9:0] b_bullet_x_1, b_bullet_x_2, b_bullet_x_3,
    output [8:0] b_bullet_y_1, b_bullet_y_2, b_bullet_y_3
);

localparam IDLE = 2'd0,
           SECOND = 2'd1,
           THIRD = 2'd2,
           WAIT_CLEAR = 2'd3;

reg [1:0] state;
reg [31:0] gap_count;
reg [31:0] move_count;

wire move_tick;
wire fire_1, fire_2, fire_3;

wire signed [31:0] current_b_x, current_b_y;
wire signed [31:0] current_p_x, current_p_y;
wire signed [31:0] spawn_x, spawn_y;
wire signed [31:0] target_x, target_y;

assign current_b_x = {1'b0, b_x};
assign current_b_y = {1'b0, b_y};
assign current_p_x = {1'b0, p_x};
assign current_p_y = {1'b0, p_y};

assign spawn_x = current_b_x + BOSS_BULLET_RELATIVE_X;
assign spawn_y = current_b_y + BOSS_BULLET_RELATIVE_Y;
assign target_x = current_p_x + (PLAYER_WIDTH - BOSS_BULLET_WIDTH) / 2;
assign target_y = current_p_y + (PLAYER_HEIGHT - BOSS_BULLET_HEIGHT) / 2;

assign move_tick = (move_count == MOVE_CYCLES - 1);
assign fire_1 = (state == IDLE) && b_bullet_fire;
assign fire_2 = (state == SECOND) && move_tick &&
                (gap_count == BURST_GAP_TICKS - 1);
assign fire_3 = (state == THIRD) && move_tick &&
                (gap_count == BURST_GAP_TICKS - 1);

always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn)
        move_count <= 0;
    else if (state == IDLE || move_tick)
        move_count <= 0;
    else
        move_count <= move_count + 1'b1;
end

//******************************************************************************** burst
always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn) begin
        state <= IDLE;
        gap_count <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                gap_count <= 0;
                if (b_bullet_fire)
                    state <= SECOND;
            end

            SECOND: begin
                if (move_tick) begin
                    if (gap_count == BURST_GAP_TICKS - 1) begin
                        gap_count <= 0;
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
                        state <= WAIT_CLEAR;
                    end
                    else
                        gap_count <= gap_count + 1'b1;
                end
            end

            WAIT_CLEAR: begin
                if (!b_bullet_active_1 &&
                    !b_bullet_active_2 &&
                    !b_bullet_active_3)
                    state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

boss_bullet_unit #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .BULLET_WIDTH(BOSS_BULLET_WIDTH),
    .BULLET_HEIGHT(BOSS_BULLET_HEIGHT),
    .BULLET_SPEED(BULLET_SPEED)
) bullet_1 (
    .CLOCK_50(CLOCK_50), .resetn(resetn),
    .fire(fire_1), .move_tick(move_tick), .rest(b_bullet_rest_1),
    .spawn_x(spawn_x), .spawn_y(spawn_y),
    .target_x(target_x), .target_y(target_y),
    .active(b_bullet_active_1),
    .bullet_x(b_bullet_x_1), .bullet_y(b_bullet_y_1)
);

boss_bullet_unit #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .BULLET_WIDTH(BOSS_BULLET_WIDTH),
    .BULLET_HEIGHT(BOSS_BULLET_HEIGHT),
    .BULLET_SPEED(BULLET_SPEED)
) bullet_2 (
    .CLOCK_50(CLOCK_50), .resetn(resetn),
    .fire(fire_2), .move_tick(move_tick), .rest(b_bullet_rest_2),
    .spawn_x(spawn_x), .spawn_y(spawn_y),
    .target_x(target_x), .target_y(target_y),
    .active(b_bullet_active_2),
    .bullet_x(b_bullet_x_2), .bullet_y(b_bullet_y_2)
);

boss_bullet_unit #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .BULLET_WIDTH(BOSS_BULLET_WIDTH),
    .BULLET_HEIGHT(BOSS_BULLET_HEIGHT),
    .BULLET_SPEED(BULLET_SPEED)
) bullet_3 (
    .CLOCK_50(CLOCK_50), .resetn(resetn),
    .fire(fire_3), .move_tick(move_tick), .rest(b_bullet_rest_3),
    .spawn_x(spawn_x), .spawn_y(spawn_y),
    .target_x(target_x), .target_y(target_y),
    .active(b_bullet_active_3),
    .bullet_x(b_bullet_x_3), .bullet_y(b_bullet_y_3)
);

endmodule


module boss_bullet_unit #(
    parameter SCREEN_WIDTH = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter BULLET_WIDTH = 4,
    parameter BULLET_HEIGHT = 8,
    parameter BULLET_SPEED = 8
)(
    input CLOCK_50,
    input resetn,
    input fire,
    input move_tick,
    input rest,
    input signed [31:0] spawn_x, spawn_y,
    input signed [31:0] target_x, target_y,
    output reg active,
    output reg [9:0] bullet_x,
    output reg [8:0] bullet_y
);

localparam integer MAX_X = SCREEN_WIDTH - BULLET_WIDTH;
localparam integer MAX_Y = SCREEN_HEIGHT - BULLET_HEIGHT;

reg signed [31:0] delta_x, delta_y;
reg signed [31:0] step_x, step_y;
reg signed [31:0] error;

reg signed [31:0] next_x, next_y;
reg signed [31:0] next_error, twice_error;
wire signed [31:0] aim_dx, aim_dy;
wire signed [31:0] abs_dx, abs_dy;
integer i;

assign aim_dx = target_x - spawn_x;
assign aim_dy = target_y - spawn_y;
assign abs_dx = (aim_dx < 0) ? -aim_dx : aim_dx;
assign abs_dy = (aim_dy < 0) ? -aim_dy : aim_dy;

//******************************************************************************** straight line
// Bresenham: latch the direction at launch; no divider or floating point.
always @(*) begin
    next_x = {1'b0, bullet_x};
    next_y = {1'b0, bullet_y};
    next_error = error;
    twice_error = 0;

    for (i = 0; i < BULLET_SPEED; i = i + 1) begin
        twice_error = next_error <<< 1;

        if (twice_error >= -delta_y) begin
            next_error = next_error - delta_y;
            next_x = next_x + step_x;
        end

        if (twice_error <= delta_x) begin
            next_error = next_error + delta_x;
            next_y = next_y + step_y;
        end
    end
end

always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn) begin
        active <= 0;
        bullet_x <= 0;
        bullet_y <= 0;
        delta_x <= 0;
        delta_y <= 1;
        step_x <= 0;
        step_y <= 1;
        error <= -1;
    end
    else begin
        if (fire) begin
            if (spawn_x < 0 || spawn_x > MAX_X ||
                spawn_y < 0 || spawn_y > MAX_Y)
                active <= 0;
            else begin
                active <= 1;
                bullet_x <= spawn_x[9:0];
                bullet_y <= spawn_y[8:0];

                if (aim_dx == 0 && aim_dy == 0) begin
                    delta_x <= 0;
                    delta_y <= 1;
                    step_x <= 0;
                    step_y <= 1;
                    error <= -1;
                end
                else begin
                    delta_x <= abs_dx;
                    delta_y <= abs_dy;
                    step_x <= (aim_dx < 0) ? -1 : 1;
                    step_y <= (aim_dy < 0) ? -1 : 1;
                    error <= abs_dx - abs_dy;
                end
            end
        end
        else if (move_tick && active) begin
            if (next_x < 0 || next_x > MAX_X ||
                next_y < 0 || next_y > MAX_Y)
                active <= 0;
            else begin
                bullet_x <= next_x[9:0];
                bullet_y <= next_y[8:0];
                error <= next_error;
            end
        end

        if (rest)
            active <= 0;
    end
end

endmodule
