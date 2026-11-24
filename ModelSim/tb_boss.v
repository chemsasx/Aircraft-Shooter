// ============================================================================
// tb_boss.v  -  testbench for boss (Jianqi's version: own move / fire counters)
// ----------------------------------------------------------------------------
// Small numbers so the result is easy to check by hand:
//   screen 40 wide, boss 10 wide  -> x can go from 0 to 30
//   start x = MAX_X / 2 = 15, speed = 3 pixels per move
//   MOVE_CYCLES = 4  -> the boss moves once every 4 clocks
//   FIRE_CYCLES = 30 -> b_bullet_fire is 1 for one clock every 30 clocks
//
// Expected Transcript (x and direction right AFTER each move):
//   18 R, 21 R, 24 R, 27 R, 30 L   <- reached the right edge, turned around
//   27 L, 24 L, 21 L, 18 L, 15 L, 12 L, 9 L, 6 L, 3 L, 0 R  <- left edge
//   3 R, 6 R, ...
//   plus a "b_bullet_fire" line every 30 clocks (600 ns)
// ============================================================================
`timescale 1ns / 1ns

module tb_boss;

    reg        clk, resetn;
    wire [9:0] b_x;
    wire [8:0] b_y;
    wire       b_bullet_fire;

    boss #(
        .SCREEN_WIDTH(40),
        .BOSS_WIDTH(10),
        .BOSS_Y(5),
        .BOSS_SPEED(3),
        .MOVE_CYCLES(4),
        .FIRE_CYCLES(30)
    ) dut (
        .CLOCK_50(clk), .resetn(resetn),
        .b_x(b_x), .b_y(b_y), .b_bullet_fire(b_bullet_fire)
    );

    // 50 MHz clock: period 20 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // print after every move ($strobe prints at the END of this time step,
    // so it shows the NEW x and direction)
    always @(posedge clk)
        if (resetn && dut.move_count == 4 - 1)
            $strobe("%t  move: x = %2d  %s", $time, b_x, dut.move_right ? "RIGHT" : "LEFT ");

    // print every shot
    always @(posedge clk)
        if (b_bullet_fire)
            $display("%t        b_bullet_fire (boss at x = %0d)", $time, b_x);

    initial begin
        resetn = 0;
        @(negedge clk);  @(negedge clk);
        resetn = 1;
        $display("after reset: x = %0d, y = %0d", b_x, b_y);

        repeat (4 * 20) @(negedge clk);           // 20 moves

        $display("---- finished ----");
        $stop;
    end

endmodule
