fill:
        addi    sp, sp, -16
        sw      ra, 12(sp)
        sw      s0, 8(sp)
        addi    s0, sp, 16
        sw      a0, 4(sp)
        li      a0, 0
        sw      a0, 0(sp)
        j       .LBB0_1
.LBB0_1:
        lw      a1, 0(sp)
        li      a0, 9
        blt     a0, a1, .LBB0_4
        j       .LBB0_2
.LBB0_2:
        lw      a0, 0(sp)
        lw      a1, 4(sp)
        slli    a2, a0, 2
        add     a1, a1, a2
        sw      a0, 0(a1)
        j       .LBB0_3
.LBB0_3:
        lw      a0, 0(sp)
        addi    a0, a0, 1
        sw      a0, 0(sp)
        j       .LBB0_1
.LBB0_4:
        lw      ra, 12(sp)
        lw      s0, 8(sp)
        addi    sp, sp, 16
        ret

sumas:
        addi    sp, sp, -32
        sw      ra, 28(sp)
        sw      s0, 24(sp)
        addi    s0, sp, 32
        sw      a0, 20(sp)
        li      a0, 0
        sw      a0, 16(sp)
        sw      a0, 12(sp)
        j       .LBB1_1
.LBB1_1:
        lw      a1, 12(sp)
        li      a0, 9
        blt     a0, a1, .LBB1_4
        j       .LBB1_2
.LBB1_2:
        lw      a0, 20(sp)
        lw      a1, 12(sp)
        slli    a1, a1, 2
        add     a0, a0, a1
        lw      a1, 0(a0)
        lw      a0, 16(sp)
        add     a0, a0, a1
        sw      a0, 16(sp)
        j       .LBB1_3
.LBB1_3:
        lw      a0, 12(sp)
        addi    a0, a0, 1
        sw      a0, 12(sp)
        j       .LBB1_1
.LBB1_4:
        lw      a0, 16(sp)
        lw      ra, 28(sp)
        lw      s0, 24(sp)
        addi    sp, sp, 32
        ret

main:
        addi    sp, sp, -16
        sw      ra, 12(sp)
        sw      s0, 8(sp)
        addi    s0, sp, 16
        li      a0, 0
        sw      a0, 4(sp)
        lui     a0, %hi(datos)
        addi    a0, a0, %lo(datos)
        sw      a0, 0(sp)
        call    fill
        lw      a0, 0(sp)
        call    sumas
        lw      ra, 12(sp)
        lw      s0, 8(sp)
        addi    sp, sp, 16
        ret

datos:
        .zero   40
