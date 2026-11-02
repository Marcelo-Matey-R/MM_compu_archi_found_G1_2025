# Reloj de 50 MHz de la tarjeta
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Entradas asincronas (botones, dedos y sensores): pasan por sincronizadores, no se analizan
set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {topGPIO[*]}]

# Salidas a LEDs, display, motor y buzzer: no tienen requisito de tiempo externo
set_false_path -to [get_ports {LEDR[*]}]
set_false_path -to [get_ports {HEX0[*]}]
set_false_path -to [get_ports {topGPIO[*]}]
