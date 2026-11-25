# run in ModelSim:   cd to this ModelSim folder, then type   do sim_display.do
quit -sim
vlib work
vlog ../draw_rect.v ../image_rom.v ../display.v tb_display.v
vsim work.tb_display

add wave -radix unsigned /tb_display/clk /tb_display/resetn /tb_display/frame_tick
add wave -radix unsigned /tb_display/p_x /tb_display/p_y /tb_display/b_x /tb_display/b_y
add wave -radix unsigned /tb_display/p_bullet_y_1 /tb_display/p_bullet_active_1
add wave -radix unsigned /tb_display/b_bullet_y_1 /tb_display/b_bullet_active_1
add wave -radix unsigned /tb_display/p_hp /tb_display/b_hp
add wave -divider control
add wave -radix unsigned /tb_display/dut/u_control/state
add wave -radix unsigned /tb_display/dut/clearing /tb_display/dut/latch /tb_display/dut/rect_start /tb_display/dut/rect_done
add wave -divider datapath
add wave -radix unsigned /tb_display/dut/u_datapath/step
add wave -radix unsigned /tb_display/dut/rect_x0 /tb_display/dut/rect_y0 /tb_display/dut/rect_w /tb_display/dut/rect_h /tb_display/dut/rect_use_picture
add wave -radix unsigned /tb_display/dut/picture_addr
add wave -radix hex      /tb_display/dut/picture_colour
add wave -radix binary   /tb_display/dut/rect_colour
add wave -divider to_vga
add wave -radix unsigned /tb_display/vga_plot /tb_display/vga_x /tb_display/vga_y
add wave -radix binary   /tb_display/vga_colour

run -all
wave zoom full
