// six states
// clear_start: clearing = 1, clear the whole screen using a SCREEN_WIDTH*SCREEN_HEIGHT block, rect_start = 1, begin to draw
// clear_wait: clearing = 1, rect_start = 0, wait until rect_done = 1
// wait_frame: do nothing, wait until frame_tick = 1
// latch: record prev location, get the new location
// rect_start: begin to draw the rectangle
// rect_wait: wait until rect_done = 1

// current version draws: player and boss (pictures from the picture ROM),
// 3 player bullets, 3 boss bullets, boss HP bar (top) and player HP bar (bottom).
// The background is black: erasing paints black rectangles.
// sizes are parameters, passed down from top -> display -> datapath / draw_rect


// display_control (unchanged: it has no widths inside, so it needs no parameters)
module display_control (
    input  clk,
    input  resetn,
    input  frame_tick, // 60 Hz pulse
    input  rect_done, // from draw_rect: whether current rectangle finished
    input  is_last_step, // from datapath: this is the last rectangle of the frame
    output clearing, // to datapath: select the full-screen rectangle
    output rect_start, // to draw_rect: start the selected rectangle
    output latch, // to datapath: take snapshot, step = 0
    output next_step // to datapath: step = step + 1
);

    localparam S_CLEAR_START = 3'd0, // start the full-screen clear
               S_CLEAR_WAIT = 3'd1, // wait for the clear to finish
               S_WAIT_FRAME = 3'd2, // idle until frame_tick
               S_LATCH = 3'd3, // snapshot + step = 0
               S_RECT_START = 3'd4, // start rectangle number "step"
               S_RECT_WAIT = 3'd5; // wait for draw_rect done

    reg [2:0] state, next_state;

    always @(*) begin
        next_state = state;
        case (state)
            S_CLEAR_START: next_state = S_CLEAR_WAIT;
            S_CLEAR_WAIT: if (rect_done)  next_state = S_WAIT_FRAME;
            S_WAIT_FRAME: if (frame_tick) next_state = S_LATCH;
            S_LATCH: next_state = S_RECT_START;
            S_RECT_START: next_state = S_RECT_WAIT;
            S_RECT_WAIT: if (rect_done)
                               next_state = is_last_step ? S_WAIT_FRAME   // frame finished
                                                         : S_RECT_START;  // next rectangle
            default: next_state = S_CLEAR_START;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) state <= S_CLEAR_START;
        else state <= next_state;
    end

    assign clearing = (state == S_CLEAR_START) || (state == S_CLEAR_WAIT);
    assign rect_start = (state == S_CLEAR_START) || (state == S_RECT_START);
    assign latch = (state == S_LATCH);
    assign next_step = (state == S_RECT_WAIT) && rect_done && !is_last_step;

endmodule


