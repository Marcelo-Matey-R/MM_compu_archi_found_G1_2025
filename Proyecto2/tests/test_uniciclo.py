from pathlib import Path

from simulador.core.instr import Instr
from simulador.parser.parser import parse, parse_file
from simulador.procesadores.base import Mod
from simulador.procesadores.uniciclo import Uniciclo, active_modules

EJEMPLOS = Path(__file__).resolve().parent.parent / "ejemplos"


def test_periodo_del_libro():
    # Harris & Harris: Tc uniciclo = 750 ps con su tabla de retardos
    assert Uniciclo(parse("ret")).period_ps == 750

def test_suma_arreglo():
    cpu = Uniciclo(parse_file(EJEMPLOS / "suma_arreglo_filtrado.s"))
    cpu.run()
    m = cpu.metrics()
    assert cpu.state.regs.read(10) == 45
    assert m["ciclos"] == m["instrucciones"] and m["CPI"] == 1.0
    assert m["tiempo_ps"] == m["ciclos"] * 750

def test_un_step_es_una_instruccion():
    cpu = Uniciclo(parse("addi a0, zero, 3\naddi a1, a0, 4"))
    info = cpu.step()
    assert info.cycle == 1 and info.stages["Uniciclo"].op == "addi"
    assert cpu.state.regs.read(10) == 3 and cpu.state.pc == 4
    cpu.step()
    assert cpu.state.regs.read(11) == 7

def test_fin_sin_gastar_ciclo():
    cpu = Uniciclo(parse("nop"))
    cpu.step()
    info = cpu.step() # PC fuera del programa
    assert info.halted and cpu.cycle == 1 and cpu.retired == 1
    assert cpu.step().halted and cpu.cycle == 1 # step despues de terminar no hace nada

def test_ecall_exit():
    cpu = Uniciclo(parse("li a7, 10\necall\naddi a0, zero, 99"))
    cpu.run()
    assert cpu.state.regs.read(10) == 0 and cpu.retired == 2

def test_ecall_no_soportado_se_ignora():
    cpu = Uniciclo(parse("li a7, 1\necall\naddi a0, zero, 5"))
    cpu.step(); info = cpu.step()
    assert not info.halted and "no soportada" in info.events[0]
    cpu.run()
    assert cpu.state.regs.read(10) == 5

def test_modulos_activos():
    add = active_modules(Instr("add", rd=5, rs1=6, rs2=7))
    assert Mod.ALU in add and Mod.RF_WRITE in add and Mod.DMEM not in add
    lw = active_modules(Instr("lw", rd=5, rs1=2, imm=4))
    assert {Mod.DMEM, Mod.EXTEND, Mod.ALU, Mod.RF_WRITE} <= lw
    sw = active_modules(Instr("sw", rs1=2, rs2=5, imm=4))
    assert Mod.DMEM in sw and Mod.RF_WRITE not in sw
    beq = active_modules(Instr("beq", rs1=5, rs2=6, imm=8))
    assert Mod.PC_TARGET in beq and Mod.RF_WRITE not in beq
    nop = active_modules(Instr("addi"))
    assert Mod.RF_WRITE not in nop # escribir en x0 no cuenta

def test_evento_de_salto():
    cpu = Uniciclo(parse("L: beq zero, zero, F\nnop\nF: nop"))
    assert "salto" in cpu.step().events[0]
    assert cpu.state.pc == 8
