// recieve the start coordinates (x, y), assume it as the top-left
// make start = 1 for one clock
// output one pixel per clock on plot/x/y/colour
// connect to vga_adapter .write/ .x / .y/ .colour
// when last pixel is drawn, done = 1
// scan from left to right, top to bottom

// three parts:
// draw_rect_control: FSM IDLE->DRAW->DONE
// draw_rect_datapath
// draw_rect

// to draw a w*h rectangle, takes w*h+2 clock

// sprite mode (use_sprite = 1, used for the player and boss pictures):
//   the colour of each pixel comes from the sprite ROM instead of colour_in.
//   sprite_addr starts at sprite_base and counts +1 per pixel, in the same
//   order the pixels are drawn (left to right, top to bottom), so pixel k of
//   the rectangle reads ROM word sprite_base + k. w must equal the picture width.
//   Pixels with colour TRANSPARENT are not plotted (the background stays).
// The ROM needs one clock to answer, so plot / x / y are delayed by one
// register stage to line up with the ROM colour (for every rectangle).

// sizes are parameters (passed down from top -> display -> draw_rect),
// the defaults below are our 640x480, 9-bit colour screen

// draw_rect_control (no widths inside, so it needs no parameters)

module draw_rect_control (
    input  clk,
    input  resetn,
    input  start, // start = 1, draw a new rectangle
    input  empty, // draw nothing, w == 0 or h == 0
    input  last_col, // cx is at the last column
    input  last_row, // cy is at the last row
    output load, // save the inputs, clear cx and cy
    output draw_en, // output this pixel, then count
    output done // finished, done = 1
);

    localparam S_IDLE = 2'd0, // waiting for start
               S_DRAW = 2'd1, // one pixel per clock
               S_DONE = 2'd2; // finished, stay here for one clock

    reg [1:0] state, next_state;

    always @(*) begin
        next_state = state; // default case
        case (state)
            S_IDLE: if (start)
                        next_state = empty ? S_DONE : S_DRAW; // empty-> done, !empty-> begin to draw
            S_DRAW: if (last_col && last_row) // this is the last pixel, then done
                        next_state = S_DONE;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) state <= S_IDLE;
        else state <= next_state;
    end

    assign load = (state == S_IDLE) && start; // begin to draw new rect, record input, clear cx, cy
    assign draw_en = (state == S_DRAW); // draw_en = 1, pass the coordinates to VGA, draw a pixel, plot = 1
    assign done = (state == S_DONE); // work finished

endmodule

