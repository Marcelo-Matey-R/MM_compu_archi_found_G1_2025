from pathlib import Path

from simulador.core.instr import Instr
from simulador.parser.parser import parse, parse_file
from simulador.procesadores.base import Mod
from simulador.procesadores.uniciclo import Uniciclo
from simulador.procesadores.multiciclo import Multiciclo, Estado, modulos_estado

EJEMPLOS = Path(__file__).resolve().parent.parent / "ejemplos"


def step_instr(cpu):
    """Avanza ciclos hasta terminar la instruccion en curso. Devuelve el ultimo CycleInfo."""
    info = cpu.step()
    while cpu.estado is not Estado.FETCH and not cpu.halted:
        info = cpu.step()
    return info


def test_periodo():
    # Depende de la tabla de latencias y del camino critico elegido (estado Decode).
    assert Multiciclo(parse("ret")).period_ps == 375


def test_suma_arreglo():
    cpu = Multiciclo(parse_file(EJEMPLOS / "suma_arreglo_filtrado.s"))
    cpu.run()
    m = cpu.metrics()
    assert cpu.state.regs.read(10) == 45
    assert 3 <= m["CPI"] <= 5
    assert m["tiempo_ps"] == m["ciclos"] * cpu.period_ps


def test_equivalencia_con_uniciclo():
    prog = parse_file(EJEMPLOS / "suma_arreglo_filtrado.s")
    uni, multi = Uniciclo(prog), Multiciclo(prog)
    uni.run(); multi.run()
    assert multi.state.regs.as_list() == uni.state.regs.as_list()
    assert multi.state.mem.words() == uni.state.mem.words()
    assert multi.retired == uni.retired


def test_un_step_es_un_ciclo_no_una_instruccion():
    cpu = Multiciclo(parse("addi a0, zero, 3\naddi a1, a0, 4"))
    info = cpu.step()                                   # S0 Fetch
    assert info.cycle == 1 and info.stages["Multiciclo"].op == "addi"
    assert "Fetch" in info.events[0]
    assert cpu.state.pc == 4                            # Fetch ya hizo PC <- PC+4
    assert cpu.state.regs.read(10) == 0                 # todavia no escribio
    cpu.step(); cpu.step(); cpu.step()                  # Decode, ExecuteI, ALUWB
    assert cpu.state.regs.read(10) == 3 and cpu.retired == 1
    step_instr(cpu)
    assert cpu.state.regs.read(11) == 7


def test_ciclos_por_instruccion():
    casos = [
        ("lw a0, 0(zero)", 5),
        ("sw a0, 0(zero)", 4),
        ("add a0, a1, a2", 4),
        ("addi a0, zero, 1", 4),
        ("L: bne zero, zero, L", 3),          # no tomado
        ("jal ra, F\nF: nop", 4 + 4),         # jal (4) + nop (4)
    ]
    for src, ciclos in casos:
        cpu = Multiciclo(parse(src))
        cpu.run()
        assert cpu.cycle == ciclos, src


def test_fin_sin_gastar_ciclo():
    cpu = Multiciclo(parse("nop"))
    step_instr(cpu)                                     # nop = addi x0: 4 ciclos
    info = cpu.step()                                   # PC fuera del programa
    assert info.halted and cpu.cycle == 4 and cpu.retired == 1
    assert cpu.step().halted and cpu.cycle == 4         # step despues de terminar no hace nada


def test_ecall_exit():
    cpu = Multiciclo(parse("li a7, 10\necall\naddi a0, zero, 99"))
    cpu.run()
    assert cpu.state.regs.read(10) == 0 and cpu.retired == 2


def test_ecall_no_soportado_se_ignora():
    cpu = Multiciclo(parse("li a7, 1\necall\naddi a0, zero, 5"))
    step_instr(cpu)                                     # li
    info = step_instr(cpu)                              # ecall
    assert not info.halted and any("no soportada" in e for e in info.events)
    cpu.run()
    assert cpu.state.regs.read(10) == 5


def test_modulos_por_estado():
    add = Instr("add", rd=5, rs1=6, rs2=7)
    assert Mod.ALU in modulos_estado(Estado.EXEC_R, add)
    assert Mod.RF_WRITE in modulos_estado(Estado.ALUWB, add)
    assert Mod.EXTEND not in modulos_estado(Estado.DECODE, add)      # tipo R no extiende
    assert Mod.DMEM not in modulos_estado(Estado.EXEC_R, add)

    lw = Instr("lw", rd=5, rs1=2, imm=4)
    assert Mod.EXTEND in modulos_estado(Estado.DECODE, lw)
    assert Mod.ALU in modulos_estado(Estado.MEMADR, lw)
    assert Mod.DMEM in modulos_estado(Estado.MEMREAD, lw)
    assert Mod.RF_WRITE in modulos_estado(Estado.MEMWB, lw)

    sw = Instr("sw", rs1=2, rs2=5, imm=4)
    assert Mod.DMEM in modulos_estado(Estado.MEMWRITE, sw)
    assert all(Mod.RF_WRITE not in modulos_estado(e, sw)             # sw no pasa por WB
               for e in (Estado.DECODE, Estado.MEMADR, Estado.MEMWRITE))

    beq = Instr("beq", rs1=5, rs2=6, imm=8)
    assert Mod.PC not in modulos_estado(Estado.BEQ, beq, tomado=False)
    assert {Mod.PC, Mod.RESULT_MUX} <= modulos_estado(Estado.BEQ, beq, tomado=True)

    # En el datapath de H&H la ALU suma PC+4 y PC+imm: no hay sumadores aparte
    for e in Estado:
        assert not ({Mod.PC_PLUS4, Mod.PC_TARGET, Mod.PC_MUX} & modulos_estado(e, beq, True))


def test_evento_de_salto():
    cpu = Multiciclo(parse("L: beq zero, zero, F\nnop\nF: nop"))
    info = step_instr(cpu)                              # el ultimo ciclo es S10 BEQ
    assert any("PC <-" in e for e in info.events)
    assert cpu.state.pc == 8