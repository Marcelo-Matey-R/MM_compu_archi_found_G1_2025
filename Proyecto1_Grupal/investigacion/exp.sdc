# Reloj de 50 MHz (el mismo de la tarjeta) para todos los tops de la investigacion
create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
