// The screen and objects are made SMALL with parameters so the simulation is
// short (same logic, smaller numbers):
//   screen 32 x 24, player 4 x 4, bullet 1 x 2
// frame_tick is given by hand (one 1-clock pulse per "frame").
//
// Colours in the Transcript:  
// 000000000 = black (erase)
// 000111111 = cyan  (player)
// 111111000 = yellow (bullet)
//
// What should happen (only bullet 1 is used, bullets 2 and 3 stay inactive):
//   after reset : the whole 32x24 screen is cleared (not printed, 768 pixels)
//   FRAME 1 : player at (5,10)
//             -> erase old player at (0,0) (black), draw player at (5,10)
//   FRAME 2 : player moves to (6,10), bullet 1 appears at (7,5)
//             -> erase (5,10) black, draw bullet (7,5)(7,6), draw player (6,10)
//   FRAME 3 : player stays, bullet 1 moves up to (7,4)
//             -> player NOT erased, erase bullet (7,5)(7,6),
//                draw bullet (7,4)(7,5), draw player again
//   FRAME 4 : bullet 1 disappears
//             -> erase bullet (7,4)(7,5), draw player again
// ============================================================================
`timescale 1ns / 1ns

module tb_display;

    reg        clk, resetn, frame_tick;
    reg  [9:0] p_x;
    reg  [8:0] p_y;
    reg  [9:0] p_bullet_x_1, p_bullet_x_2, p_bullet_x_3;
    reg  [8:0] p_bullet_y_1, p_bullet_y_2, p_bullet_y_3;
    reg        p_bullet_active_1, p_bullet_active_2, p_bullet_active_3;

    wire       vga_plot;
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_colour;

    // device under test, with a small screen and small objects
    display #(
        .SCREEN_WIDTH(32),         .SCREEN_HEIGHT(24),
        .PLAYER_WIDTH(4),          .PLAYER_HEIGHT(4),
        .PLAYER_BULLET_WIDTH(1),   .PLAYER_BULLET_HEIGHT(2)
    ) dut (
        .clk(clk), .resetn(resetn), .frame_tick(frame_tick),
        .p_x(p_x), .p_y(p_y),
        .p_bullet_x_1(p_bullet_x_1), .p_bullet_y_1(p_bullet_y_1), .p_bullet_active_1(p_bullet_active_1),
        .p_bullet_x_2(p_bullet_x_2), .p_bullet_y_2(p_bullet_y_2), .p_bullet_active_2(p_bullet_active_2),
        .p_bullet_x_3(p_bullet_x_3), .p_bullet_y_3(p_bullet_y_3), .p_bullet_active_3(p_bullet_active_3),
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
        p_x = 0;  p_y = 0;
        p_bullet_x_1 = 0;  p_bullet_y_1 = 0;  p_bullet_active_1 = 0;
        p_bullet_x_2 = 0;  p_bullet_y_2 = 0;  p_bullet_active_2 = 0;
        p_bullet_x_3 = 0;  p_bullet_y_3 = 0;  p_bullet_active_3 = 0;
        @(negedge clk);  @(negedge clk);
        resetn = 1;

        // wait for the full-screen clear (32 * 24 = 768 pixels)
        repeat (1000) @(negedge clk);
        show_pixels = 1;

        // FRAME 1: player appears at (5,10)
        $display("---- FRAME 1: player at (5,10) ----");
        p_x = 5;  p_y = 10;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;   // 1-clock pulse
        repeat (200) @(negedge clk);

        // FRAME 2: player moves right by 1, bullet 1 appears
        $display("---- FRAME 2: player to (6,10), bullet at (7,5) ----");
        p_x = 6;
        p_bullet_x_1 = 7;  p_bullet_y_1 = 5;  p_bullet_active_1 = 1;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;
        repeat (200) @(negedge clk);

        // FRAME 3: player stays, bullet moves up by 1
        $display("---- FRAME 3: player stays, bullet to (7,4) ----");
        p_bullet_y_1 = 4;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;
        repeat (200) @(negedge clk);

        // FRAME 4: bullet disappears
        $display("---- FRAME 4: bullet disappears ----");
        p_bullet_active_1 = 0;
        frame_tick = 1;  @(negedge clk);  frame_tick = 0;
        repeat (200) @(negedge clk);

        $display("---- finished ----");
        $stop;
    end

endmodule
