module boss #(
    parameter SCREEN_WIDTH = 640,
    parameter BOSS_WIDTH = 64,
    parameter BOSS_Y = 0,
    parameter BOSS_SPEED = 2,
    parameter MOVE_CYCLES = 833333,
    parameter FIRE_CYCLES = 100000000
)(
    input CLOCK_50,
    input resetn,
    output reg [9:0] b_x,
    output [8:0] b_y,
    output reg b_bullet_fire
);

localparam integer MAX_X = SCREEN_WIDTH - BOSS_WIDTH;

reg move_right;
reg [31:0] move_count;
reg [31:0] fire_count;

assign b_y = BOSS_Y;

//******************************************************************************** position
always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn) begin
        b_x <= MAX_X / 2;
        move_right <= 1;
        move_count <= 0;
    end
    else if (move_count == MOVE_CYCLES - 1) begin
        move_count <= 0;

        if (move_right) begin
            if (b_x + BOSS_SPEED >= MAX_X) begin
                b_x <= MAX_X;
                move_right <= 0;
            end
            else
                b_x <= b_x + BOSS_SPEED;
        end
        else begin
            if (b_x <= BOSS_SPEED) begin
                b_x <= 0;
                move_right <= 1;
            end
            else
                b_x <= b_x - BOSS_SPEED;
        end
    end
    else
        move_count <= move_count + 1'b1;
end

//******************************************************************************** fire
always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn) begin
        fire_count <= 0;
        b_bullet_fire <= 0;
    end
    else begin
        b_bullet_fire <= 0;

        if (fire_count == FIRE_CYCLES - 1) begin
            fire_count <= 0;
            b_bullet_fire <= 1;
        end
        else
            fire_count <= fire_count + 1'b1;
    end
end

endmodule
