# run in ModelSim:   cd to this ModelSim folder, then type   do sim_damage_hp.do
quit -sim
vlib work
vlog ../damage_detect.v ../hp_update.v tb_damage_hp.v
vsim work.tb_damage_hp

add wave -radix unsigned -label clk               /tb_damage_hp/clk
add wave -radix unsigned -label resetn            /tb_damage_hp/resetn
add wave -radix unsigned -label p_bullet_y_1      /tb_damage_hp/p_bullet_y_1
add wave -radix unsigned -label p_bullet_active_1 /tb_damage_hp/p_bullet_active_1
add wave -radix unsigned -label p_bullet_rest_1   /tb_damage_hp/p_bullet_rest_1
add wave -radix unsigned -label b_damage          /tb_damage_hp/b_damage
add wave -radix unsigned -label b_hp              /tb_damage_hp/b_hp
add wave -radix unsigned -label b_bullet_x_1      /tb_damage_hp/b_bullet_x_1
add wave -radix unsigned -label b_bullet_active_1 /tb_damage_hp/b_bullet_active_1
add wave -radix unsigned -label b_bullet_rest_1   /tb_damage_hp/b_bullet_rest_1
add wave -radix unsigned -label p_damage          /tb_damage_hp/p_damage
add wave -radix unsigned -label p_hp              /tb_damage_hp/p_hp

run -all
wave zoom full
