// six states
// clear_start: clearing = 1, clear the whole screen using a SCREEN_WIDTH*SCREEN_HEIGHT block, rect_start = 1, begin to draw
// clear_wait: clearing = 1, rect_start = 0, wait until rect_done = 1
// wait_frame: do nothing, wait until frame_tick = 1
// latch: record prev location, get the new location
// rect_start: begin to draw the rectangle
// rect_wait: wait until rect_done = 1

// current version draws: the player + 3 player bullets (a burst)
// (boss, boss bullet and HP bars will be added back later)
// sizes are parameters, passed down from top -> display -> datapath / draw_rect


// display_control (unchanged: it has no widths inside, so it needs no parameters)
module display_control (
    input  clk,
    input  resetn,
    input  frame_tick,       // 60 Hz pulse
    input  rect_done,        // from draw_rect: whether current rectangle finished
    input  is_last_step,     // from datapath: this is the last rectangle of the frame
    output clearing,         // to datapath: select the full-screen rectangle
    output rect_start,       // to draw_rect: start the selected rectangle
    output latch,            // to datapath: take snapshot, step = 0
    output next_step         // to datapath: step = step + 1
);

    localparam S_CLEAR_START = 3'd0,   // start the full-screen clear
               S_CLEAR_WAIT  = 3'd1,   // wait for the clear to finish
               S_WAIT_FRAME  = 3'd2,   // idle until frame_tick
               S_LATCH       = 3'd3,   // snapshot + step = 0
               S_RECT_START  = 3'd4,   // start rectangle number "step"
               S_RECT_WAIT   = 3'd5;   // wait for draw_rect done

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
    parameter XW = 10,                     // x bits: 0-639
    parameter YW = 9,                      // y bits: 0-479
    parameter CW = 9,                      // colour bits {RRR,GGG,BBB}
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter PLAYER_WIDTH  = 36,
    parameter PLAYER_HEIGHT = 48,
    parameter PLAYER_BULLET_WIDTH  = 4,
    parameter PLAYER_BULLET_HEIGHT = 8
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
    input          p_bullet_active_1,
    input [XW-1:0] p_bullet_x_2,
    input [YW-1:0] p_bullet_y_2,
    input          p_bullet_active_2,
    input [XW-1:0] p_bullet_x_3,
    input [YW-1:0] p_bullet_y_3,
    input          p_bullet_active_3,

    // to display_control
    output is_last_step,

    // the rectangle draw_rect should draw now
    output reg [XW-1:0] rect_x0,
    output reg [YW-1:0] rect_y0,
    output reg [XW-1:0] rect_w,
    output reg [YW-1:0] rect_h,
    output reg [CW-1:0] rect_colour
);

    // colours {RRR,GGG,BBB}
    localparam BG_COLOUR       = 9'b000_000_000;   // black
    localparam PLAYER_COLOUR   = 9'b000_111_111;   // cyan
    localparam P_BULLET_COLOUR = 9'b111_111_000;   // yellow

    // drawing order inside one frame: erase everything first, then draw everything
    localparam STEP_ERASE_PLAYER     = 4'd0,
               STEP_ERASE_P_BULLET_1 = 4'd1,
               STEP_ERASE_P_BULLET_2 = 4'd2,
               STEP_ERASE_P_BULLET_3 = 4'd3,
               STEP_DRAW_P_BULLET_1  = 4'd4,
               STEP_DRAW_P_BULLET_2  = 4'd5,
               STEP_DRAW_P_BULLET_3  = 4'd6,
               STEP_DRAW_PLAYER      = 4'd7,   // player drawn last -> player is on top
               LAST_STEP             = 4'd7;

    // snapshot registers
    // curr_ = what this frame will draw   (copied from the inputs on latch)
    // prev_ = what the last frame drew    (what is on the screen right now)
    reg [XW-1:0] curr_p_x, prev_p_x;
    reg [YW-1:0] curr_p_y, prev_p_y;

    reg [XW-1:0] curr_p_bullet_x_1, prev_p_bullet_x_1;
    reg [YW-1:0] curr_p_bullet_y_1, prev_p_bullet_y_1;
    reg          curr_p_bullet_active_1, prev_p_bullet_active_1;

    reg [XW-1:0] curr_p_bullet_x_2, prev_p_bullet_x_2;
    reg [YW-1:0] curr_p_bullet_y_2, prev_p_bullet_y_2;
    reg          curr_p_bullet_active_2, prev_p_bullet_active_2;

    reg [XW-1:0] curr_p_bullet_x_3, prev_p_bullet_x_3;
    reg [YW-1:0] curr_p_bullet_y_3, prev_p_bullet_y_3;
    reg          curr_p_bullet_active_3, prev_p_bullet_active_3;

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
        end

        //latch = 1, store current into previous, store the inputs into current
        else if (latch) begin
            // shift: current -> previous
            prev_p_x <= curr_p_x; prev_p_y <= curr_p_y;
            prev_p_bullet_x_1 <= curr_p_bullet_x_1; prev_p_bullet_y_1 <= curr_p_bullet_y_1;
            prev_p_bullet_active_1 <= curr_p_bullet_active_1;
            prev_p_bullet_x_2 <= curr_p_bullet_x_2; prev_p_bullet_y_2 <= curr_p_bullet_y_2;
            prev_p_bullet_active_2 <= curr_p_bullet_active_2;
            prev_p_bullet_x_3 <= curr_p_bullet_x_3; prev_p_bullet_y_3 <= curr_p_bullet_y_3;
            prev_p_bullet_active_3 <= curr_p_bullet_active_3;
            // load: inputs -> current
            curr_p_x <= p_x; curr_p_y <= p_y;
            curr_p_bullet_x_1 <= p_bullet_x_1; curr_p_bullet_y_1 <= p_bullet_y_1;
            curr_p_bullet_active_1 <= p_bullet_active_1;
            curr_p_bullet_x_2 <= p_bullet_x_2; curr_p_bullet_y_2 <= p_bullet_y_2;
            curr_p_bullet_active_2 <= p_bullet_active_2;
            curr_p_bullet_x_3 <= p_bullet_x_3; curr_p_bullet_y_3 <= p_bullet_y_3;
            curr_p_bullet_active_3 <= p_bullet_active_3;
        end
    end

    // erase decisions (comparators)
    // Erase an old image only if the object moved or (bullets) disappeared.
    // An object that stands still is just drawn again -> no black flash.
    wire p_moved = (curr_p_x != prev_p_x) || (curr_p_y != prev_p_y);
    wire p_bullet_moved_1 = (curr_p_bullet_x_1 != prev_p_bullet_x_1) || (curr_p_bullet_y_1 != prev_p_bullet_y_1);
    wire p_bullet_moved_2 = (curr_p_bullet_x_2 != prev_p_bullet_x_2) || (curr_p_bullet_y_2 != prev_p_bullet_y_2);
    wire p_bullet_moved_3 = (curr_p_bullet_x_3 != prev_p_bullet_x_3) || (curr_p_bullet_y_3 != prev_p_bullet_y_3);

    wire erase_p = p_moved;

    // only erase when the bullet existed in last frame, and moved or disappear at this frame
    wire erase_p_bullet_1 = prev_p_bullet_active_1 && (p_bullet_moved_1 || !curr_p_bullet_active_1);
    wire erase_p_bullet_2 = prev_p_bullet_active_2 && (p_bullet_moved_2 || !curr_p_bullet_active_2);
    wire erase_p_bullet_3 = prev_p_bullet_active_3 && (p_bullet_moved_3 || !curr_p_bullet_active_3);

    // step counter
    reg [3:0] step;

    always @(posedge clk) begin
        if (!resetn || latch) step <= 4'd0;
        else if (next_step)   step <= step + 1'b1;
    end

    assign is_last_step = (step == LAST_STEP);

    // rectangle MUX
    // width 0 = "skip": draw_rect sees an empty rectangle and is done at once
    always @(*) begin
        rect_x0 = 0;  rect_y0 = 0;  rect_w = 0;  rect_h = 0;  rect_colour = BG_COLOUR; // default value

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

                // draw new images (inactive bullet -> width 0 -> skipped)
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
                STEP_DRAW_PLAYER: begin
                    rect_x0 = curr_p_x;       rect_y0 = curr_p_y;
                    rect_w  = PLAYER_WIDTH;   rect_h  = PLAYER_HEIGHT;
                    rect_colour = PLAYER_COLOUR;
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
    parameter PLAYER_BULLET_HEIGHT = 8
)(
    input clk,
    input resetn,
    input frame_tick,

    input [XW-1:0] p_x,
    input [YW-1:0] p_y,
    input [XW-1:0] p_bullet_x_1,
    input [YW-1:0] p_bullet_y_1,
    input          p_bullet_active_1,
    input [XW-1:0] p_bullet_x_2,
    input [YW-1:0] p_bullet_y_2,
    input          p_bullet_active_2,
    input [XW-1:0] p_bullet_x_3,
    input [YW-1:0] p_bullet_y_3,
    input          p_bullet_active_3,

    output          vga_plot,
    output [XW-1:0] vga_x,
    output [YW-1:0] vga_y,
    output [CW-1:0] vga_colour
);

    wire clearing, rect_start, latch, next_step, is_last_step;   // control <-> datapath
    wire [XW-1:0] rect_x0, rect_w; // datapath -> draw_rect
    wire [YW-1:0] rect_y0, rect_h;
    wire [CW-1:0] rect_colour;
    wire rect_done; // draw_rect -> control

    display_control u_control (
        .clk(clk), .resetn(resetn),
        .frame_tick(frame_tick), .rect_done(rect_done), .is_last_step(is_last_step),
        .clearing(clearing), .rect_start(rect_start), .latch(latch), .next_step(next_step)
    );

    display_datapath #(
        .XW(XW), .YW(YW), .CW(CW),
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .PLAYER_WIDTH(PLAYER_WIDTH), .PLAYER_HEIGHT(PLAYER_HEIGHT),
        .PLAYER_BULLET_WIDTH(PLAYER_BULLET_WIDTH), .PLAYER_BULLET_HEIGHT(PLAYER_BULLET_HEIGHT)
    ) u_datapath (
        .clk(clk), .resetn(resetn),
        .clearing(clearing), .latch(latch), .next_step(next_step),
        .p_x(p_x), .p_y(p_y),
        .p_bullet_x_1(p_bullet_x_1), .p_bullet_y_1(p_bullet_y_1), .p_bullet_active_1(p_bullet_active_1),
        .p_bullet_x_2(p_bullet_x_2), .p_bullet_y_2(p_bullet_y_2), .p_bullet_active_2(p_bullet_active_2),
        .p_bullet_x_3(p_bullet_x_3), .p_bullet_y_3(p_bullet_y_3), .p_bullet_active_3(p_bullet_active_3),
        .is_last_step(is_last_step),
        .rect_x0(rect_x0), .rect_y0(rect_y0), .rect_w(rect_w), .rect_h(rect_h),
        .rect_colour(rect_colour)
    );

    draw_rect #(
        .XW(XW), .YW(YW), .CW(CW),
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) u_draw_rect (
        .clk(clk), .resetn(resetn), .start(rect_start),
        .x0(rect_x0), .y0(rect_y0), .w(rect_w), .h(rect_h), .colour_in(rect_colour),
        .plot(vga_plot), .x(vga_x), .y(vga_y), .colour(vga_colour), .done(rect_done)
    );

endmodule
