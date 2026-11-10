    addi s2, zero, 0      # idx: i = 0
    addi t2, zero, 2000   # N = 2000    
    lui  s1, 0x10000      # base = 0x10000000 (inicio del segmento de datos)
    lui  t0, 0x00000      # no se usa, slli lo sobrescribe (se deja tal como se corrio)

FOR:
    bge  s2, t2, done     # salta si i >= N: 2001 evaluaciones, solo la ultima salta
    slli t0, s2, 2        # t0 = 4*i (operacion entre registros)
    add  t0, t0, s1       # t0 = base + 4*i (operacion entre registros)
    sw   s2, 0(t0)        # ESCRITURA a memoria de datos: 1 por vuelta x 2000 = 2000
    lw   s3, 0(t0)        # LECTURA de memoria de datos: 1 por vuelta x 2000 = 2000
    addi s2, s2, 1        # i = i + 1
    jal  zero, FOR        # salto incondicional: 2000 veces

done:
    li   a0, 10           # syscall exit
    ecall                 # accesos totales a memoria de datos = 2000 + 2000 = 4000