// display_datapath: snapshot registers, step counter, rectangle MUX
module display_datapath #(
    parameter XW = 10, // x bits: 0-639
    parameter YW = 9, // y bits: 0-479
    parameter CW = 9, // colour bits {RRR,GGG,BBB}
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter PLAYER_WIDTH  = 36,
    parameter PLAYER_HEIGHT = 48,
    parameter PLAYER_BULLET_WIDTH  = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter BOSS_WIDTH  = 64,
    parameter BOSS_HEIGHT = 48,
    parameter BOSS_BULLET_WIDTH  = 4,
    parameter BOSS_BULLET_HEIGHT = 8,
    parameter HP_W   = 5, // HP bits: 0..16
    parameter MAX_HP = 16,
    parameter HP_UNIT_W = 16, // bar pixels per HP point
    parameter BAR_H = 8, // bar height
    parameter PICTURE_AW = 14 // picture ROM address bits
)(
    input clk,
    input resetn,

    // from display_control
    input clearing,
    input latch,
    input next_step,

    // live game state (may change at any time)
    input [XW-1:0] p_x,
    input [YW-1:0] p_y,

    input [XW-1:0] p_bullet_x_1,
    input [YW-1:0] p_bullet_y_1,
    input p_bullet_active_1,

    input [XW-1:0] p_bullet_x_2,
    input [YW-1:0] p_bullet_y_2,
    input p_bullet_active_2,

    input [XW-1:0] p_bullet_x_3,
    input [YW-1:0] p_bullet_y_3,
    input p_bullet_active_3,

    input [XW-1:0] b_x,
    input [YW-1:0] b_y,

    input [XW-1:0] b_bullet_x_1,
    input [YW-1:0] b_bullet_y_1,
    input b_bullet_active_1,

    input [XW-1:0] b_bullet_x_2,
    input [YW-1:0] b_bullet_y_2,
    input b_bullet_active_2,

    input [XW-1:0] b_bullet_x_3,
    input [YW-1:0] b_bullet_y_3,
    input b_bullet_active_3,

    input [HP_W-1:0] p_hp,
    input [HP_W-1:0] b_hp,

    // to display_control
    output is_last_step,

    // the rectangle draw_rect should draw now
    output reg [XW-1:0] rect_x0,
    output reg [YW-1:0] rect_y0,
    output reg [XW-1:0] rect_w,
    output reg [YW-1:0] rect_h,
    output reg [CW-1:0] rect_colour,
    output reg rect_use_picture, // 1 = colour comes from the picture ROM (player / boss picture)
    output reg [PICTURE_AW-1:0] rect_picture_base // first picture ROM word of the picture
);

    // colours {RRR,GGG,BBB}
    localparam BG_COLOUR = 9'b000_000_000;   // black
    localparam P_BULLET_COLOUR = 9'b111_111_000;   // yellow
    localparam B_BULLET_COLOUR = 9'b111_100_000;   // orange
    localparam P_HP_COLOUR = 9'b000_111_000;   // green (player HP left)
    localparam B_HP_COLOUR = 9'b111_000_000;   // red   (boss HP left)
    localparam HP_LOST_COLOUR = 9'b010_010_010;   // dark grey (HP already lost)

    // where each picture starts in the picture ROM (MIF/pictures.hex)
    localparam PLAYER_PICTURE_BASE = 0;
    localparam BOSS_PICTURE_BASE = PLAYER_WIDTH * PLAYER_HEIGHT; // boss words come after the player

    // HP bar geometry
    // each HP point = HP_UNIT_W (16) px, full bar = 16 * 16 = 256 px, centred: (640 - 256) / 2 = 192
    localparam BAR_X = (SCREEN_WIDTH - MAX_HP * HP_UNIT_W) / 2;
    localparam BOSS_BAR_Y = 4; // boss bar at the top of the screen
    localparam PLAYER_BAR_Y = SCREEN_HEIGHT - BAR_H - 4; // player bar at the bottom (468)

    // drawing order inside one frame: erase everything first, then draw everything
    localparam STEP_ERASE_PLAYER = 5'd0,
               STEP_ERASE_BOSS = 5'd1,
               STEP_ERASE_P_BULLET_1 = 5'd2,
               STEP_ERASE_P_BULLET_2 = 5'd3,
               STEP_ERASE_P_BULLET_3 = 5'd4,
               STEP_ERASE_B_BULLET_1 = 5'd5,
               STEP_ERASE_B_BULLET_2 = 5'd6,
               STEP_ERASE_B_BULLET_3 = 5'd7,
               STEP_DRAW_BOSS = 5'd8,
               STEP_DRAW_P_BULLET_1 = 5'd9,
               STEP_DRAW_P_BULLET_2 = 5'd10,
               STEP_DRAW_P_BULLET_3 = 5'd11,
               STEP_DRAW_B_BULLET_1 = 5'd12,
               STEP_DRAW_B_BULLET_2 = 5'd13,
               STEP_DRAW_B_BULLET_3 = 5'd14,
               STEP_DRAW_PLAYER = 5'd15,   // player drawn after boss and bullets -> player is on top
               STEP_B_BAR_FULL = 5'd16,   // HP bars drawn last -> always on top
               STEP_B_BAR_LOST = 5'd17,
               STEP_P_BAR_FULL = 5'd18,
               STEP_P_BAR_LOST = 5'd19,
               LAST_STEP = 5'd19;

    // snapshot registers
    // curr_ = what this frame will draw   (copied from the inputs on latch)
    // prev_ = what the last frame drew    (what is on the screen right now)
    reg [XW-1:0] curr_p_x, prev_p_x;
    reg [YW-1:0] curr_p_y, prev_p_y;

    reg [XW-1:0] curr_p_bullet_x_1, prev_p_bullet_x_1;
    reg [YW-1:0] curr_p_bullet_y_1, prev_p_bullet_y_1;
    reg curr_p_bullet_active_1, prev_p_bullet_active_1;

    reg [XW-1:0] curr_p_bullet_x_2, prev_p_bullet_x_2;
    reg [YW-1:0] curr_p_bullet_y_2, prev_p_bullet_y_2;
    reg curr_p_bullet_active_2, prev_p_bullet_active_2;

    reg [XW-1:0] curr_p_bullet_x_3, prev_p_bullet_x_3;
    reg [YW-1:0] curr_p_bullet_y_3, prev_p_bullet_y_3;
    reg curr_p_bullet_active_3, prev_p_bullet_active_3;

    reg [XW-1:0] curr_b_x, prev_b_x;
    reg [YW-1:0] curr_b_y, prev_b_y;

    reg [XW-1:0] curr_b_bullet_x_1, prev_b_bullet_x_1;
    reg [YW-1:0] curr_b_bullet_y_1, prev_b_bullet_y_1;
    reg curr_b_bullet_active_1, prev_b_bullet_active_1;

    reg [XW-1:0] curr_b_bullet_x_2, prev_b_bullet_x_2;
    reg [YW-1:0] curr_b_bullet_y_2, prev_b_bullet_y_2;
    reg curr_b_bullet_active_2, prev_b_bullet_active_2;

    reg [XW-1:0] curr_b_bullet_x_3, prev_b_bullet_x_3;
    reg [YW-1:0] curr_b_bullet_y_3, prev_b_bullet_y_3;
    reg curr_b_bullet_active_3, prev_b_bullet_active_3;

    // HP bars are fully redrawn every frame, so no prev_ needed
    reg [HP_W-1:0] curr_p_hp, curr_b_hp;

    always @(posedge clk) begin

        // initialize
        if (!resetn) begin
            curr_p_x <= 0; prev_p_x <= 0;
            curr_p_y <= 0; prev_p_y <= 0;
            curr_p_bullet_x_1 <= 0; prev_p_bullet_x_1 <= 0;
            curr_p_bullet_y_1 <= 0; prev_p_bullet_y_1 <= 0;
            curr_p_bullet_active_1 <= 0; prev_p_bullet_active_1 <= 0;
            curr_p_bullet_x_2 <= 0; prev_p_bullet_x_2 <= 0;
            curr_p_bullet_y_2 <= 0; prev_p_bullet_y_2 <= 0;
            curr_p_bullet_active_2 <= 0; prev_p_bullet_active_2 <= 0;
            curr_p_bullet_x_3 <= 0; prev_p_bullet_x_3 <= 0;
            curr_p_bullet_y_3 <= 0; prev_p_bullet_y_3 <= 0;
            curr_p_bullet_active_3 <= 0; prev_p_bullet_active_3 <= 0;

            curr_b_x <= 0; prev_b_x <= 0;
            curr_b_y <= 0; prev_b_y <= 0;
            curr_b_bullet_x_1 <= 0; prev_b_bullet_x_1 <= 0;
            curr_b_bullet_y_1 <= 0; prev_b_bullet_y_1 <= 0;
            curr_b_bullet_active_1 <= 0; prev_b_bullet_active_1 <= 0;
            curr_b_bullet_x_2 <= 0; prev_b_bullet_x_2 <= 0;
            curr_b_bullet_y_2 <= 0; prev_b_bullet_y_2 <= 0;
            curr_b_bullet_active_2 <= 0; prev_b_bullet_active_2 <= 0;
            curr_b_bullet_x_3 <= 0; prev_b_bullet_x_3 <= 0;
            curr_b_bullet_y_3 <= 0; prev_b_bullet_y_3 <= 0;
            curr_b_bullet_active_3 <= 0; prev_b_bullet_active_3 <= 0;

            curr_p_hp <= 0; curr_b_hp <= 0;
        end

        //latch = 1, store current into previous, store the inputs into current
        else if (latch) begin
            // shift: current -> previous
            prev_p_x <= curr_p_x; prev_p_y <= curr_p_y;
            prev_p_bullet_x_1 <= curr_p_bullet_x_1;
            prev_p_bullet_y_1 <= curr_p_bullet_y_1;
            prev_p_bullet_active_1 <= curr_p_bullet_active_1;

            prev_p_bullet_x_2 <= curr_p_bullet_x_2;
            prev_p_bullet_y_2 <= curr_p_bullet_y_2;
            prev_p_bullet_active_2 <= curr_p_bullet_active_2;

            prev_p_bullet_x_3 <= curr_p_bullet_x_3;
            prev_p_bullet_y_3 <= curr_p_bullet_y_3;
            prev_p_bullet_active_3 <= curr_p_bullet_active_3;

            prev_b_x <= curr_b_x; prev_b_y <= curr_b_y;
            prev_b_bullet_x_1 <= curr_b_bullet_x_1;
            prev_b_bullet_y_1 <= curr_b_bullet_y_1;
            prev_b_bullet_active_1 <= curr_b_bullet_active_1;

            prev_b_bullet_x_2 <= curr_b_bullet_x_2;
            prev_b_bullet_y_2 <= curr_b_bullet_y_2;
            prev_b_bullet_active_2 <= curr_b_bullet_active_2;

            prev_b_bullet_x_3 <= curr_b_bullet_x_3;
            prev_b_bullet_y_3 <= curr_b_bullet_y_3;
            prev_b_bullet_active_3 <= curr_b_bullet_active_3;

            // load: inputs -> current
            curr_p_x <= p_x; curr_p_y <= p_y;
            curr_p_bullet_x_1 <= p_bullet_x_1;
            curr_p_bullet_y_1 <= p_bullet_y_1;
            curr_p_bullet_active_1 <= p_bullet_active_1;

            curr_p_bullet_x_2 <= p_bullet_x_2;
            curr_p_bullet_y_2 <= p_bullet_y_2;
            curr_p_bullet_active_2 <= p_bullet_active_2;

            curr_p_bullet_x_3 <= p_bullet_x_3;
            curr_p_bullet_y_3 <= p_bullet_y_3;
            curr_p_bullet_active_3 <= p_bullet_active_3;

            curr_b_x <= b_x; curr_b_y <= b_y;
            curr_b_bullet_x_1 <= b_bullet_x_1;
            curr_b_bullet_y_1 <= b_bullet_y_1;
            curr_b_bullet_active_1 <= b_bullet_active_1;

            curr_b_bullet_x_2 <= b_bullet_x_2;
            curr_b_bullet_y_2 <= b_bullet_y_2;
            curr_b_bullet_active_2 <= b_bullet_active_2;

            curr_b_bullet_x_3 <= b_bullet_x_3;
            curr_b_bullet_y_3 <= b_bullet_y_3;
            curr_b_bullet_active_3 <= b_bullet_active_3;

            curr_p_hp <= p_hp; curr_b_hp <= b_hp;
        end
    end

    // erase decisions (comparators)
    // Erase an old image only if the object moved or (bullets) disappeared.
    // An object that stands still is just drawn again -> no black flash.
    wire p_moved = (curr_p_x != prev_p_x) || (curr_p_y != prev_p_y);
    wire b_moved = (curr_b_x != prev_b_x) || (curr_b_y != prev_b_y);
    wire p_bullet_moved_1 = (curr_p_bullet_x_1 != prev_p_bullet_x_1) || (curr_p_bullet_y_1 != prev_p_bullet_y_1);
    wire p_bullet_moved_2 = (curr_p_bullet_x_2 != prev_p_bullet_x_2) || (curr_p_bullet_y_2 != prev_p_bullet_y_2);
    wire p_bullet_moved_3 = (curr_p_bullet_x_3 != prev_p_bullet_x_3) || (curr_p_bullet_y_3 != prev_p_bullet_y_3);
    wire b_bullet_moved_1 = (curr_b_bullet_x_1 != prev_b_bullet_x_1) || (curr_b_bullet_y_1 != prev_b_bullet_y_1);
    wire b_bullet_moved_2 = (curr_b_bullet_x_2 != prev_b_bullet_x_2) || (curr_b_bullet_y_2 != prev_b_bullet_y_2);
    wire b_bullet_moved_3 = (curr_b_bullet_x_3 != prev_b_bullet_x_3) || (curr_b_bullet_y_3 != prev_b_bullet_y_3);

    wire erase_p = p_moved;
    wire erase_b = b_moved;

    // only erase when the bullet existed in last frame, and moved or disappear at this frame
    wire erase_p_bullet_1 = prev_p_bullet_active_1 && (p_bullet_moved_1 || !curr_p_bullet_active_1);
    wire erase_p_bullet_2 = prev_p_bullet_active_2 && (p_bullet_moved_2 || !curr_p_bullet_active_2);
    wire erase_p_bullet_3 = prev_p_bullet_active_3 && (p_bullet_moved_3 || !curr_p_bullet_active_3);
    wire erase_b_bullet_1 = prev_b_bullet_active_1 && (b_bullet_moved_1 || !curr_b_bullet_active_1);
    wire erase_b_bullet_2 = prev_b_bullet_active_2 && (b_bullet_moved_2 || !curr_b_bullet_active_2);
    wire erase_b_bullet_3 = prev_b_bullet_active_3 && (b_bullet_moved_3 || !curr_b_bullet_active_3);

    // HP bar widths
    // one bar = two rectangles side by side:
    //   [ full part: hp * 16 px, colour ][ lost part: (MAX_HP - hp) * 16 px, grey ]
    // together they cover the whole bar every frame, so the bar never needs erasing
    // (* HP_UNIT_W is a constant multiply; 16 = shift left by 4, no real multiplier is built)
    wire [HP_W-1:0] p_hp_lost = MAX_HP - curr_p_hp;   // subtractor
    wire [HP_W-1:0] b_hp_lost = MAX_HP - curr_b_hp;

    wire [XW-1:0] p_bar_full_w = curr_p_hp * HP_UNIT_W;
    wire [XW-1:0] p_bar_lost_w = p_hp_lost * HP_UNIT_W;
    wire [XW-1:0] p_bar_lost_x0 = BAR_X + p_bar_full_w;   // adder: grey part starts where colour ends

    wire [XW-1:0] b_bar_full_w = curr_b_hp * HP_UNIT_W;
    wire [XW-1:0] b_bar_lost_w = b_hp_lost * HP_UNIT_W;
    wire [XW-1:0] b_bar_lost_x0 = BAR_X + b_bar_full_w;

    // step counter
    reg [4:0] step;

    always @(posedge clk) begin
        if (!resetn || latch) step <= 5'd0;
        else if (next_step)   step <= step + 1'b1;
    end

    assign is_last_step = (step == LAST_STEP);

    // rectangle MUX
    // width 0 = "skip": draw_rect sees an empty rectangle and is done at once
    always @(*) begin
        rect_x0 = 0;  rect_y0 = 0;  rect_w = 0;  rect_h = 0;  rect_colour = BG_COLOUR; // default value
        rect_use_picture = 0;  rect_picture_base = 0; // only the player and the boss use pictures

        if (clearing) begin // clearing = 1, clear the whole screen using one black block
            rect_w = SCREEN_WIDTH;
            rect_h = SCREEN_HEIGHT;
        end
        else begin
            case (step)
                // erase old images, replacing them with background colour
                STEP_ERASE_PLAYER: begin
                    rect_x0 = prev_p_x;   rect_y0 = prev_p_y;
                    // moved - width needed to be erased is PLAYER_WIDTH, else 0
                    rect_w  = erase_p ? PLAYER_WIDTH : 0;   rect_h = PLAYER_HEIGHT;
                end
                STEP_ERASE_BOSS: begin
                    rect_x0 = prev_b_x;   rect_y0 = prev_b_y;
                    rect_w  = erase_b ? BOSS_WIDTH : 0;   rect_h = BOSS_HEIGHT;
                end
                STEP_ERASE_P_BULLET_1: begin
                    rect_x0 = prev_p_bullet_x_1;   rect_y0 = prev_p_bullet_y_1;
                    rect_w  = erase_p_bullet_1 ? PLAYER_BULLET_WIDTH : 0;   rect_h = PLAYER_BULLET_HEIGHT;
                end
                STEP_ERASE_P_BULLET_2: begin
                    rect_x0 = prev_p_bullet_x_2;   rect_y0 = prev_p_bullet_y_2;
                    rect_w  = erase_p_bullet_2 ? PLAYER_BULLET_WIDTH : 0;   rect_h = PLAYER_BULLET_HEIGHT;
                end
                STEP_ERASE_P_BULLET_3: begin
                    rect_x0 = prev_p_bullet_x_3;   rect_y0 = prev_p_bullet_y_3;
                    rect_w  = erase_p_bullet_3 ? PLAYER_BULLET_WIDTH : 0;   rect_h = PLAYER_BULLET_HEIGHT;
                end
                STEP_ERASE_B_BULLET_1: begin
                    rect_x0 = prev_b_bullet_x_1;   rect_y0 = prev_b_bullet_y_1;
                    rect_w  = erase_b_bullet_1 ? BOSS_BULLET_WIDTH : 0;   rect_h = BOSS_BULLET_HEIGHT;
                end
                STEP_ERASE_B_BULLET_2: begin
                    rect_x0 = prev_b_bullet_x_2;   rect_y0 = prev_b_bullet_y_2;
                    rect_w  = erase_b_bullet_2 ? BOSS_BULLET_WIDTH : 0;   rect_h = BOSS_BULLET_HEIGHT;
                end
                STEP_ERASE_B_BULLET_3: begin
                    rect_x0 = prev_b_bullet_x_3;   rect_y0 = prev_b_bullet_y_3;
                    rect_w  = erase_b_bullet_3 ? BOSS_BULLET_WIDTH : 0;   rect_h = BOSS_BULLET_HEIGHT;
                end

                // draw new images (inactive bullet -> width 0 -> skipped)
                STEP_DRAW_BOSS: begin
                    rect_x0 = curr_b_x;     rect_y0 = curr_b_y;
                    rect_w  = BOSS_WIDTH;   rect_h  = BOSS_HEIGHT;
                    rect_use_picture = 1;   rect_picture_base = BOSS_PICTURE_BASE;
                end
                STEP_DRAW_P_BULLET_1: begin
                    rect_x0 = curr_p_bullet_x_1;   rect_y0 = curr_p_bullet_y_1;
                    rect_w  = curr_p_bullet_active_1 ? PLAYER_BULLET_WIDTH : 0;   rect_h = PLAYER_BULLET_HEIGHT;
                    rect_colour = P_BULLET_COLOUR;
                end
                STEP_DRAW_P_BULLET_2: begin
                    rect_x0 = curr_p_bullet_x_2;   rect_y0 = curr_p_bullet_y_2;
                    rect_w  = curr_p_bullet_active_2 ? PLAYER_BULLET_WIDTH : 0;   rect_h = PLAYER_BULLET_HEIGHT;
                    rect_colour = P_BULLET_COLOUR;
                end
                STEP_DRAW_P_BULLET_3: begin
                    rect_x0 = curr_p_bullet_x_3;   rect_y0 = curr_p_bullet_y_3;
                    rect_w  = curr_p_bullet_active_3 ? PLAYER_BULLET_WIDTH : 0;   rect_h = PLAYER_BULLET_HEIGHT;
                    rect_colour = P_BULLET_COLOUR;
                end
                STEP_DRAW_B_BULLET_1: begin
                    rect_x0 = curr_b_bullet_x_1;   rect_y0 = curr_b_bullet_y_1;
                    rect_w  = curr_b_bullet_active_1 ? BOSS_BULLET_WIDTH : 0;   rect_h = BOSS_BULLET_HEIGHT;
                    rect_colour = B_BULLET_COLOUR;
                end
                STEP_DRAW_B_BULLET_2: begin
                    rect_x0 = curr_b_bullet_x_2;   rect_y0 = curr_b_bullet_y_2;
                    rect_w  = curr_b_bullet_active_2 ? BOSS_BULLET_WIDTH : 0;   rect_h = BOSS_BULLET_HEIGHT;
                    rect_colour = B_BULLET_COLOUR;
                end
                STEP_DRAW_B_BULLET_3: begin
                    rect_x0 = curr_b_bullet_x_3;   rect_y0 = curr_b_bullet_y_3;
                    rect_w  = curr_b_bullet_active_3 ? BOSS_BULLET_WIDTH : 0;   rect_h = BOSS_BULLET_HEIGHT;
                    rect_colour = B_BULLET_COLOUR;
                end
                STEP_DRAW_PLAYER: begin
                    rect_x0 = curr_p_x;       rect_y0 = curr_p_y;
                    rect_w  = PLAYER_WIDTH;   rect_h  = PLAYER_HEIGHT;
                    rect_use_picture = 1;   rect_picture_base = PLAYER_PICTURE_BASE;
                end

                // HP bars (full part width 0 when HP = 0, lost part width 0 when HP = MAX -> skipped)
                STEP_B_BAR_FULL: begin
                    rect_x0 = BAR_X;          rect_y0 = BOSS_BAR_Y;
                    rect_w  = b_bar_full_w;   rect_h  = BAR_H;
                    rect_colour = B_HP_COLOUR;
                end
                STEP_B_BAR_LOST: begin
                    rect_x0 = b_bar_lost_x0;  rect_y0 = BOSS_BAR_Y;
                    rect_w  = b_bar_lost_w;   rect_h  = BAR_H;
                    rect_colour = HP_LOST_COLOUR;
                end
                STEP_P_BAR_FULL: begin
                    rect_x0 = BAR_X;          rect_y0 = PLAYER_BAR_Y;
                    rect_w  = p_bar_full_w;   rect_h  = BAR_H;
                    rect_colour = P_HP_COLOUR;
                end
                STEP_P_BAR_LOST: begin
                    rect_x0 = p_bar_lost_x0;  rect_y0 = PLAYER_BAR_Y;
                    rect_w  = p_bar_lost_w;   rect_h  = BAR_H;
                    rect_colour = HP_LOST_COLOUR;
                end

                default: ; // keep the "empty" defaults
            endcase
        end
    end

