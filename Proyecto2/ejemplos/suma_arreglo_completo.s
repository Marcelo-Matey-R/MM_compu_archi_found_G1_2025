       .attribute      4, 16
        .attribute      5, "rv32i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zifencei2p0_zmmul1p0_zaamo1p0_zalrsc1p0_zca1p0_zcd1p0_zcf1p0"
        .file   "example.c"
        .file   0 "/app" "/app/example.c" md5 0xaf373fcc280691e01800dd3456446ea6
        .text
        .globl  fill
        .p2align        1
        .type   fill,@function
fill:
.Lfunc_begin0:
        .file   1 "example.c" md5 0xaf373fcc280691e01800dd3456446ea6
        .loc    1 3 0
        .cfi_sections .debug_frame
        .cfi_startproc
        addi    sp, sp, -16
        .cfi_def_cfa_offset 16
        sw      ra, 12(sp)
        sw      s0, 8(sp)
        .cfi_offset ra, -4
        .cfi_offset s0, -8
        addi    s0, sp, 16
        .cfi_def_cfa s0, 0
        sw      a0, 4(sp)
        li      a0, 0
.Ltmp0:
        .loc    1 4 14 prologue_end
        sw      a0, 0(sp)
        .loc    1 4 10 is_stmt 0
        j       .LBB0_1
.LBB0_1:
        .loc    1 4 21
        lw      a1, 0(sp)
        .loc    1 4 23
        li      a0, 9
        .loc    1 4 5
        blt     a0, a1, .LBB0_4
        j       .LBB0_2
.LBB0_2:
        .loc    1 5 18 is_stmt 1
        lw      a0, 0(sp)
        .loc    1 5 9 is_stmt 0
        lw      a1, 4(sp)
        slli    a2, a0, 2
        add     a1, a1, a2
        .loc    1 5 16
        sw      a0, 0(a1)
        .loc    1 5 9
        j       .LBB0_3
.LBB0_3:
        .loc    1 4 30 is_stmt 1
        lw      a0, 0(sp)
        addi    a0, a0, 1
        sw      a0, 0(sp)
        .loc    1 4 5 is_stmt 0
        j       .LBB0_1
.Ltmp4:
.LBB0_4:
        .cfi_def_cfa sp, 16
        .loc    1 6 1 epilogue_begin is_stmt 1
        lw      ra, 12(sp)
        lw      s0, 8(sp)
        .cfi_restore ra
        .cfi_restore s0
        addi    sp, sp, 16
        .cfi_def_cfa_offset 0
        ret
.Lfunc_end0:
        .size   fill, .Lfunc_end0-fill
        .cfi_endproc

        .globl  sumas
        .p2align        1
        .type   sumas,@function
sumas:
.Lfunc_begin1:
        .loc    1 8 0
        .cfi_startproc
        addi    sp, sp, -32
        .cfi_def_cfa_offset 32
        sw      ra, 28(sp)
        sw      s0, 24(sp)
        .cfi_offset ra, -4
        .cfi_offset s0, -8
        addi    s0, sp, 32
        .cfi_def_cfa s0, 0
        sw      a0, 20(sp)
        li      a0, 0
        .loc    1 9 9 prologue_end
        sw      a0, 16(sp)
.Ltmp7:
        .loc    1 10 14
        sw      a0, 12(sp)
        .loc    1 10 10 is_stmt 0
        j       .LBB1_1
.LBB1_1:
        .loc    1 10 21
        lw      a1, 12(sp)
        .loc    1 10 23
        li      a0, 9
        .loc    1 10 5
        blt     a0, a1, .LBB1_4
        j       .LBB1_2
.LBB1_2:
        .loc    1 11 17 is_stmt 1
        lw      a0, 20(sp)
        .loc    1 11 21 is_stmt 0
        lw      a1, 12(sp)
        .loc    1 11 17
        slli    a1, a1, 2
        add     a0, a0, a1
        lw      a1, 0(a0)
        .loc    1 11 14
        lw      a0, 16(sp)
        add     a0, a0, a1
        sw      a0, 16(sp)
        .loc    1 11 9
        j       .LBB1_3
.LBB1_3:
        .loc    1 10 30 is_stmt 1
        lw      a0, 12(sp)
        addi    a0, a0, 1
        sw      a0, 12(sp)
        .loc    1 10 5 is_stmt 0
        j       .LBB1_1
.Ltmp11:
.LBB1_4:
        .loc    1 12 12 is_stmt 1
        lw      a0, 16(sp)
        .cfi_def_cfa sp, 32
        .loc    1 12 5 epilogue_begin is_stmt 0
        lw      ra, 28(sp)
        lw      s0, 24(sp)
        .cfi_restore ra
        .cfi_restore s0
        addi    sp, sp, 32
        .cfi_def_cfa_offset 0
        ret
