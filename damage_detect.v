// ============================================================================
// damage_detect.v  -  collisions between bullets and planes
// ----------------------------------------------------------------------------
//   player bullet 1..3  vs  boss    -> b_damage  + p_bullet_rest_1..3
//   boss   bullet 1..3  vs  player  -> p_damage  + b_bullet_rest_1..3
//
// "rest" = remove that bullet. The names match the ports of Jianqi's
// player_bullet (p_bullet_rest_i) and boss_bullet (b_bullet_rest_i).
//
// A hit is counted ONCE: only on the clock where "touching" goes 0 -> 1.
// All outputs are 1-clock pulses.
// If two bullets hit on the same clock, both bullets are removed but the
// HP only goes down by 1 (very rare: bullets of a burst are 6 frames apart).
//
// Every (x, y) is the TOP-LEFT corner. Sizes come from top.v as parameters.
// ============================================================================


// ---------------------------------------------------------------------------
// rect_overlap : do rectangle A and rectangle B overlap?  (AABB test)
//   x ranges overlap:  a_x < b_x + B_W   and   b_x < a_x + A_W
//   y ranges overlap:  a_y < b_y + B_H   and   b_y < a_y + A_H
// strict "<": rectangles that only touch at an edge do NOT overlap
// ---------------------------------------------------------------------------
module rect_overlap #(
    parameter XW = 10,
    parameter YW = 9,
    parameter A_W = 1, parameter A_H = 1,     // size of A
    parameter B_W = 1, parameter B_H = 1      // size of B
)(
    input  [XW-1:0] a_x,
    input  [YW-1:0] a_y,
    input  [XW-1:0] b_x,
    input  [YW-1:0] b_y,
    output overlap
);

    // one extra bit so x + width cannot wrap around to a small number
    wire [XW:0] a_right  = {1'b0, a_x} + A_W;
    wire [XW:0] b_right  = {1'b0, b_x} + B_W;
    wire [YW:0] a_bottom = {1'b0, a_y} + A_H;
    wire [YW:0] b_bottom = {1'b0, b_y} + B_H;

    wire x_overlap = ({1'b0, a_x} < b_right)  && ({1'b0, b_x} < a_right);
    wire y_overlap = ({1'b0, a_y} < b_bottom) && ({1'b0, b_y} < a_bottom);

    assign overlap = x_overlap && y_overlap;

endmodule


// ---------------------------------------------------------------------------
// hit_pulse : active && touching, then a rising-edge detector
//   hit_now   = bullet is active AND overlaps the target
//   hit_event = hit_now is 1 now but was 0 one clock ago  -> 1-clock pulse
// (a bullet that already disappeared may still hold its old x, y,
//  so "active" is checked first)
// ---------------------------------------------------------------------------
module hit_pulse (
    input  clk,
    input  resetn,
    input  active,
    input  touching,
    output hit_event
);

    wire hit_now = active && touching;
    reg  hit_prev;                           // hit_now one clock ago

    always @(posedge clk) begin
        if (!resetn) hit_prev <= 1'b0;
        else         hit_prev <= hit_now;
    end

    assign hit_event = hit_now && !hit_prev;

endmodule


// ---------------------------------------------------------------------------
// damage_detect
// ---------------------------------------------------------------------------
module damage_detect #(
    parameter XW = 10,
    parameter YW = 9,
    parameter PLAYER_WIDTH  = 36,
    parameter PLAYER_HEIGHT = 48,
    parameter BOSS_WIDTH    = 64,
    parameter BOSS_HEIGHT   = 48,
    parameter PLAYER_BULLET_WIDTH  = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter BOSS_BULLET_WIDTH    = 4,
    parameter BOSS_BULLET_HEIGHT   = 8
)(
    input clk,
    input resetn,

    // planes
    input [XW-1:0] p_x,
    input [YW-1:0] p_y,
    input [XW-1:0] b_x,
    input [YW-1:0] b_y,

    // player bullets (from player_bullet)
    input [XW-1:0] p_bullet_x_1, p_bullet_x_2, p_bullet_x_3,
    input [YW-1:0] p_bullet_y_1, p_bullet_y_2, p_bullet_y_3,
    input          p_bullet_active_1, p_bullet_active_2, p_bullet_active_3,

    // boss bullets (from boss_bullet)
    input [XW-1:0] b_bullet_x_1, b_bullet_x_2, b_bullet_x_3,
    input [YW-1:0] b_bullet_y_1, b_bullet_y_2, b_bullet_y_3,
    input          b_bullet_active_1, b_bullet_active_2, b_bullet_active_3,

    output b_damage,                                            // -> hp_update: boss loses 1 HP
    output p_bullet_rest_1, p_bullet_rest_2, p_bullet_rest_3,   // -> player_bullet: remove bullet i
    output p_damage,                                            // -> hp_update: player loses 1 HP
    output b_bullet_rest_1, b_bullet_rest_2, b_bullet_rest_3    // -> boss_bullet: remove bullet i
);

    // ---------------- player bullets vs boss ----------------
    wire p_bullet_touch_1, p_bullet_touch_2, p_bullet_touch_3;

    rect_overlap #(.XW(XW), .YW(YW),
                   .A_W(PLAYER_BULLET_WIDTH), .A_H(PLAYER_BULLET_HEIGHT),
                   .B_W(BOSS_WIDTH),          .B_H(BOSS_HEIGHT)) u_p_bullet_1_vs_boss (
        .a_x(p_bullet_x_1), .a_y(p_bullet_y_1), .b_x(b_x), .b_y(b_y), .overlap(p_bullet_touch_1)
    );
    rect_overlap #(.XW(XW), .YW(YW),
                   .A_W(PLAYER_BULLET_WIDTH), .A_H(PLAYER_BULLET_HEIGHT),
                   .B_W(BOSS_WIDTH),          .B_H(BOSS_HEIGHT)) u_p_bullet_2_vs_boss (
        .a_x(p_bullet_x_2), .a_y(p_bullet_y_2), .b_x(b_x), .b_y(b_y), .overlap(p_bullet_touch_2)
    );
    rect_overlap #(.XW(XW), .YW(YW),
                   .A_W(PLAYER_BULLET_WIDTH), .A_H(PLAYER_BULLET_HEIGHT),
                   .B_W(BOSS_WIDTH),          .B_H(BOSS_HEIGHT)) u_p_bullet_3_vs_boss (
        .a_x(p_bullet_x_3), .a_y(p_bullet_y_3), .b_x(b_x), .b_y(b_y), .overlap(p_bullet_touch_3)
    );

    hit_pulse u_p_hit_1 (.clk(clk), .resetn(resetn), .active(p_bullet_active_1),
                         .touching(p_bullet_touch_1), .hit_event(p_bullet_rest_1));
    hit_pulse u_p_hit_2 (.clk(clk), .resetn(resetn), .active(p_bullet_active_2),
                         .touching(p_bullet_touch_2), .hit_event(p_bullet_rest_2));
    hit_pulse u_p_hit_3 (.clk(clk), .resetn(resetn), .active(p_bullet_active_3),
                         .touching(p_bullet_touch_3), .hit_event(p_bullet_rest_3));

    // any player bullet hit the boss -> boss loses 1 HP
    assign b_damage = p_bullet_rest_1 || p_bullet_rest_2 || p_bullet_rest_3;

    // ---------------- boss bullets vs player ----------------
    wire b_bullet_touch_1, b_bullet_touch_2, b_bullet_touch_3;

    rect_overlap #(.XW(XW), .YW(YW),
                   .A_W(BOSS_BULLET_WIDTH), .A_H(BOSS_BULLET_HEIGHT),
                   .B_W(PLAYER_WIDTH),      .B_H(PLAYER_HEIGHT)) u_b_bullet_1_vs_player (
        .a_x(b_bullet_x_1), .a_y(b_bullet_y_1), .b_x(p_x), .b_y(p_y), .overlap(b_bullet_touch_1)
    );
    rect_overlap #(.XW(XW), .YW(YW),
                   .A_W(BOSS_BULLET_WIDTH), .A_H(BOSS_BULLET_HEIGHT),
                   .B_W(PLAYER_WIDTH),      .B_H(PLAYER_HEIGHT)) u_b_bullet_2_vs_player (
        .a_x(b_bullet_x_2), .a_y(b_bullet_y_2), .b_x(p_x), .b_y(p_y), .overlap(b_bullet_touch_2)
    );
    rect_overlap #(.XW(XW), .YW(YW),
                   .A_W(BOSS_BULLET_WIDTH), .A_H(BOSS_BULLET_HEIGHT),
                   .B_W(PLAYER_WIDTH),      .B_H(PLAYER_HEIGHT)) u_b_bullet_3_vs_player (
        .a_x(b_bullet_x_3), .a_y(b_bullet_y_3), .b_x(p_x), .b_y(p_y), .overlap(b_bullet_touch_3)
    );

    hit_pulse u_b_hit_1 (.clk(clk), .resetn(resetn), .active(b_bullet_active_1),
                         .touching(b_bullet_touch_1), .hit_event(b_bullet_rest_1));
    hit_pulse u_b_hit_2 (.clk(clk), .resetn(resetn), .active(b_bullet_active_2),
                         .touching(b_bullet_touch_2), .hit_event(b_bullet_rest_2));
    hit_pulse u_b_hit_3 (.clk(clk), .resetn(resetn), .active(b_bullet_active_3),
                         .touching(b_bullet_touch_3), .hit_event(b_bullet_rest_3));

    // any boss bullet hit the player -> player loses 1 HP
    assign p_damage = b_bullet_rest_1 || b_bullet_rest_2 || b_bullet_rest_3;

endmodule
