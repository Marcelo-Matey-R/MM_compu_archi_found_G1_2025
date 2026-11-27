import pytest
from simulador.core.state import ArchState, DataMemory, RegisterFile, MemoryError_
from simulador.core.instr import Instr

def test_x0_siempre_cero():
    r = RegisterFile()
    r.write(0, 123)
    assert r.read(0) == 0

def test_registros_se_recortan_a_32_bits():
    r = RegisterFile()
    r.write(5, -1)
    assert r.read(5) == 0xFFFFFFFF

def test_little_endian():
    m = DataMemory(16)
    m.store(0, 0x11223344, 4)
    assert m.load(0, 1, signed=False) == 0x44     # byte menos significativo primero
    assert m.load(3, 1, signed=False) == 0x11
    assert m.load(2, 2, signed=False) == 0x1122

def test_lb_vs_lbu_y_lh_vs_lhu():
    m = DataMemory(16)
    m.store(4, 0xFF80, 2)
    assert m.load(4, 1, signed=True) == 0xFFFFFF80    # lb
    assert m.load(4, 1, signed=False) == 0x80         # lbu
    assert m.load(4, 2, signed=True) == 0xFFFFFF80    # lh
    assert m.load(4, 2, signed=False) == 0xFF80       # lhu

def test_sb_solo_escribe_un_byte():
    m = DataMemory(16)
    m.store(0, 0xAABBCCDD, 4)
    m.store(1, 0x12345678, 1)                         # sb guarda 0x78
    assert m.load(0, 4, signed=False) == 0xAABB78DD

def test_errores():
    m = DataMemory(16)
    with pytest.raises(MemoryError_):
        m.load(16, 4, signed=False)                   # fuera de rango
    with pytest.raises(MemoryError_):
        m.load(2, 4, signed=False)                    # desalineado

def test_estado_inicial_y_fetch():
    prog = [Instr("addi", rd=5, imm=1), Instr("addi", rd=6, imm=2)]
    s = ArchState(prog, mem_size=1024)
    assert s.regs.read(2) == 1024                     # sp al final
    assert s.fetch(4) is prog[1]
    assert s.fetch(8) is None                         # fin del programa

def test_last_used_y_words():
    m = DataMemory(16)
    assert m.last_used() == -1
    m.store(8, 7, 4)
    assert m.last_used() == 8
    assert m.words(0, 12)[2] == (8, 7)