.Lfunc_end1:
        .size   sumas, .Lfunc_end1-sumas
        .cfi_endproc

        .globl  main
        .p2align        1
        .type   main,@function
main:
.Lfunc_begin2:
        .loc    1 15 0 is_stmt 1
        .cfi_startproc
        addi    sp, sp, -16
        .cfi_def_cfa_offset 16
        sw      ra, 12(sp)
        sw      s0, 8(sp)
        .cfi_offset ra, -4
        .cfi_offset s0, -8
        addi    s0, sp, 16
        .cfi_def_cfa s0, 0
        li      a0, 0
        sw      a0, 4(sp)
        .loc    1 16 5 prologue_end
        lui     a0, %hi(datos)
        addi    a0, a0, %lo(datos)
        sw      a0, 0(sp)
        call    fill
        lw      a0, 0(sp)
        .loc    1 17 12
        call    sumas
        .cfi_def_cfa sp, 16
        .loc    1 17 5 epilogue_begin is_stmt 0
        lw      ra, 12(sp)
        lw      s0, 8(sp)
        .cfi_restore ra
        .cfi_restore s0
        addi    sp, sp, 16
        .cfi_def_cfa_offset 0
        ret
.Lfunc_end2:
        .size   main, .Lfunc_end2-main
        .cfi_endproc

        .type   datos,@object
        .bss
        .globl  datos
        .p2align        2, 0x0
datos:
        .zero   40
        .size   datos, 40

        .section        .debug_abbrev,"",@progbits
        .byte   1
        .byte   17
        .byte   1
        .byte   37
        .byte   37
        .byte   19
        .byte   5
        .byte   3
        .byte   37
        .byte   114
        .byte   23
        .byte   16
        .byte   23
        .byte   27
        .byte   37
        .byte   17
        .byte   27
        .byte   18
        .byte   6
        .byte   115
        .byte   23
        .byte   0
        .byte   0
        .byte   2
        .byte   46
        .byte   1
        .byte   17
        .byte   27
        .byte   18
        .byte   6
        .byte   64
        .byte   24
        .byte   3
        .byte   37
        .byte   58
        .byte   11
        .byte   59
        .byte   11
        .byte   39
        .byte   25
        .byte   63
        .byte   25
        .byte   0
        .byte   0
        .byte   3
        .byte   5
        .byte   0
        .byte   2
        .byte   24
        .byte   3
        .byte   37
        .byte   58
        .byte   11
        .byte   59
        .byte   11
        .byte   73
        .byte   19
        .byte   0
        .byte   0
        .byte   4
        .byte   11
        .byte   1
        .byte   17
        .byte   27
        .byte   18
        .byte   6
        .byte   0
        .byte   0
        .byte   5
        .byte   52
        .byte   0
        .byte   2
        .byte   24
        .byte   3
        .byte   37
        .byte   58
        .byte   11
        .byte   59
        .byte   11
        .byte   73
        .byte   19
        .byte   0
        .byte   0
        .byte   6
        .byte   46
        .byte   1
        .byte   17
        .byte   27
        .byte   18
        .byte   6
        .byte   64
        .byte   24
        .byte   3
        .byte   37
        .byte   58
        .byte   11
        .byte   59
        .byte   11
        .byte   39
        .byte   25
        .byte   73
        .byte   19
        .byte   63
        .byte   25
        .byte   0
        .byte   0
        .byte   7
        .byte   46
        .byte   0
        .byte   17
        .byte   27
        .byte   18
        .byte   6
        .byte   64
        .byte   24
        .byte   3
        .byte   37
        .byte   58
        .byte   11
        .byte   59
        .byte   11
        .byte   73
        .byte   19
        .byte   63
        .byte   25
        .byte   0
        .byte   0
        .byte   8
        .byte   52
        .byte   0
        .byte   3
        .byte   37
        .byte   73
        .byte   19
        .byte   63
        .byte   25
        .byte   58
        .byte   11
        .byte   59
        .byte   11
        .byte   2
        .byte   24
        .byte   0
        .byte   0
        .byte   9
        .byte   1
        .byte   1
        .byte   73
        .byte   19
        .byte   0
        .byte   0
        .byte   10
        .byte   33
        .byte   0
        .byte   73
        .byte   19
        .byte   55
        .byte   11
        .byte   0
        .byte   0
        .byte   11
        .byte   36
        .byte   0
        .byte   3
        .byte   37
        .byte   62
        .byte   11
        .byte   11
        .byte   11
        .byte   0
        .byte   0
        .byte   12
        .byte   36
        .byte   0
        .byte   3
        .byte   37
        .byte   11
        .byte   11
        .byte   62
        .byte   11
        .byte   0
        .byte   0
        .byte   13
        .byte   15
        .byte   0
        .byte   73
        .byte   19
        .byte   0
        .byte   0
        .byte   0
        .section        .debug_info,"",@progbits
        .word   .Ldebug_info_end0-.Ldebug_info_start0
