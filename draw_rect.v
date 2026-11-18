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

    localparam S_IDLE = 2'd0,   // waiting for start
               S_DRAW = 2'd1,   // one pixel per clock
               S_DONE = 2'd2;   // finished, stay here for one clock

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
    parameter SCREEN_HEIGHT = 480
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

    output last_col, // to control
    output last_row, // to control
    output empty, // to control

    output plot, // to vga_adapter .write
    output [XW-1:0] x, // to vga_adapter .x
    output [YW-1:0] y, // to vga_adapter .y
    output [CW-1:0] colour // to vga_adapter .color
);

    reg [XW-1:0] x0_r, w_r;
    reg [YW-1:0] y0_r, h_r;
    reg [CW-1:0] colour_r;

    reg [XW-1:0] cx; // current col
    reg [YW-1:0] cy; // current row

    always @(posedge clk) begin
        if (!resetn) begin
        // initialize the parameters
            x0_r <= 0;  y0_r <= 0;  w_r <= 0;  h_r <= 0;  colour_r <= 0;
            cx   <= 0;  cy   <= 0;
        end
        else if (load) begin // load = 1, drawing a new rectangle is allowed
            x0_r <= x0;  y0_r <= y0;  w_r <= w;  h_r <= h;  colour_r <= colour_in;
            cx   <= 0;   cy   <= 0;
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
        end
    end

    assign last_col = (cx == w_r - 1'b1);
    assign last_row = (cy == h_r - 1'b1);

    assign empty = (w == 0) || (h == 0);

    // one extra bit so a big sum cannot wrap around to a small number
    wire [XW:0] x_sum = {1'b0, x0_r} + {1'b0, cx};
    wire [YW:0] y_sum = {1'b0, y0_r} + {1'b0, cy};

    wire in_screen = (x_sum < SCREEN_WIDTH) && (y_sum < SCREEN_HEIGHT); // off-screen pixels are skipped

    assign x      = x_sum[XW-1:0];
    assign y      = y_sum[YW-1:0];
    assign colour = colour_r;
    assign plot   = draw_en && in_screen; // when plot = 1, this pixel is allowed to draw

endmodule

// connext draw_rect_control with datapath
module draw_rect #(
    parameter XW = 10,
    parameter YW = 9,
    parameter CW = 9,
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480
)(
    input clk,
    input resetn,
    input start,
    input [XW-1:0] x0,
    input [YW-1:0] y0,
    input [XW-1:0] w,
    input [YW-1:0] h,
    input [CW-1:0] colour_in,

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
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) u_datapath (
        .clk(clk), .resetn(resetn), .load(load), .draw_en(draw_en),
        .x0(x0), .y0(y0), .w(w), .h(h), .colour_in(colour_in),
        .last_col(last_col), .last_row(last_row), .empty(empty),
        .plot(plot), .x(x), .y(y), .colour(colour)
    );

endmodule
