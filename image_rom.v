// ============================================================================
// image_rom.v  -  a picture stored in on-chip memory (read-only)
// ----------------------------------------------------------------------------
// One 9-bit colour {RRR,GGG,BBB} per word. The words are read from a text
// file (one 3-digit hex number per line) with $readmemh when the FPGA is
// programmed / the simulation starts. Quartus builds this from M10K blocks.
//
// Read is synchronous: the colour of "address" appears ONE clock later.
//
// Used twice in display.v:
//   sprite ROM     : MIF/sprites.hex          player 37 x 66 (words 0 .. 2441)
//                                             then boss 112 x 117 (words 2442 .. 15545)
//                    1c7 = TRANSPARENT (not drawn)
//   background ROM : MIF/space_bg_160x120.hex one word per 4 x 4 block of the screen
// (MIF/*_preview.png show what the pictures look like.)
// ============================================================================
module image_rom #(
    parameter AW = 14,                         // address bits
    parameter CW = 9,                          // colour bits
    parameter DEPTH = 15546,                   // number of words
    parameter INIT_FILE = "MIF/sprites.hex"
)(
    input clk,
    input [AW-1:0] address,
    output reg [CW-1:0] colour
);

    reg [CW-1:0] memory [0:DEPTH-1];

    initial $readmemh(INIT_FILE, memory);      // load the picture

    always @(posedge clk)
        colour <= memory[address];

endmodule
