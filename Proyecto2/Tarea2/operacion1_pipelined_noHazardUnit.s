    addi s2, zero, 0      # idx: i = 0
    addi t2, zero, 2000   # N = 2000
    lui  s1, 0x10000      # base = 0x10000000
    lui  t0, 0x00000      # no se usa

FOR:
    bge  s2, t2, done     # salta si i >= N
    slli t0, s2, 2        # t0 = 4*i
    nop                   # RAW slli -> add: se necesitan 2 nop
    nop
    add  t0, t0, s1       # t0 = base + 4*i
    nop                   # RAW add -> sw y add -> lw: se necesitan 2 nop
    nop
    sw   s2, 0(t0)        # ESCRITURA: 2000 en total
    lw   s3, 0(t0)        # LECTURA: 2000 en total
    addi s2, s2, 1        # i = i + 1
    nop                   # distancia minima hasta el bge de la vuelta siguiente
    nop
    jal  zero, FOR        # salto incondicional

done:
    li   a0, 10
    ecall