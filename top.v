// ============================================================================
// top  -  board top level: mouse -> player -> player bullets -> display -> VGA
// ----------------------------------------------------------------------------
// Current goal: the player follows the mouse, a left click fires a burst of
// 3 bullets, and both are drawn on the 640x480 screen without trails.
// (Boss, damage and HP bars are not connected yet.)
//
//   KEY[0]      reset (active-low)
//   mouse       move = move the player, left click = fire (right button not held)
//   LEDR[0]     right mouse button held (shows the mouse is being decoded)
//   LEDR[3:1]   bullet 3..1 active
//
// All game constants live here (values taken from player.v, player_bullet.v
// and mouse_decoder.v) and are passed down with #( ).
// ============================================================================
module top #(
    // ---- screen (640x480 -> x needs 10 bits, y needs 9 bits) ----
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter XW = 10,                              // bits for x: 0..639
    parameter YW = 9,                               // bits for y: 0..479
    parameter CW = 9,                               // colour bits {RRR,GGG,BBB}

    // ---- player (top-left corner position) ----
    parameter PLAYER_WIDTH  = 36,
    parameter PLAYER_HEIGHT = 48,

    // ---- player bullets ----
    parameter PLAYER_BULLET_WIDTH  = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter integer PLAYER_BULLET_RELATIVE_X = 16, // (36 - 4) / 2: bullet starts at the player's centre
    parameter integer PLAYER_BULLET_RELATIVE_Y = -8, // bullet starts just above the player
    parameter BULLET_SPEED    = 4,                   // pixels per frame
    parameter BURST_GAP_TICKS = 6,                   // frames between the 3 bullets of a burst

    // ---- timing ----
    parameter FRAME_CYCLES = 833333,                 // 50 MHz / 60 Hz
    parameter COUNT_W      = 20                      // 2^20 > 833,333
)(
    input        CLOCK_50,
    input  [3:0] KEY,
    inout        PS2_CLK,
    inout        PS2_DAT,
    output [9:0] LEDR,
    output [7:0] VGA_R, VGA_G, VGA_B,
    output       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);

    wire resetn;
    assign resetn = KEY[0];

    // ========================================================================
    // 60 Hz frame pulse: bullets move and the screen is redrawn once per frame
    // ========================================================================
    wire frame_tick;

    frame_tick #(
        .FRAME_CYCLES(FRAME_CYCLES),
        .COUNT_W(COUNT_W)
    ) u_frame_tick (
        .clk(CLOCK_50),
        .resetn(resetn),
        .frame_tick(frame_tick)
    );

    // ========================================================================
    // Mouse
    // ========================================================================
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

    // ========================================================================
    // Player
    // ========================================================================
    wire move_en;
    assign move_en = (dx != 9'sd0) || (dy != 9'sd0);

    wire [XW-1:0] p_x;
    wire [YW-1:0] p_y;
    wire p_bullet_fire, p_laser_fire;              // p_laser_fire: not used yet (M2)

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

    // ========================================================================
    // Player bullets (a burst of up to 3)
    // ========================================================================
    wire          p_bullet_active_1, p_bullet_active_2, p_bullet_active_3;
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
        .move_tick(frame_tick),                    // bullets move once per frame
        .p_bullet_fire(p_bullet_fire),
        .p_x(p_x),
        .p_y(p_y),
        .p_bullet_rest_1(1'b0),                    // no damage_detect yet -> never reset by a hit
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

    // ========================================================================
    // Display -> VGA adapter
    // NOTE: display.v must be updated (plan step 5) to have these parameters
    //       and ports before this file compiles.
    // ========================================================================
    wire          vga_plot;
    wire [XW-1:0] vga_x;
    wire [YW-1:0] vga_y;
    wire [CW-1:0] vga_colour;

    display #(
        .XW(XW), .YW(YW), .CW(CW),
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
        .p_bullet_x_1(p_bullet_x_1), .p_bullet_y_1(p_bullet_y_1), .p_bullet_active_1(p_bullet_active_1),
        .p_bullet_x_2(p_bullet_x_2), .p_bullet_y_2(p_bullet_y_2), .p_bullet_active_2(p_bullet_active_2),
        .p_bullet_x_3(p_bullet_x_3), .p_bullet_y_3(p_bullet_y_3), .p_bullet_active_3(p_bullet_active_3),
        .vga_plot(vga_plot),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_colour(vga_colour)
    );

    vga_adapter #(
        .RESOLUTION("640x480"),                     // must match XW = 10, YW = 9
        .COLOR_DEPTH(CW),
        .BACKGROUND_IMAGE("./MIF/black_640_9.mif")
    ) VGA (
        .resetn(resetn),
        .clock(CLOCK_50),
        .color(vga_colour),
        .x(vga_x),
        .y(vga_y),
        .write(vga_plot),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK)
    );

    // ========================================================================
    // Debug LEDs
    // ========================================================================
    assign LEDR[0]   = right_down;
    assign LEDR[1]   = p_bullet_active_1;
    assign LEDR[2]   = p_bullet_active_2;
    assign LEDR[3]   = p_bullet_active_3;
    assign LEDR[9:4] = 6'b0;

endmodule
