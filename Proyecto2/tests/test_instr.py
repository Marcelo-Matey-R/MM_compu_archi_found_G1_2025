import pytest
from simulador.core.instr import Instr, Fmt

def test_formatos_y_propiedades():
    add = Instr("add", rd=7, rs1=5, rs2=6)
    assert add.fmt is Fmt.R and add.writes_rd and add.reads_rs2
    sw = Instr("sw", rs1=2, rs2=7, imm=-4)
    assert sw.is_store and not sw.writes_rd and sw.reads_rs1 and sw.reads_rs2
    lw = Instr("lw", rd=5, rs1=2, imm=8)
    assert lw.is_load and lw.writes_rd and not lw.reads_rs2
    beq = Instr("beq", rs1=5, rs2=0, imm=-12)
    assert beq.is_branch and not beq.writes_rd

def test_escribir_x0_no_cuenta():
    assert not Instr("addi", rd=0, rs1=0, imm=0).writes_rd   # nop

def test_validaciones():
    with pytest.raises(ValueError):
        Instr("li", rd=5, imm=3)        # pseudoinstruccion: la traduce el parser
    with pytest.raises(ValueError):
        Instr("add", rd=32)

def test_inmutable():
    i = Instr("addi", rd=5, imm=1)
    with pytest.raises(Exception):
        i.rd = 6
