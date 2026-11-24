// The screen and objects are made SMALL with parameters so the simulation is
// short (same logic, smaller numbers):
//   screen 32 x 24, player 4 x 4, boss 4 x 2, all bullets 1 x 2
//   MAX_HP = 2, each HP point = 2 px, bar height 1
//   -> bars are 4 px wide, start at x = (32 - 4) / 2 = 14,
//      boss bar at y = 4, player bar at y = 24 - 1 - 4 = 19
// frame_tick is given by hand (one 1-clock pulse per "frame").
// Only bullet 1 of each side is used, bullets 2 and 3 stay inactive.
//
// Colours in the Transcript:
// 000000000 = black (erase)      000111111 = cyan    (player)
// 111111000 = yellow (p bullet)  111000111 = magenta (boss)
// 111100000 = orange (b bullet)  111000000 = red     (boss HP left)
// 000111000 = green (player HP)  010010010 = grey    (HP lost)
//
// What should happen:
//   after reset : the whole 32x24 screen is cleared (not printed, 768 pixels)
//   FRAME 1 : player at (5,10), boss at (20,8), both HP = 2
//             -> erase old player (0,0) and old boss (0,0) (black),
//                draw boss, draw player, boss bar 4 px red, player bar 4 px green
//   FRAME 2 : player moves to (6,10), player bullet at (7,5), boss bullet at (22,12)
//             -> erase player (5,10), boss NOT erased (did not move),
//                draw boss, p bullet (7,5)(7,6), b bullet (22,12)(22,13), player, bars
//   FRAME 3 : boss moves to (21,8), p bullet to (7,4), b bullet to (22,14), boss HP = 1
//             -> erase boss (20,8), erase both bullets at the old places,
//                draw everything at the new places,
//                boss bar = 2 px red (14,4)(15,4) + 2 px grey (16,4)(17,4)
//   FRAME 4 : both bullets disappear, player HP = 1
//             -> erase both bullets, draw boss and player again,
//                player bar = 2 px green (14,19)(15,19) + 2 px grey (16,19)(17,19)
// ============================================================================
`timescale 1ns / 1ns

module tb_display;

    reg        clk, resetn, frame_tick;
    reg  [9:0] p_x, b_x;
    reg  [8:0] p_y, b_y;
    reg  [9:0] p_bullet_x_1, b_bullet_x_1;
    reg  [8:0] p_bullet_y_1, b_bullet_y_1;
    reg        p_bullet_active_1, b_bullet_active_1;
    reg  [1:0] p_hp, b_hp;              // HP_W = 2

    wire       vga_plot;
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_colour;

    // device under test, with a small screen and small objects
    display #(
        .SCREEN_WIDTH(32),         .SCREEN_HEIGHT(24),
        .PLAYER_WIDTH(4),          .PLAYER_HEIGHT(4),
        .PLAYER_BULLET_WIDTH(1),   .PLAYER_BULLET_HEIGHT(2),
        .BOSS_WIDTH(4),            .BOSS_HEIGHT(2),
        .BOSS_BULLET_WIDTH(1),     .BOSS_BULLET_HEIGHT(2),
        .HP_W(2), .MAX_HP(2), .HP_UNIT_W(2), .BAR_H(1)
    ) dut (
        .clk(clk), .resetn(resetn), .frame_tick(frame_tick),
        .p_x(p_x), .p_y(p_y),
        .p_bullet_x_1(p_bullet_x_1), .p_bullet_y_1(p_bullet_y_1), .p_bullet_active_1(p_bullet_active_1),
        .p_bullet_x_2(10'd0), .p_bullet_y_2(9'd0), .p_bullet_active_2(1'b0),
        .p_bullet_x_3(10'd0), .p_bullet_y_3(9'd0), .p_bullet_active_3(1'b0),
        .b_x(b_x), .b_y(b_y),
        .b_bullet_x_1(b_bullet_x_1), .b_bullet_y_1(b_bullet_y_1), .b_bullet_active_1(b_bullet_active_1),
        .b_bullet_x_2(10'd0), .b_bullet_y_2(9'd0), .b_bullet_active_2(1'b0),
        .b_bullet_x_3(10'd0), .b_bullet_y_3(9'd0), .b_bullet_active_3(1'b0),
        .p_hp(p_hp), .b_hp(b_hp),
        .vga_plot(vga_plot), .vga_x(vga_x), .vga_y(vga_y), .vga_colour(vga_colour)
    );

    // 50 MHz clock: period 20 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // print pixels, but not the 768 pixels of the screen clear
    reg show_pixels;
    always @(posedge clk)
        if (vga_plot && show_pixels)
            $display("%t  plot (%0d, %0d)  colour = %b", $time, vga_x, vga_y, vga_colour);

    initial begin
        // reset, nothing on screen
        resetn = 0;  frame_tick = 0;  show_pixels = 0;
        p_x = 0;  p_y = 0;  b_x = 0;  b_y = 0;
        p_bullet_x_1 = 0;  p_bullet_y_1 = 0;  p_bullet_active_1 = 0;
        b_bullet_x_1 = 0;  b_bullet_y_1 = 0;  b_bullet_active_1 = 0;
        p_hp = 2;  b_hp = 2;
        @(negedge clk);  @(negedge clk);
        resetn = 1;

        // wait for the full-screen clear (32 * 24 = 768 pixels)
        repeat (1000) @(negedge clk);
        show_pixels = 1;

        // FRAME 1: player and boss appear
        $display("---- FRAME 1: player at (5,10), boss at (20,8), HP 2 / 2 ----");
        p_x = 5;  p_y = 10;  b_x = 20;  b_y = 8;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;   // 1-clock pulse
        repeat (300) @(negedge clk);

        // FRAME 2: player moves right by 1, one bullet of each side appears
        $display("---- FRAME 2: player to (6,10), p bullet at (7,5), b bullet at (22,12) ----");
        p_x = 6;
        p_bullet_x_1 = 7;   p_bullet_y_1 = 5;   p_bullet_active_1 = 1;
        b_bullet_x_1 = 22;  b_bullet_y_1 = 12;  b_bullet_active_1 = 1;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;
        repeat (300) @(negedge clk);

        // FRAME 3: boss moves, bullets move, boss loses 1 HP
        $display("---- FRAME 3: boss to (21,8), p bullet to (7,4), b bullet to (22,14), boss HP 1 ----");
        b_x = 21;  p_bullet_y_1 = 4;  b_bullet_y_1 = 14;  b_hp = 1;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;
        repeat (300) @(negedge clk);

        // FRAME 4: bullets disappear, player loses 1 HP
        $display("---- FRAME 4: bullets disappear, player HP 1 ----");
        p_bullet_active_1 = 0;  b_bullet_active_1 = 0;  p_hp = 1;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;
        repeat (300) @(negedge clk);

        $display("---- finished ----");
        $stop;
    end

endmodule
