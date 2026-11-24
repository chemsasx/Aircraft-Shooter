`timescale 1ns / 1ns

module tb_draw_rect;

    reg        clk, resetn, start;
    reg  [9:0] x0, w;            // XW = 10
    reg  [8:0] y0, h;            // YW = 9
    reg  [8:0] colour_in;        // CW = 9

    wire       plot, done;
    wire [9:0] x;
    wire [8:0] y;
    wire [8:0] colour;

    // device under test (default parameters = 640 x 480)
    draw_rect dut (
        .clk(clk), .resetn(resetn), .start(start),
        .x0(x0), .y0(y0), .w(w), .h(h), .colour_in(colour_in),
        .plot(plot), .x(x), .y(y), .colour(colour), .done(done)
    );

    // 50 MHz clock: period 20 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // print every pixel and every done
    always @(posedge clk) begin
        if (plot) $display("%t  plot (%0d, %0d)", $time, x, y);
        if (done) $display("%t  done", $time);
    end

    initial begin
        // reset
        resetn = 0;  start = 0;
        x0 = 0;  y0 = 0;  w = 0;  h = 0;  colour_in = 0;
        @(negedge clk);  @(negedge clk);
        resetn = 1;
        @(negedge clk);

        // TEST 1: normal rectangle
        $display("---- TEST 1: 4x3 at (10,20) ----");
        x0 = 10;  y0 = 20;  w = 4;  h = 3;  colour_in = 9'b000_111_111;
        start = 1;  @(negedge clk);  start = 0;      // start for 1 clock
        wait (done);  @(negedge clk);  @(negedge clk);

        // TEST 2: empty rectangle
        $display("---- TEST 2: w = 0 ----");
        x0 = 50;  y0 = 50;  w = 0;  h = 5;
        start = 1;  @(negedge clk);  start = 0;
        wait (done);  @(negedge clk);  @(negedge clk);

        // TEST 3: right edge clipping
        $display("---- TEST 3: 4x2 at (638,100) ----");
        x0 = 638;  y0 = 100;  w = 4;  h = 2;  colour_in = 9'b111_111_000;
        start = 1;  @(negedge clk);  start = 0;
        wait (done);  @(negedge clk);  @(negedge clk);

        $display("---- finished ----");
        $stop;
    end

endmodule
