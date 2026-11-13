    addi s2, zero, 0      # idx: i = 0
    addi t0, zero, 3      # operando A = 3
    addi t1, zero, 5      # operando B = 5
    addi t2, zero, 2000   # N = 2000

LOOP:
    addi s2, s2, 1        # i = i + 1, se ejecuta 2000 veces (tipo I, no cuenta)
    add  s3, t0, t1       # operacion entre registros #1, se ejecuta 2000 veces
    nop                   # RAW s3 -> sub: 2 nop
    nop
    sub  s4, s3, t0       # operacion entre registros #2, se ejecuta 2000 veces
    nop                   # RAW s4 -> and: 2 nop
    nop
    and  s5, s4, t1       # operacion entre registros #3, se ejecuta 2000 veces
    nop                   # RAW s5 -> or: 2 nop
    nop
    or   s6, s5, t0       # operacion entre registros #4, se ejecuta 2000 veces
    nop                   # RAW s6 -> xor: 2 nop
    nop
    xor  s7, s6, t1       # operacion entre registros #5, se ejecuta 2000 veces
    nop                   # RAW s7 -> sll: 2 nop
    nop
    sll  s8, s7, t0       # operacion entre registros #6, se ejecuta 2000 veces
    nop                   # RAW s8 -> srl: 2 nop
    nop
    srl  s9, s8, t1       # operacion entre registros #7, se ejecuta 2000 veces
    nop                   # RAW s9 -> slt: 2 nop
    nop
    slt  s10, s9, t0      # operacion entre registros #8, se ejecuta 2000 veces
    addi t0, t0, 1        # A = A + 1, se ejecuta 2000 veces (tipo I, no cuenta)
    addi t1, t1, 2        # B = B + 2, se ejecuta 2000 veces (tipo I, no cuenta)
    blt  s2, t2, LOOP     # s2 escrito lejos: sin RAW, se toma 1999 veces y no se toma 1 vez

done:
    li   a7, 10           # syscall exit
    nop                   # RAW a7 -> ecall: 3 nop
    nop
    nop
    ecall
# se ejecutan 8 operaciones entre registros por vuelta x 2000 vueltas = 16000 operaciones
# instrucciones totales: 4 (inicio) + 2000 x 26 (lazo: 12 + 14 nop) + 2 (salida) + 3 nop = 52009
# los 14 nop por vuelta (28000 en total) son el costo de resolver los 7 RAW por software