module draw_rect_datapath #(
    parameter XW = 10, // x bits: 0..639
    parameter YW = 9, // y bits: 0..479
    parameter CW = 9, // colour bits {RRR,GGG,BBB}
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter SPRITE_AW = 14, // sprite ROM address bits (15546 words < 16384)
    parameter TRANSPARENT = 9'b111_000_111 // sprite colour that is not drawn
)(
    input clk,
    input resetn,
    input load, // from control
    input draw_en, // from control
    input [XW-1:0] x0, // top-left corner
    input [YW-1:0] y0,
    input [XW-1:0] w, // width  (number of columns)
    input [YW-1:0] h, // height (number of rows)
    input [CW-1:0] colour_in,
    input use_sprite, // 1 = take the colour from the sprite ROM
    input [SPRITE_AW-1:0] sprite_base, // first ROM word of the picture
    input [CW-1:0] sprite_colour, // from the sprite ROM (one clock after sprite_addr)

    output last_col, // to control
    output last_row, // to control
    output empty, // to control

    output reg [SPRITE_AW-1:0] sprite_addr, // to the sprite ROM
    output plot, // to vga_adapter .write
    output reg [XW-1:0] x, // to vga_adapter .x
    output reg [YW-1:0] y, // to vga_adapter .y
    output [CW-1:0] colour // to vga_adapter .color
);

    reg [XW-1:0] x0_r, w_r;
    reg [YW-1:0] y0_r, h_r;
    reg [CW-1:0] colour_r;
    reg use_sprite_r;

    reg [XW-1:0] cx; // current col
    reg [YW-1:0] cy; // current row

    always @(posedge clk) begin
        if (!resetn) begin
        // initialize the parameters
            x0_r <= 0;  y0_r <= 0;  w_r <= 0;  h_r <= 0;  colour_r <= 0;  use_sprite_r <= 0;
            cx   <= 0;  cy   <= 0;  sprite_addr <= 0;
        end
        else if (load) begin // load = 1, drawing a new rectangle is allowed
            x0_r <= x0;  y0_r <= y0;  w_r <= w;  h_r <= h;  colour_r <= colour_in;  use_sprite_r <= use_sprite;
            cx   <= 0;   cy   <= 0;   sprite_addr <= sprite_base;
        end
        else if (draw_en) begin // draw one pixel per clock
        // left to right, top to bottom
            if (last_col) begin // end of this row:
                cx <= 0;
                if (!last_row)
                    cy <= cy + 1'b1;
            end
            else
                cx <= cx + 1'b1;
            sprite_addr <= sprite_addr + 1'b1; // next pixel = next ROM word
        end
    end

    assign last_col = (cx == w_r - 1'b1);
    assign last_row = (cy == h_r - 1'b1);

    assign empty = (w == 0) || (h == 0);

    // one extra bit so a big sum cannot wrap around to a small number
    wire [XW:0] x_sum = {1'b0, x0_r} + {1'b0, cx};
    wire [YW:0] y_sum = {1'b0, y0_r} + {1'b0, cy};

    wire in_screen = (x_sum < SCREEN_WIDTH) && (y_sum < SCREEN_HEIGHT); // off-screen pixels are skipped

    // delay register: wait one clock for the ROM, so x, y, plot and the ROM colour belong to the same pixel
    reg plot_d;
    always @(posedge clk) begin
        if (!resetn) begin
            plot_d <= 0;  x <= 0;  y <= 0;
        end
        else begin
            plot_d <= draw_en && in_screen; // this pixel is inside the screen
            x <= x_sum[XW-1:0];
            y <= y_sum[YW-1:0];
        end
    end

    wire transparent = use_sprite_r && (sprite_colour == TRANSPARENT); // comparator

    assign colour = use_sprite_r ? sprite_colour : colour_r; // 2-to-1 MUX

    assign plot = plot_d && !transparent; // when plot = 1, this pixel is allowed to draw

endmodule

// connext draw_rect_control with datapath
module draw_rect #(
    parameter XW = 10,
    parameter YW = 9,
    parameter CW = 9,
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter SPRITE_AW = 14
)(
    input clk,
    input resetn,
    input start,
    input [XW-1:0] x0,
    input [YW-1:0] y0,
    input [XW-1:0] w,
    input [YW-1:0] h,
    input [CW-1:0] colour_in,
    input use_sprite,
    input [SPRITE_AW-1:0] sprite_base,
    input [CW-1:0] sprite_colour,

    output [SPRITE_AW-1:0] sprite_addr,
    output plot,
    output [XW-1:0] x,
    output [YW-1:0] y,
    output [CW-1:0] colour,
    output done
);

    wire load, draw_en; // control  -> datapath
    wire last_col, last_row, empty; // datapath -> control

    draw_rect_control u_control (
        .clk(clk), .resetn(resetn), .start(start),
        .empty(empty), .last_col(last_col), .last_row(last_row),
        .load(load), .draw_en(draw_en), .done(done)
    );

    // pass the parameters one level further down
    draw_rect_datapath #(
        .XW(XW), .YW(YW), .CW(CW),
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .SPRITE_AW(SPRITE_AW)
    ) u_datapath (
        .clk(clk), .resetn(resetn), .load(load), .draw_en(draw_en),
        .x0(x0), .y0(y0), .w(w), .h(h), .colour_in(colour_in),
        .use_sprite(use_sprite), .sprite_base(sprite_base), .sprite_colour(sprite_colour),
        .last_col(last_col), .last_row(last_row), .empty(empty),
        .sprite_addr(sprite_addr),
        .plot(plot), .x(x), .y(y), .colour(colour)
    );

endmodule
