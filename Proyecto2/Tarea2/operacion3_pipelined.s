    addi s2, zero, 0      # idx: i = 0
    addi t0, zero, 3      # operando A = 3
    addi t1, zero, 5      # operando B = 5
    addi t2, zero, 2000   # N = 2000

LOOP:
    addi t0, t0, 1        # A = A + 1, se ejecuta 2000 veces (tipo I, no cuenta)
    add  s3, t0, t1       # operacion entre registros #1, se ejecuta 2000 veces
    sub  s4, t1, t0       # operacion entre registros #2, se ejecuta 2000 veces
    and  s5, t0, t1       # operacion entre registros #3, se ejecuta 2000 veces
    or   s6, t0, t1       # operacion entre registros #4, se ejecuta 2000 veces
    xor  s7, t0, t1       # operacion entre registros #5, se ejecuta 2000 veces
    sll  s8, t0, t1       # operacion entre registros #6, se ejecuta 2000 veces
    srl  s9, t1, t0       # operacion entre registros #7, se ejecuta 2000 veces
    slt  s10, t0, t1      # operacion entre registros #8, se ejecuta 2000 veces
    addi t1, t1, 2        # B = B + 2, se ejecuta 2000 veces (tipo I, no cuenta)
    addi s2, s2, 1        # i = i + 1, se ejecuta 2000 veces (tipo I, no cuenta)
    blt  s2, t2, LOOP     # se ejecuta 2000 veces, se toma el salto 1999 veces y no se toma 1 vez

done:
    li   a7, 10           # syscall exit
    ecall
# se ejecutan 8 operaciones entre registros por vuelta x 2000 vueltas = 16000 operaciones
# instrucciones totales: 4 (inicio) + 2000 x 12 (lazo) + 2 (salida) = 24006