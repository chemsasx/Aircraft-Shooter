
module frame_tick #(
    parameter FRAME_CYCLES = 833333,   // clocks per frame (ModelSim: 200)
    parameter COUNT_W      = 20        // 2^20 = 1,048,576 > 833,333
)(
    input  clk,
    input  resetn,
    output frame_tick                  // 1 for exactly one clock per frame
);

    reg  [COUNT_W-1:0] cycle_count;
    wire last_cycle = (cycle_count == FRAME_CYCLES - 1);

    always @(posedge clk) begin
        if (!resetn || last_cycle)
            cycle_count <= 0;                      // start a new frame
        else
            cycle_count <= cycle_count + 1'b1;
    end

    assign frame_tick = last_cycle;

endmodule