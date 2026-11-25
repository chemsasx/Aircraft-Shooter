// ============================================================================
// top  -  board top level for Aircraft Shooter (M2 version)
// ----------------------------------------------------------------------------
//   mouse -> player -> player_bullet --+
//   boss  -> boss_bullet --------------+-> damage_detect -> hp_update
//                                      |                      |
//                                      +------> display <-----+ -> vga_adapter
//
//   KEY[0]      reset (active-low)
//   mouse       move = move the player, left click = fire a burst of 3 bullets
//   LEDR[0]     right mouse button held
//   LEDR[3:1]   player bullet 3..1 active
//   LEDR[6:4]   boss bullet 3..1 active
//   LEDR[8]     boss HP = 0
//   LEDR[9]     player HP = 0
//
// All game constants live here and are passed down with #( ).
// Values follow player.v, player_bullet.v, boss.v and boss_bullet.v.
// ============================================================================
module top #(
    parameter SCREEN_WIDTH = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter XW = 10,// x position digits
    parameter YW = 9,// y position digits
    parameter CW = 9,// RGB

    // player = the picture at the start of MIF/sprites.hex (drawn by display through the sprite ROM)
    parameter PLAYER_WIDTH = 37,
    parameter PLAYER_HEIGHT = 66,

    parameter PLAYER_BULLET_WIDTH = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter integer PLAYER_BULLET_RELATIVE_X = 16, // (37 - 4) / 2: bullet leaves from the nose (column 18)
    parameter integer PLAYER_BULLET_RELATIVE_Y = -8,
    parameter BULLET_SPEED = 4,
    parameter BURST_GAP_TICKS = 6,

    // ---- boss (values from boss.v / boss_bullet.v) ----
    parameter BOSS_WIDTH = 112,                // boss = the picture in MIF/sprites.hex (after the player)
    parameter BOSS_HEIGHT = 117,
    parameter BOSS_Y = 16,                     // boss.v default is 0; 16 leaves room for the boss HP bar (y = 4..11)
    parameter BOSS_SPEED = 2,                  // pixels per frame
    parameter BOSS_FIRE_CYCLES = 100000000,    // one burst every 2 s
    parameter BOSS_BULLET_WIDTH = 4,
    parameter BOSS_BULLET_HEIGHT = 8,
    parameter BOSS_BULLET_SPEED = 8,           // steps per frame

    // ---- HP ----
    parameter HP_W = 5,                        // 0..16 needs 5 bits
    parameter MAX_HP = 16,

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

// ---------------------------------------------------------------- player
wire [XW-1:0] p_x;
wire [YW-1:0] p_y;
wire p_bullet_fire, p_laser_fire; // laser is not used

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

// ---------------------------------------------------------------- player bullets
wire p_bullet_active_1, p_bullet_active_2, p_bullet_active_3;
wire [XW-1:0] p_bullet_x_1, p_bullet_x_2, p_bullet_x_3;
wire [YW-1:0] p_bullet_y_1, p_bullet_y_2, p_bullet_y_3;
wire p_bullet_rest_1, p_bullet_rest_2, p_bullet_rest_3; // from damage_detect

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
    .p_bullet_rest_1(p_bullet_rest_1),
    .p_bullet_rest_2(p_bullet_rest_2),
    .p_bullet_rest_3(p_bullet_rest_3),
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

// ---------------------------------------------------------------- boss
wire [XW-1:0] b_x;
wire [YW-1:0] b_y;
wire b_bullet_fire;

boss #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .BOSS_WIDTH(BOSS_WIDTH),
    .BOSS_Y(BOSS_Y),
    .BOSS_SPEED(BOSS_SPEED),
    .MOVE_CYCLES(FRAME_CYCLES),
    .FIRE_CYCLES(BOSS_FIRE_CYCLES)
) b (
    .CLOCK_50(CLOCK_50),
    .resetn(resetn),
    .b_x(b_x),
    .b_y(b_y),
    .b_bullet_fire(b_bullet_fire)
);

// ---------------------------------------------------------------- boss bullets
wire b_bullet_active_1, b_bullet_active_2, b_bullet_active_3;
wire [XW-1:0] b_bullet_x_1, b_bullet_x_2, b_bullet_x_3;
wire [YW-1:0] b_bullet_y_1, b_bullet_y_2, b_bullet_y_3;
wire b_bullet_rest_1, b_bullet_rest_2, b_bullet_rest_3; // from damage_detect

boss_bullet #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .BOSS_WIDTH(BOSS_WIDTH),
    .BOSS_HEIGHT(BOSS_HEIGHT),
    .PLAYER_WIDTH(PLAYER_WIDTH),
    .PLAYER_HEIGHT(PLAYER_HEIGHT),
    .BOSS_BULLET_WIDTH(BOSS_BULLET_WIDTH),
    .BOSS_BULLET_HEIGHT(BOSS_BULLET_HEIGHT),
    .BULLET_SPEED(BOSS_BULLET_SPEED),
    .MOVE_CYCLES(FRAME_CYCLES),
    .BURST_GAP_TICKS(BURST_GAP_TICKS)
) b_bullet (
    .CLOCK_50(CLOCK_50),
    .resetn(resetn),
    .b_bullet_fire(b_bullet_fire),
    .b_x(b_x),
    .p_x(p_x),
    .b_y(b_y),
    .p_y(p_y),
    .b_bullet_rest_1(b_bullet_rest_1),
    .b_bullet_rest_2(b_bullet_rest_2),
    .b_bullet_rest_3(b_bullet_rest_3),
    .b_bullet_active_1(b_bullet_active_1),
    .b_bullet_active_2(b_bullet_active_2),
    .b_bullet_active_3(b_bullet_active_3),
    .b_bullet_x_1(b_bullet_x_1),
    .b_bullet_x_2(b_bullet_x_2),
    .b_bullet_x_3(b_bullet_x_3),
    .b_bullet_y_1(b_bullet_y_1),
    .b_bullet_y_2(b_bullet_y_2),
    .b_bullet_y_3(b_bullet_y_3)
);

