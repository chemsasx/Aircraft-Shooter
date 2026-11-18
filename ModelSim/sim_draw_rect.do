# run in ModelSim:   cd to this ModelSim folder, then type   do sim_draw_rect.do
quit -sim
vlib work
vlog ../draw_rect.v tb_draw_rect.v
vsim work.tb_draw_rect

add wave -radix unsigned /tb_draw_rect/clk /tb_draw_rect/resetn /tb_draw_rect/start
add wave -radix unsigned /tb_draw_rect/x0 /tb_draw_rect/y0 /tb_draw_rect/w /tb_draw_rect/h
add wave -radix unsigned /tb_draw_rect/dut/u_control/state
add wave -radix unsigned /tb_draw_rect/dut/u_datapath/cx /tb_draw_rect/dut/u_datapath/cy
add wave -radix unsigned /tb_draw_rect/plot /tb_draw_rect/x /tb_draw_rect/y
add wave -radix binary   /tb_draw_rect/colour
add wave -radix unsigned /tb_draw_rect/done

run -all
wave zoom full
