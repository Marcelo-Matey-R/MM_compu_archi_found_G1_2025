    addi s2, zero, 0 #idx: i = 0
    addi t2, zero, 2000 #N = 2000
    addi s1, zero, 0 # contador impares
    addi s0, zero, 0 # contador pares
LOOP:
    andi t0, s2, 1 # se ejecuta 2000 veces
    beq t0, zero, PAR # se ejecuta 2000 veces, se toma el salto 1000 veces y no se toma 1000 veces
    addi s1, s1, 1 # suma impares, se ejecuta 1000 veces
    jal zero, SIGUE # se toma este salto 1000 veces
PAR:
    addi s0, s0, 1 # suma pares, se ejecuta 1000 veces
SIGUE:
    addi s2, s2, 1 # se ejecuta 2000 veces
    blt s2, t2, LOOP # se toma el salto 1999 veces y no se toma 1 vez
done:
    li a7, 10 # syscall exit
    nop
    nop
    nop
    ecall
# se ejecutan 5000 saltos, de los cuales solo se toman 3999 y no se toman 1001