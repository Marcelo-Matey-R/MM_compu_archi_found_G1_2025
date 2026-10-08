# Restricciones SDC para datapath secuencial de 16 bits: 
# Dominio de reloj principal: CLOCK_50 a 50 MHz (periodo 20 ns)
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# Las entradas fisicas (SW, KEY) son asincronicas respecto al reloj:
# se sincronizan explicitamente en el diseno via reset_bridge y
# sync_edge_detector, por lo que se marcan como false path para el STA
# (evita que Quartus intente aplicar timing de setup/hold sobre
#  señales que ya se tratan como asincronicas por diseno)
set_false_path -from [get_ports {SW[*] KEY[*]}]