endmodule


// display: connects control + datapath + draw_rect
// vga_* outputs go straight to vga_adapter (.write .x .y .color)
module display #(
    parameter XW = 10,
    parameter YW = 9,
    parameter CW = 9,
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter PLAYER_WIDTH  = 36,
    parameter PLAYER_HEIGHT = 48,
    parameter PLAYER_BULLET_WIDTH  = 4,
    parameter PLAYER_BULLET_HEIGHT = 8,
    parameter BOSS_WIDTH  = 64,
    parameter BOSS_HEIGHT = 48,
    parameter BOSS_BULLET_WIDTH  = 4,
    parameter BOSS_BULLET_HEIGHT = 8,
    parameter HP_W   = 5,
    parameter MAX_HP = 16,
    parameter HP_UNIT_W = 16,
    parameter BAR_H = 8,
    // picture ROM: player picture, then boss picture
    parameter PICTURE_AW = 14,
    parameter PICTURE_FILE = "MIF/pictures.hex"
)(
    input clk,
    input resetn,
    input frame_tick,

    input [XW-1:0] p_x,
    input [YW-1:0] p_y,
    input [XW-1:0] p_bullet_x_1,
    input [YW-1:0] p_bullet_y_1,
    input p_bullet_active_1,
    input [XW-1:0] p_bullet_x_2,
    input [YW-1:0] p_bullet_y_2,
    input p_bullet_active_2,
    input [XW-1:0] p_bullet_x_3,
    input [YW-1:0] p_bullet_y_3,
    input p_bullet_active_3,

    input [XW-1:0] b_x,
    input [YW-1:0] b_y,
    input [XW-1:0] b_bullet_x_1,
    input [YW-1:0] b_bullet_y_1,
    input b_bullet_active_1,
    input [XW-1:0] b_bullet_x_2,
    input [YW-1:0] b_bullet_y_2,
    input b_bullet_active_2,
    input [XW-1:0] b_bullet_x_3,
    input [YW-1:0] b_bullet_y_3,
    input b_bullet_active_3,

    input [HP_W-1:0] p_hp,
    input [HP_W-1:0] b_hp,

    output vga_plot,
    output [XW-1:0] vga_x,
    output [YW-1:0] vga_y,
    output [CW-1:0] vga_colour
);

    wire clearing, rect_start, latch, next_step, is_last_step;   // control <-> datapath
    wire [XW-1:0] rect_x0, rect_w; // datapath -> draw_rect
    wire [YW-1:0] rect_y0, rect_h;
    wire [CW-1:0] rect_colour;
    wire rect_use_picture;
    wire [PICTURE_AW-1:0] rect_picture_base;
    wire rect_done; // draw_rect -> control
    wire [PICTURE_AW-1:0] picture_addr; // draw_rect -> picture ROM
    wire [CW-1:0] picture_colour; // picture ROM -> draw_rect

    display_control u_control (
        .clk(clk), .resetn(resetn),
        .frame_tick(frame_tick), .rect_done(rect_done), .is_last_step(is_last_step),
        .clearing(clearing), .rect_start(rect_start), .latch(latch), .next_step(next_step)
    );

    display_datapath #(
        .XW(XW), .YW(YW), .CW(CW),
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .PLAYER_WIDTH(PLAYER_WIDTH), .PLAYER_HEIGHT(PLAYER_HEIGHT),
        .PLAYER_BULLET_WIDTH(PLAYER_BULLET_WIDTH), .PLAYER_BULLET_HEIGHT(PLAYER_BULLET_HEIGHT),
        .BOSS_WIDTH(BOSS_WIDTH), .BOSS_HEIGHT(BOSS_HEIGHT),
        .BOSS_BULLET_WIDTH(BOSS_BULLET_WIDTH), .BOSS_BULLET_HEIGHT(BOSS_BULLET_HEIGHT),
        .HP_W(HP_W), .MAX_HP(MAX_HP), .HP_UNIT_W(HP_UNIT_W), .BAR_H(BAR_H),
        .PICTURE_AW(PICTURE_AW)
    ) u_datapath (
        .clk(clk), .resetn(resetn),
        .clearing(clearing), .latch(latch), .next_step(next_step),
        .p_x(p_x), .p_y(p_y),
        .p_bullet_x_1(p_bullet_x_1), .p_bullet_y_1(p_bullet_y_1), .p_bullet_active_1(p_bullet_active_1),
        .p_bullet_x_2(p_bullet_x_2), .p_bullet_y_2(p_bullet_y_2), .p_bullet_active_2(p_bullet_active_2),
        .p_bullet_x_3(p_bullet_x_3), .p_bullet_y_3(p_bullet_y_3), .p_bullet_active_3(p_bullet_active_3),
        .b_x(b_x), .b_y(b_y),
        .b_bullet_x_1(b_bullet_x_1), .b_bullet_y_1(b_bullet_y_1), .b_bullet_active_1(b_bullet_active_1),
        .b_bullet_x_2(b_bullet_x_2), .b_bullet_y_2(b_bullet_y_2), .b_bullet_active_2(b_bullet_active_2),
        .b_bullet_x_3(b_bullet_x_3), .b_bullet_y_3(b_bullet_y_3), .b_bullet_active_3(b_bullet_active_3),
        .p_hp(p_hp), .b_hp(b_hp),
        .is_last_step(is_last_step),
        .rect_x0(rect_x0), .rect_y0(rect_y0), .rect_w(rect_w), .rect_h(rect_h),
        .rect_colour(rect_colour), .rect_use_picture(rect_use_picture),
        .rect_picture_base(rect_picture_base)
    );

    // picture ROM: player (PLAYER_WIDTH x PLAYER_HEIGHT words) then boss (BOSS_WIDTH x BOSS_HEIGHT words)
    image_rom #(
        .AW(PICTURE_AW), .CW(CW),
        .DEPTH(PLAYER_WIDTH * PLAYER_HEIGHT + BOSS_WIDTH * BOSS_HEIGHT),
        .INIT_FILE(PICTURE_FILE)
    ) u_picture_rom (
        .clk(clk), .address(picture_addr), .colour(picture_colour)
    );

    draw_rect #(
        .XW(XW), .YW(YW), .CW(CW),
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .PICTURE_AW(PICTURE_AW)
    ) u_draw_rect (
        .clk(clk), .resetn(resetn), .start(rect_start),
        .x0(rect_x0), .y0(rect_y0), .w(rect_w), .h(rect_h), .colour_in(rect_colour),
        .use_picture(rect_use_picture), .picture_base(rect_picture_base),
        .picture_colour(picture_colour), .picture_addr(picture_addr),
        .plot(vga_plot), .x(vga_x), .y(vga_y), .colour(vga_colour), .done(rect_done)
    );

endmodule
