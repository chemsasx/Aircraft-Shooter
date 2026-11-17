module player #(
    parameter SCREEN_WIDTH = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter PLAYER_WIDTH = 36,
    parameter PLAYER_HEIGHT = 48
)(
    input CLOCK_50,
    input resetn,
    input move_en,
    input signed [8:0] dx, dy,
    input left_click,
    input right_down,
    output reg [9:0] p_x,
    output reg [8:0] p_y,
    output p_bullet_fire, p_laser_fire
);

//******************************************************************************** fire
assign p_bullet_fire = resetn && left_click && !right_down;
assign p_laser_fire = resetn && left_click && right_down;

//******************************************************************************** position
localparam MAX_X = SCREEN_WIDTH - PLAYER_WIDTH;
localparam MAX_Y = SCREEN_HEIGHT - PLAYER_HEIGHT;

wire signed [11:0] next_x, next_y;

wire signed [11:0] p_x_signed = {2'b00, p_x};
wire signed [11:0] p_y_signed = {3'b000, p_y};

assign next_x = p_x_signed + dx;
assign next_y = p_y_signed - dy;

always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn) begin
        p_x <= MAX_X / 2;
        p_y <= MAX_Y / 2;
    end
    else if (move_en) begin
        if (next_x < 0)
            p_x <= 0;
        else if (next_x > MAX_X)
            p_x <= MAX_X;
        else
            p_x <= next_x[9:0];

        if (next_y < 0)
            p_y <= 0;
        else if (next_y > MAX_Y)
            p_y <= MAX_Y;
        else
            p_y <= next_y[8:0];
    end
end
endmodule