.Ldebug_info_start0:
        .half   5
        .byte   1
        .byte   4
        .word   .debug_abbrev
        .byte   1
        .byte   0
        .half   29
        .byte   1
        .word   .Lstr_offsets_base0
        .word   .Lline_table_start0
        .byte   2
        .byte   0
        .word   .Lfunc_end2-.Lfunc_begin0
        .word   .Laddr_table_base0
        .byte   2
        .byte   0
        .word   .Lfunc_end0-.Lfunc_begin0
        .byte   1
        .byte   88
        .byte   6
        .byte   1
        .byte   3

        .byte   3
        .byte   2
        .byte   114
        .byte   4
        .byte   9
        .byte   1
        .byte   3
        .word   178
        .byte   4
        .byte   1
        .word   .Ltmp4-.Ltmp0
        .byte   5
        .byte   2
        .byte   114
        .byte   0
        .byte   10
        .byte   1
        .byte   4
        .word   170
        .byte   0
        .byte   0
        .byte   6
        .byte   2
        .word   .Lfunc_end1-.Lfunc_begin1
        .byte   1
        .byte   88
        .byte   7
        .byte   1
        .byte   8

        .word   170

        .byte   3
        .byte   2
        .byte   114
        .byte   20
        .byte   9
        .byte   1
        .byte   8
        .word   178
        .byte   5
        .byte   2
        .byte   114
        .byte   16
        .byte   11
        .byte   1
        .byte   9
        .word   170
        .byte   4
        .byte   3
        .word   .Ltmp11-.Ltmp7
        .byte   5
        .byte   2
        .byte   114
        .byte   12
        .byte   10
        .byte   1
        .byte   10
        .word   170
        .byte   0
        .byte   0
        .byte   7
        .byte   4
        .word   .Lfunc_end2-.Lfunc_begin2
        .byte   1
        .byte   88
        .byte   8
        .byte   1
        .byte   15
        .word   170

        .byte   8
        .byte   3
        .word   158

        .byte   1
        .byte   1
        .byte   2
        .byte   161
        .byte   5
        .byte   9
        .word   170
        .byte   10
        .word   174
        .byte   10
        .byte   0
        .byte   11
        .byte   4
        .byte   5
        .byte   4
        .byte   12
        .byte   5
        .byte   8
        .byte   7
        .byte   13
        .word   170
        .byte   0
.Ldebug_info_end0:
        .section        .debug_str_offsets,"",@progbits
        .word   52
        .half   5
        .half   0
.Lstr_offsets_base0:
        .section        .debug_str,"MS",@progbits,1
.Linfo_string0:
        .asciz  "clang version 24.0.0git (https://github.com/llvm/llvm-project.git 62fd8674914f044d13f7a098c26ffe7626287124)"
.Linfo_string1:
        .asciz  "/app/example.c"
.Linfo_string2:
        .asciz  "/app"
.Linfo_string3:
        .asciz  "datos"
.Linfo_string4:
        .asciz  "int"
.Linfo_string5:
        .asciz  "__ARRAY_SIZE_TYPE__"
.Linfo_string6:
        .asciz  "fill"
.Linfo_string7:
        .asciz  "sumas"
.Linfo_string8:
        .asciz  "main"
.Linfo_string9:
        .asciz  "arr"
.Linfo_string10:
        .asciz  "i"
.Linfo_string11:
        .asciz  "suma"
        .section        .debug_str_offsets,"",@progbits
        .word   .Linfo_string0
        .word   .Linfo_string1
        .word   .Linfo_string2
        .word   .Linfo_string3
        .word   .Linfo_string4
        .word   .Linfo_string5
        .word   .Linfo_string6
        .word   .Linfo_string7
        .word   .Linfo_string8
        .word   .Linfo_string9
        .word   .Linfo_string10
        .word   .Linfo_string11
        .section        .debug_addr,"",@progbits
        .word   .Ldebug_addr_end0-.Ldebug_addr_start0
.Ldebug_addr_start0:
        .half   5
        .byte   4
        .byte   0
.Laddr_table_base0:
        .word   .Lfunc_begin0
        .word   .Ltmp0
        .word   .Lfunc_begin1
        .word   .Ltmp7
        .word   .Lfunc_begin2
        .word   datos
.Ldebug_addr_end0:
        .ident  "clang version 24.0.0git (https://github.com/llvm/llvm-project.git 62fd8674914f044d13f7a098c26ffe7626287124)"
        .section        ".note.GNU-stack","",@progbits
        .addrsig
        .addrsig_sym fill
        .addrsig_sym sumas
        .addrsig_sym datos
        .section        .debug_line,"",@progbits
.Lline_table_start0: