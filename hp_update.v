// ============================================================================
// hp_update.v  -  player HP and boss HP
// ----------------------------------------------------------------------------
//   reset / restart -> both HP = MAX_HP
//   p_damage pulse  -> player HP - 1   (stops at 0)
//   b_damage pulse  -> boss   HP - 1   (stops at 0)
// ============================================================================


// hp_counter : one HP register (down counter that stops at 0)
module hp_counter #(
    parameter HP_W   = 5,                // bits for HP: 0..16 needs 5 bits
    parameter MAX_HP = 16
)(
    input clk,
    input resetn,
    input refill,                        // pulse: back to full HP
    input damage,                        // pulse: lose 1 HP
    output reg [HP_W-1:0] hp
);

    wire is_zero = (hp == 0);            // comparator

    always @(posedge clk) begin
        if (!resetn || refill)
            hp <= MAX_HP;
        else if (damage && !is_zero)     // stop at 0
            hp <= hp - 1'b1;
    end

endmodule


// hp_update : two hp_counters, one for the player, one for the boss
module hp_update #(
    parameter HP_W   = 5,
    parameter MAX_HP = 16
)(
    input clk,
    input resetn,
    input restart,                       // pulse: refill both (later from game_fsm)
    input p_damage,                      // pulse from damage_detect
    input b_damage,                      // pulse from damage_detect
    output [HP_W-1:0] p_hp,
    output [HP_W-1:0] b_hp
);

    hp_counter #(.HP_W(HP_W), .MAX_HP(MAX_HP)) u_p_hp (
        .clk(clk), .resetn(resetn), .refill(restart), .damage(p_damage), .hp(p_hp)
    );

    hp_counter #(.HP_W(HP_W), .MAX_HP(MAX_HP)) u_b_hp (
        .clk(clk), .resetn(resetn), .refill(restart), .damage(b_damage), .hp(b_hp)
    );

endmodule
