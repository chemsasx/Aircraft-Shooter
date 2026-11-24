// ============================================================================
// tb_damage_hp.v  -  testbench for damage_detect + hp_update together
// ----------------------------------------------------------------------------
// Small sizes:  boss 10 x 5 at (20,10),  player 4 x 4 at (20,40),
//               all bullets 1 x 2,  MAX_HP = 16
// Only bullet 1 of each side is used, bullets 2 and 3 stay inactive.
//
// What should happen:
//   TEST 1: player bullet 1 at (25,20)   -> below the boss, no hit,  boss HP 16
//   TEST 2: player bullet 1 at (25,14)   -> inside the boss:
//           p_bullet_rest_1 + b_damage for ONE clock, boss HP 16 -> 15.
//           The bullet stays there for 5 clocks (this testbench does not
//           react to rest), but HP only drops ONCE  (edge detection)
//   TEST 3: same bullet, but active = 0  -> no hit (inactive bullets are ignored)
//   TEST 4: boss bullet 1 at (23,39)     -> its bottom row y = 40 touches the
//           player: b_bullet_rest_1 + p_damage for ONE clock, player HP 16 -> 15
//   TEST 5: boss bullet 1 at (24,41)     -> x = 24 = player right edge, no hit
//           (strict "<": only touching the edge is not a hit)
// ============================================================================
`timescale 1ns / 1ns

module tb_damage_hp;

    reg        clk, resetn;
    reg  [9:0] p_x, b_x, p_bullet_x_1, b_bullet_x_1;
    reg  [8:0] p_y, b_y, p_bullet_y_1, b_bullet_y_1;
    reg        p_bullet_active_1, b_bullet_active_1;

    wire b_damage, p_damage;
    wire p_bullet_rest_1, p_bullet_rest_2, p_bullet_rest_3;
    wire b_bullet_rest_1, b_bullet_rest_2, b_bullet_rest_3;
    wire [4:0] p_hp, b_hp;

    damage_detect #(
        .PLAYER_WIDTH(4),        .PLAYER_HEIGHT(4),
        .BOSS_WIDTH(10),         .BOSS_HEIGHT(5),
        .PLAYER_BULLET_WIDTH(1), .PLAYER_BULLET_HEIGHT(2),
        .BOSS_BULLET_WIDTH(1),   .BOSS_BULLET_HEIGHT(2)
    ) dut_damage (
        .clk(clk), .resetn(resetn),
        .p_x(p_x), .p_y(p_y), .b_x(b_x), .b_y(b_y),
        .p_bullet_x_1(p_bullet_x_1), .p_bullet_x_2(10'd0), .p_bullet_x_3(10'd0),
        .p_bullet_y_1(p_bullet_y_1), .p_bullet_y_2(9'd0),  .p_bullet_y_3(9'd0),
        .p_bullet_active_1(p_bullet_active_1), .p_bullet_active_2(1'b0), .p_bullet_active_3(1'b0),
        .b_bullet_x_1(b_bullet_x_1), .b_bullet_x_2(10'd0), .b_bullet_x_3(10'd0),
        .b_bullet_y_1(b_bullet_y_1), .b_bullet_y_2(9'd0),  .b_bullet_y_3(9'd0),
        .b_bullet_active_1(b_bullet_active_1), .b_bullet_active_2(1'b0), .b_bullet_active_3(1'b0),
        .b_damage(b_damage),
        .p_bullet_rest_1(p_bullet_rest_1), .p_bullet_rest_2(p_bullet_rest_2), .p_bullet_rest_3(p_bullet_rest_3),
        .p_damage(p_damage),
        .b_bullet_rest_1(b_bullet_rest_1), .b_bullet_rest_2(b_bullet_rest_2), .b_bullet_rest_3(b_bullet_rest_3)
    );

    hp_update dut_hp (
        .clk(clk), .resetn(resetn), .restart(1'b0),
        .p_damage(p_damage), .b_damage(b_damage),
        .p_hp(p_hp), .b_hp(b_hp)
    );

    // 50 MHz clock: period 20 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // print every hit pulse
    always @(posedge clk) begin
        if (b_damage) $display("%t    b_damage  (p_bullet_rest_1 = %b)", $time, p_bullet_rest_1);
        if (p_damage) $display("%t    p_damage  (b_bullet_rest_1 = %b)", $time, b_bullet_rest_1);
    end

    initial begin
        resetn = 0;
        b_x = 20;  b_y = 10;  p_x = 20;  p_y = 40;
        p_bullet_x_1 = 0;  p_bullet_y_1 = 0;  p_bullet_active_1 = 0;
        b_bullet_x_1 = 0;  b_bullet_y_1 = 0;  b_bullet_active_1 = 0;
        @(negedge clk);  @(negedge clk);
        resetn = 1;
        @(negedge clk);
        $display("after reset: player HP = %0d, boss HP = %0d", p_hp, b_hp);

        $display("---- TEST 1: player bullet below the boss ----");
        p_bullet_x_1 = 25;  p_bullet_y_1 = 20;  p_bullet_active_1 = 1;
        repeat (5) @(negedge clk);
        $display("boss HP = %0d", b_hp);

        $display("---- TEST 2: player bullet inside the boss for 5 clocks ----");
        p_bullet_y_1 = 14;
        repeat (5) @(negedge clk);
        $display("boss HP = %0d", b_hp);

        $display("---- TEST 3: same place, bullet inactive ----");
        p_bullet_active_1 = 0;
        repeat (2) @(negedge clk);
        p_bullet_y_1 = 20;  repeat (2) @(negedge clk);   // move away, then come back inactive
        p_bullet_y_1 = 14;  repeat (5) @(negedge clk);
        $display("boss HP = %0d", b_hp);

        $display("---- TEST 4: boss bullet touches the player ----");
        b_bullet_x_1 = 23;  b_bullet_y_1 = 39;  b_bullet_active_1 = 1;
        repeat (5) @(negedge clk);
        $display("player HP = %0d", p_hp);

        $display("---- TEST 5: boss bullet just right of the player ----");
        b_bullet_active_1 = 0;  @(negedge clk);
        b_bullet_x_1 = 24;  b_bullet_y_1 = 41;  b_bullet_active_1 = 1;
        repeat (5) @(negedge clk);
        $display("player HP = %0d", p_hp);

        $display("---- finished ----");
        $stop;
    end

endmodule
