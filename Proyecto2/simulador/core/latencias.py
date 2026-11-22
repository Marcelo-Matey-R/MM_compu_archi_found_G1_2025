"""Latencias de los componentes de hardware, en picosegundos (enteros).
Fuente: S. L. Harris y D. Harris, Digital Design and Computer Architecture,
RISC-V Edition, cap. 7, tabla de retardos de los elementos del datapath.
"""

T_PCQ = 40        # registro: reloj -> Q (PC, registros de pipeline)
T_SETUP = 50      # registro: tiempo de setup
T_MUX = 30        # multiplexor
T_ANDOR = 20      # compuerta AND-OR (logica de PCSrc)
T_ALU = 120       # ALU
T_DEC = 25        # decodificador / unidad de control
T_EXT = 35        # unidad de extension del inmediato
T_MEM = 200       # lectura de memoria (instrucciones o datos)
T_RF_READ = 100   # lectura del banco de registros
T_RF_SETUP = 60   # setup del banco de registros