// ---------------------------------------------------------------- damage + HP
wire p_damage, b_damage;
wire [HP_W-1:0] p_hp, b_hp;

damage_detect #(
    .XW(XW), .YW(YW),
    .PLAYER_WIDTH(PLAYER_WIDTH), .PLAYER_HEIGHT(PLAYER_HEIGHT),
    .BOSS_WIDTH(BOSS_WIDTH), .BOSS_HEIGHT(BOSS_HEIGHT),
    .PLAYER_BULLET_WIDTH(PLAYER_BULLET_WIDTH), .PLAYER_BULLET_HEIGHT(PLAYER_BULLET_HEIGHT),
    .BOSS_BULLET_WIDTH(BOSS_BULLET_WIDTH), .BOSS_BULLET_HEIGHT(BOSS_BULLET_HEIGHT)
) u_damage (
    .clk(CLOCK_50),
    .resetn(resetn),
    .p_x(p_x), .p_y(p_y),
    .b_x(b_x), .b_y(b_y),
    .p_bullet_x_1(p_bullet_x_1), .p_bullet_x_2(p_bullet_x_2), .p_bullet_x_3(p_bullet_x_3),
    .p_bullet_y_1(p_bullet_y_1), .p_bullet_y_2(p_bullet_y_2), .p_bullet_y_3(p_bullet_y_3),
    .p_bullet_active_1(p_bullet_active_1), .p_bullet_active_2(p_bullet_active_2), .p_bullet_active_3(p_bullet_active_3),
    .b_bullet_x_1(b_bullet_x_1), .b_bullet_x_2(b_bullet_x_2), .b_bullet_x_3(b_bullet_x_3),
    .b_bullet_y_1(b_bullet_y_1), .b_bullet_y_2(b_bullet_y_2), .b_bullet_y_3(b_bullet_y_3),
    .b_bullet_active_1(b_bullet_active_1), .b_bullet_active_2(b_bullet_active_2), .b_bullet_active_3(b_bullet_active_3),
    .b_damage(b_damage),
    .p_bullet_rest_1(p_bullet_rest_1), .p_bullet_rest_2(p_bullet_rest_2), .p_bullet_rest_3(p_bullet_rest_3),
    .p_damage(p_damage),
    .b_bullet_rest_1(b_bullet_rest_1), .b_bullet_rest_2(b_bullet_rest_2), .b_bullet_rest_3(b_bullet_rest_3)
);

hp_update #(
    .HP_W(HP_W),
    .MAX_HP(MAX_HP)
) u_hp (
    .clk(CLOCK_50),
    .resetn(resetn),
    .restart(1'b0), // KEY[0] reset already refills HP; game_fsm can use this later
    .p_damage(p_damage),
    .b_damage(b_damage),
    .p_hp(p_hp),
    .b_hp(b_hp)
);

// ---------------------------------------------------------------- display + VGA
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
    .PLAYER_BULLET_HEIGHT(PLAYER_BULLET_HEIGHT),
    .BOSS_WIDTH(BOSS_WIDTH),
    .BOSS_HEIGHT(BOSS_HEIGHT),
    .BOSS_BULLET_WIDTH(BOSS_BULLET_WIDTH),
    .BOSS_BULLET_HEIGHT(BOSS_BULLET_HEIGHT),
    .HP_W(HP_W),
    .MAX_HP(MAX_HP)
) u_display (
    .clk(CLOCK_50),
    .resetn(resetn),
    .frame_tick(frame_tick),
    .p_x(p_x),
    .p_y(p_y),
    .p_bullet_x_1(p_bullet_x_1), .p_bullet_y_1(p_bullet_y_1), .p_bullet_active_1(p_bullet_active_1),
    .p_bullet_x_2(p_bullet_x_2), .p_bullet_y_2(p_bullet_y_2), .p_bullet_active_2(p_bullet_active_2),
    .p_bullet_x_3(p_bullet_x_3), .p_bullet_y_3(p_bullet_y_3), .p_bullet_active_3(p_bullet_active_3),
    .b_x(b_x),
    .b_y(b_y),
    .b_bullet_x_1(b_bullet_x_1), .b_bullet_y_1(b_bullet_y_1), .b_bullet_active_1(b_bullet_active_1),
    .b_bullet_x_2(b_bullet_x_2), .b_bullet_y_2(b_bullet_y_2), .b_bullet_active_2(b_bullet_active_2),
    .b_bullet_x_3(b_bullet_x_3), .b_bullet_y_3(b_bullet_y_3), .b_bullet_active_3(b_bullet_active_3),
    .p_hp(p_hp),
    .b_hp(b_hp),
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
assign LEDR[4] = b_bullet_active_1;
assign LEDR[5] = b_bullet_active_2;
assign LEDR[6] = b_bullet_active_3;
assign LEDR[7] = 1'b0;
assign LEDR[8] = (b_hp == 0);
assign LEDR[9] = (p_hp == 0);

endmodule
