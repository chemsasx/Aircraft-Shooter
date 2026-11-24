// ============================================================================
// player_sprite_rom.v  -  the player picture, stored in on-chip memory
// ----------------------------------------------------------------------------
// The picture is 37 x 66 pixels = 2442 words, one 9-bit colour {RRR,GGG,BBB}
// per word. Word number (row * 37 + col) is the pixel at (col, row), i.e.
// row 0 from left to right, then row 1, ... (the same order draw_rect draws).
// The colour 9'h1c7 (111_000_111) means TRANSPARENT: draw_rect skips it.
//
// The words are read from a text file (one 3-digit hex number per line)
// with $readmemh when the FPGA is programmed / the simulation starts.
// File made from the player image: MIF/player_37x66.hex
// (MIF/player_37x66_preview.png shows what it looks like.)
//
// Read is synchronous: the colour of "address" appears ONE clock later.
// Quartus builds this from M10K memory blocks.
// ============================================================================
module player_sprite_rom #(
    parameter AW = 12,                         // address bits: 2442 < 4096
    parameter CW = 9,                          // colour bits
    parameter DEPTH = 2442,                    // 37 * 66 words
    parameter INIT_FILE = "MIF/player_37x66.hex"
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
