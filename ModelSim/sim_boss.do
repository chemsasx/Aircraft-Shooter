# run in ModelSim:   cd to this ModelSim folder, then type   do sim_boss.do
quit -sim
vlib work
vlog ../boss.v tb_boss.v
vsim work.tb_boss

add wave -radix unsigned -label clk           /tb_boss/clk
add wave -radix unsigned -label resetn        /tb_boss/resetn
add wave -radix unsigned -label move_count    /tb_boss/dut/move_count
add wave -radix unsigned -label move_right    /tb_boss/dut/move_right
add wave -radix unsigned -label b_x           /tb_boss/b_x
add wave -radix unsigned -label fire_count    /tb_boss/dut/fire_count
add wave -radix unsigned -label b_bullet_fire /tb_boss/b_bullet_fire

run -all
wave zoom full
