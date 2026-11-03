// Lista de modulos de ../src para vlog. Se corre desde la carpeta tb:
//     vlog -f files.f
// El paquete va primero porque alu_nbit lo importa.

../src/alu_types_pkg.sv

// basicos
../src/full_adder.sv
../src/ripple_adder.sv
../src/mux_2_1.sv
../src/mux_2_1_param.sv
../src/not_nbit.sv
../src/or_nbit.sv
../src/xnor_nbit.sv

// ALU
../src/shift_left.sv
../src/shift_left_rotator.sv
../src/shift_right.sv
../src/shift_right_rotator.sv
../src/product.sv
../src/alu_nbit.sv

// sistema
../src/reset_bridge.sv
../src/sync_edge_detector.sv
../src/encoder.sv
../src/digit_capture.sv
../src/password_memory.sv
../src/tick_var.sv
../src/pwm.sv
../src/buzzer.sv
../src/hex7seg.sv
../src/motor_control.sv
../src/main_fsm.sv
../src/top_level.sv
