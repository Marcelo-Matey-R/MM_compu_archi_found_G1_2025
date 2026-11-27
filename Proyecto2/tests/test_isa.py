import pytest
from simulador.core.bits import u32
from simulador.core.instr import Instr
from simulador.core.isa import execute, mem_access, wb_value
from simulador.core.state import DataMemory

def ex(op, a=0, b=0, pc=0, **kw):
    return execute(Instr(op, **kw), u32(a), u32(b), pc)

# aritmeticas

def test_add_desborda():
    assert ex("add", 0x7FFFFFFF, 1).alu == 0x80000000

def test_sub_negativo():
    assert ex("sub", 2, 5).alu == u32(-3)

def test_addi_con_inmediato_negativo():
    assert ex("addi", 10, imm=-1).alu == 9

def test_slt_vs_sltu():
    assert ex("slt", -1, 1).alu == 1
    assert ex("sltu", -1, 1).alu == 0
    assert ex("sltiu", 5, imm=-1).alu == 1     # -1 como sin signo es enorme

def test_desplazamientos():
    assert ex("sll", 1, 33).alu == 2           # solo 5 bits bajos de b
    assert ex("sra", -8, 1).alu == u32(-4)
    assert ex("srl", -8, 1).alu == 0x7FFFFFFC
    assert ex("srai", -8, imm=1).alu == u32(-4)

# extension M

def test_mul_y_altos():
    assert ex("mul", 0x10000, 0x10000).alu == 0
    assert ex("mulhu", 0x10000, 0x10000).alu == 1
    assert ex("mulh", -1, -1).alu == 0          # (-1)*(-1) = 1, parte alta 0
    assert ex("mulhsu", -1, 1).alu == 0xFFFFFFFF

def test_div_trunca_hacia_cero():
    assert ex("div", -7, 2).alu == u32(-3)
    assert ex("rem", -7, 2).alu == u32(-1)
    assert ex("divu", 7, 2).alu == 3

def test_div_casos_especiales():
    assert ex("div", 5, 0).alu == 0xFFFFFFFF
    assert ex("rem", 5, 0).alu == 5
    assert ex("divu", 5, 0).alu == 0xFFFFFFFF
    assert ex("remu", 5, 0).alu == 5
    assert ex("div", -2**31, -1).alu == 0x80000000
    assert ex("rem", -2**31, -1).alu == 0

# saltos

def test_branches():
    r = ex("beq", 3, 3, pc=100, imm=-8)
    assert r.taken and r.target == 92
    assert not ex("bne", 3, 3, imm=8).taken
    assert ex("blt", -1, 1, imm=8).taken
    assert not ex("bltu", -1, 1, imm=8).taken
    assert ex("bge", 1, 1, imm=8).taken
    assert ex("bgeu", -1, 1, imm=8).taken

def test_jal_y_jalr():
    r = ex("jal", pc=8, rd=1, imm=16)
    assert r.taken and r.target == 24 and r.alu == 12
    r = ex("jalr", 101, pc=8, rd=1, imm=0)
    assert r.taken and r.target == 100 and r.alu == 12   # bit 0 en cero

def test_lui_auipc():
    assert ex("lui", rd=5, imm=0x12345).alu == 0x12345000
    assert ex("auipc", pc=8, rd=5, imm=1).alu == 0x1008
    assert ex("lui", rd=5, imm=0xFFFFF).alu == 0xFFFFF000

# memoria y write-back

def test_store_y_load():
    m = DataMemory(64)
    sw = Instr("sw", rs1=2, rs2=5, imm=-4)
    r = execute(sw, 16, 0xCAFEBABE, 0)
    assert r.alu == 12 and r.store_val == 0xCAFEBABE
    assert mem_access(sw, r, m) is None
    lb = Instr("lb", rd=6, rs1=2, imm=-4)
    r = execute(lb, 16, 0, 0)
    loaded = mem_access(lb, r, m)
    assert loaded == u32(-66)               # 0xBE con signo
    assert wb_value(lb, r, loaded) == loaded

def test_wb_de_aritmetica_y_jal():
    i = Instr("add", rd=5, rs1=6, rs2=7)
    r = execute(i, 2, 3, 0)
    assert wb_value(i, r, None) == 5
    j = Instr("jal", rd=1, imm=8)
    r = execute(j, 0, 0, 40)
    assert wb_value(j, r, None) == 44

def test_programa_completo_a_mano():
    """Mini 'uniciclo' para comprobar que las tres partes encajan."""
    from simulador.core.state import ArchState
    prog = [
        Instr("addi", rd=5, imm=3),             # t0 = 3
        Instr("addi", rd=6, imm=4),             # t1 = 4
        Instr("add",  rd=7, rs1=5, rs2=6),      # t2 = 7
        Instr("sw",   rs1=0, rs2=7, imm=0),     # mem[0] = 7
        Instr("lw",   rd=8, rs1=0, imm=0),      # s0 = mem[0]
        Instr("beq",  rs1=8, rs2=7, imm=8),     # salta la siguiente
        Instr("addi", rd=9, imm=99),            # no debe ejecutarse
    ]
    s = ArchState(prog, 64)
    while (i := s.fetch(s.pc)) is not None:
        a, b = s.regs.read(i.rs1), s.regs.read(i.rs2)
        r = execute(i, a, b, s.pc)
        ld = mem_access(i, r, s.mem)
        if i.writes_rd:
            s.regs.write(i.rd, wb_value(i, r, ld))
        s.pc = r.target if r.taken else s.pc + 4
    assert s.regs.read(7) == 7 and s.regs.read(8) == 7
    assert s.regs.read(9) == 0 and s.mem.load(0, 4, False) == 7