module top #(
    parameter SCREEN_WIDTH = 640,// change to 320*240?
    parameter SCREEN_HEIGHT = 480,
    parameter XW = 10,// x position digits
    parameter YW = 9,// y position digits
    parameter CW = 9,// RGB

    parameter PLAYER_WIDTH = 36,
    parameter PLAYER_HEIGHT = 48,

    parameter PLAYER_BULLET_WIDTH = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter integer PLAYER_BULLET_RELATIVE_X = 16,
    parameter integer PLAYER_BULLET_RELATIVE_Y = -8,
    parameter BULLET_SPEED = 4,
    parameter BURST_GAP_TICKS = 6,

    parameter FRAME_CYCLES = 833333, // 60 Hz at CLOCK_50, 60fps
    parameter COUNT_W = 20
)(
    input CLOCK_50,
    input [3:0] KEY,
    inout PS2_CLK,
    inout PS2_DAT,
    output [9:0] LEDR,
    output [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);

wire resetn;
assign resetn = KEY[0];

wire frame_tick;

frame_tick #(
    .FRAME_CYCLES(FRAME_CYCLES),
    .COUNT_W(COUNT_W)
) u_frame_tick (
    .clk(CLOCK_50),
    .resetn(resetn),
    .frame_tick(frame_tick)
);

wire left_click, right_down;
wire signed [8:0] dx, dy;

mouse_decoder m (
    .clock(CLOCK_50),
    .resetn(resetn),
    .PS2_CLK(PS2_CLK),
    .PS2_DAT(PS2_DAT),
    .dx(dx),
    .dy(dy),
    .left_click(left_click),
    .right_down(right_down)
);

wire move_en;
assign move_en = (dx != 9'sd0) || (dy != 9'sd0);

wire [XW-1:0] p_x;
wire [YW-1:0] p_y;
wire p_bullet_fire, p_laser_fire;

player #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .PLAYER_WIDTH(PLAYER_WIDTH),
    .PLAYER_HEIGHT(PLAYER_HEIGHT)
) p (
    .CLOCK_50(CLOCK_50),
    .resetn(resetn),
    .move_en(move_en),
    .dx(dx),
    .dy(dy),
    .left_click(left_click),
    .right_down(right_down),
    .p_x(p_x),
    .p_y(p_y),
    .p_bullet_fire(p_bullet_fire),
    .p_laser_fire(p_laser_fire)
);

wire p_bullet_active_1, p_bullet_active_2, p_bullet_active_3;
wire [XW-1:0] p_bullet_x_1, p_bullet_x_2, p_bullet_x_3;
wire [YW-1:0] p_bullet_y_1, p_bullet_y_2, p_bullet_y_3;

player_bullet #(
    .PLAYER_BULLET_RELATIVE_X(PLAYER_BULLET_RELATIVE_X),
    .PLAYER_BULLET_RELATIVE_Y(PLAYER_BULLET_RELATIVE_Y),
    .PLAYER_BULLET_WIDTH(PLAYER_BULLET_WIDTH),
    .PLAYER_BULLET_HEIGHT(PLAYER_BULLET_HEIGHT),
    .BULLET_SPEED(BULLET_SPEED),
    .BURST_GAP_TICKS(BURST_GAP_TICKS)
) p_bullet (
    .CLOCK_50(CLOCK_50),
    .resetn(resetn),
    .move_tick(frame_tick),
    .p_bullet_fire(p_bullet_fire),
    .p_x(p_x),
    .p_y(p_y),
    .p_bullet_rest_1(1'b0), // not connected yet
    .p_bullet_rest_2(1'b0),
    .p_bullet_rest_3(1'b0),
    .p_bullet_active_1(p_bullet_active_1),
    .p_bullet_active_2(p_bullet_active_2),
    .p_bullet_active_3(p_bullet_active_3),
    .p_bullet_x_1(p_bullet_x_1),
    .p_bullet_x_2(p_bullet_x_2),
    .p_bullet_x_3(p_bullet_x_3),
    .p_bullet_y_1(p_bullet_y_1),
    .p_bullet_y_2(p_bullet_y_2),
    .p_bullet_y_3(p_bullet_y_3)
);

wire vga_plot;
wire [XW-1:0] vga_x;
wire [YW-1:0] vga_y;
wire [CW-1:0] vga_colour;

display #(
    .XW(XW),
    .YW(YW),
    .CW(CW),
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .PLAYER_WIDTH(PLAYER_WIDTH),
    .PLAYER_HEIGHT(PLAYER_HEIGHT),
    .PLAYER_BULLET_WIDTH(PLAYER_BULLET_WIDTH),
    .PLAYER_BULLET_HEIGHT(PLAYER_BULLET_HEIGHT)
) u_display (
    .clk(CLOCK_50),
    .resetn(resetn),
    .frame_tick(frame_tick),
    .p_x(p_x),
    .p_y(p_y),
    .p_bullet_x_1(p_bullet_x_1),
    .p_bullet_y_1(p_bullet_y_1),
    .p_bullet_active_1(p_bullet_active_1),
    .p_bullet_x_2(p_bullet_x_2),
    .p_bullet_y_2(p_bullet_y_2),
    .p_bullet_active_2(p_bullet_active_2),
    .p_bullet_x_3(p_bullet_x_3),
    .p_bullet_y_3(p_bullet_y_3),
    .p_bullet_active_3(p_bullet_active_3),
    .vga_plot(vga_plot),
    .vga_x(vga_x),
    .vga_y(vga_y),
    .vga_colour(vga_colour)
);

vga_adapter #(
    .RESOLUTION("640x480"),
    .COLOR_DEPTH(CW),
    .BACKGROUND_IMAGE("./MIF/black_640_9.mif")
) VGA (
    .resetn(resetn),
    .clock(CLOCK_50),
    .color(vga_colour),
    .x(vga_x),
    .y(vga_y),
    .write(vga_plot),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_BLANK_N(VGA_BLANK_N),
    .VGA_SYNC_N(VGA_SYNC_N),
    .VGA_CLK(VGA_CLK)
);

assign LEDR[0] = right_down;
assign LEDR[1] = p_bullet_active_1;
assign LEDR[2] = p_bullet_active_2;
assign LEDR[3] = p_bullet_active_3;
assign LEDR[9:4] = 6'b0;

endmodule