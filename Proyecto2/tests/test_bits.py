from simulador.core.bits import u32, s32, sext, zext, fits_signed, hex32

def test_desbordamiento_circular():
    assert u32(0x7FFFFFFF + 1) == 0x80000000
    assert u32(0xFFFFFFFF + 1) == 0
    assert u32(0 - 1) == 0xFFFFFFFF

def test_interpretacion_con_signo():
    assert s32(0xFFFFFFFF) == -1
    assert s32(0x80000000) == -2**31
    assert s32(0x7FFFFFFF) == 2**31 - 1
    assert s32(5) == 5

def test_blt_vs_bltu():
    a, b = u32(-1), 1
    assert s32(a) < s32(b)      # blt:  -1 < 1
    assert not (a < b)          # bltu: 0xFFFFFFFF < 1 es falso

def test_sra_vs_srl():
    a = u32(-8)                 # 0xFFFFFFF8
    assert u32(s32(a) >> 1) == u32(-4)   # sra
    assert (a >> 1) == 0x7FFFFFFC        # srl

def test_sext():
    assert sext(0xFFF, 12) == 0xFFFFFFFF
    assert sext(0x7FF, 12) == 0x7FF
    assert sext(0x800, 12) == u32(-2048)
    assert sext(0x80, 8) == 0xFFFFFF80   # lb de 0x80
    assert sext(-1, 12) == 0xFFFFFFFF    # acepta negativos de Python

def test_zext():
    assert zext(0xFFFFFF80, 8) == 0x80   # lbu

def test_fits_signed():
    assert fits_signed(2047, 12) and fits_signed(-2048, 12)
    assert not fits_signed(2048, 12) and not fits_signed(-2049, 12)

def test_hex32():
    assert hex32(42) == "0x0000002A"
    assert hex32(-1) == "0xFFFFFFFF"
