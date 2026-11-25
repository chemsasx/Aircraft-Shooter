# Aircraft-Shooter

ECE241 course project (Team 200): a boss-fight shooter on the DE1-SoC FPGA,
written in Verilog, with a PS/2 mouse and 640x480 VGA output.

## How to play
- `KEY[0]`: reset
- Move the mouse to move the player (a 37 x 66 pixel-art ship). Left click fires a burst of 3 bullets (yellow).
- The boss (a 112 x 117 pixel-art ship) moves left and right at the top. Every 2 s it fires a burst of 3 aimed bullets (orange).
- HP bars: boss at the top (red), player at the bottom (green). Grey shows HP already lost.
- LEDs: `LEDR[3:1]` player bullets, `LEDR[6:4]` boss bullets, `LEDR[8]` boss HP = 0, `LEDR[9]` player HP = 0.

## Modules
| File | Module(s) | What it does |
|---|---|---|
| `top.v` | top | All game constants. Connects every module. |
| `mouse_decoder.v`, `PS2/` | mouse_decoder | PS/2 mouse packets to dx, dy and clicks |
| `player.v` | player | Player position, clamped to the screen |
| `player_bullet.v` | player_bullet | 3-bullet burst going straight up |
| `boss.v` | boss | Moves left and right, fire timer |
| `boss_bullet.v` | boss_bullet | 3-bullet burst aimed at the player (Bresenham line) |
| `damage_detect.v` | damage_detect | Rectangle overlap tests; removes the bullet that hit; damage pulses |
| `hp_update.v` | hp_update | Player and boss HP counters |
| `frame_tick.v` | frame_tick | 60 Hz frame pulse |
| `display.v`, `draw_rect.v` | display, draw_rect | Erase and redraw every object once per frame, then the HP bars |
| `image_rom.v` | image_rom | A picture in on-chip memory: the sprite ROM used by display |
| `MIF/sprites.hex` | - | Player 37 x 66 then boss 112 x 117, 9-bit colours, `1c7` = transparent |
| `vga/` | vga_adapter | Course VGA adapter |

## Build
Open `project_final.qpf` in Quartus, compile, and program the `.sof` to the DE1-SoC (5CSEMA5F31).

## Simulation (ModelSim)
In the `ModelSim/` folder, run `do sim_draw_rect.do`, `do sim_display.do`, `do sim_boss.do`
or `do sim_damage_hp.do`. Each testbench lists its expected output at the top.
