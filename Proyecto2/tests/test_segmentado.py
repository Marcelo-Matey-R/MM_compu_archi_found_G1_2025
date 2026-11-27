from pathlib import Path

import pytest

from simulador.parser.parser import parse, parse_file
from simulador.procesadores.uniciclo import Uniciclo
from simulador.procesadores.segmentado_stalls import SegmentadoStalls
from simulador.procesadores.segmentado_forwarding import SegmentadoForwarding

RAIZ = Path(__file__).resolve().parent.parent
EJEMPLOS = RAIZ / "ejemplos"
TAREA2 = RAIZ / "Tarea2"

SEGMENTADOS = [SegmentadoStalls, SegmentadoForwarding]


def correr(cls, fuente: str):
    cpu = cls(parse(fuente))
    cpu.run()
    return cpu


# Mismo resultado que el uniciclo (modelo de referencia)

PROGRAMAS = [
    EJEMPLOS / "suma_arreglo_filtrado.s",
    TAREA2 / "operacion2_pipelined.s",
    TAREA2 / "operacion3_pipelined.s",
]


@pytest.mark.parametrize("cls", SEGMENTADOS)
@pytest.mark.parametrize("ruta", PROGRAMAS, ids=lambda p: p.name)
def test_igual_que_uniciclo(cls, ruta):
    if not ruta.exists():
        pytest.skip(f"no existe {ruta}")
    ref = Uniciclo(parse_file(ruta))
    ref.run()
    cpu = cls(parse_file(ruta))
    cpu.run()
    assert cpu.state.regs.as_list() == ref.state.regs.as_list()
    assert cpu.state.mem.words() == ref.state.mem.words()
    assert cpu.retired == ref.retired


@pytest.mark.parametrize("cls", SEGMENTADOS)
def test_suma_arreglo_da_45(cls):
    cpu = cls(parse_file(EJEMPLOS / "suma_arreglo_filtrado.s"))
    cpu.run()
    assert cpu.state.regs.read(10) == 45


# Conteo exacto de ciclos
# 3 instrucciones sin riesgos: 3 + 4 ciclos de llenado = 7

@pytest.mark.parametrize("cls", SEGMENTADOS)
def test_sin_riesgos(cls):
    cpu = correr(cls, "addi a0, zero, 1\naddi a1, zero, 2\naddi a2, zero, 3")
    assert cpu.cycle == 7 and cpu.stalls == 0 and cpu.flushes == 0


def test_dependencia_alu_stalls():
    cpu = correr(SegmentadoStalls, "addi a0, zero, 1\nadd a1, a0, a0")
    assert cpu.stalls == 2 and cpu.cycle == 2 + 4 + 2
    assert cpu.state.regs.read(11) == 2


def test_dependencia_alu_forwarding():
    cpu = correr(SegmentadoForwarding, "addi a0, zero, 1\nadd a1, a0, a0")
    assert cpu.stalls == 0 and cpu.cycle == 2 + 4
    assert cpu.state.regs.read(11) == 2


def test_dependencia_a_dos_instrucciones():
    # productor en MEM cuando el consumidor esta en ID
    src = "addi a0, zero, 5\nnop\nadd a1, a0, a0"
    assert correr(SegmentadoStalls, src).stalls == 1
    cpu = correr(SegmentadoForwarding, src)
    assert cpu.stalls == 0 and cpu.state.regs.read(11) == 10


def test_load_use():
    src = "addi a0, zero, 7\nsw a0, 0(zero)\nlw a1, 0(zero)\nadd a2, a1, a1"
    s = correr(SegmentadoStalls, src)
    f = correr(SegmentadoForwarding, src)
    assert f.stalls == 1                         # solo el load-use
    assert s.stalls == 2 + 2                     # addi->sw y lw->add
    assert s.state.regs.read(12) == f.state.regs.read(12) == 14


def test_store_usa_dato_adelantado():
    cpu = correr(SegmentadoForwarding, "addi a0, zero, 9\nsw a0, 8(zero)")
    assert cpu.stalls == 0 and cpu.state.mem.load(8, 4, True) == 9


@pytest.mark.parametrize("cls", SEGMENTADOS)
def test_salto_tomado_hace_flush(cls):
    src = "beq zero, zero, F\naddi a0, zero, 1\naddi a1, zero, 1\nF: addi a2, zero, 3"
    cpu = correr(cls, src)
    assert cpu.flushes == 1
    assert cpu.state.regs.read(10) == 0 and cpu.state.regs.read(11) == 0
    assert cpu.state.regs.read(12) == 3
    assert cpu.retired == 2


@pytest.mark.parametrize("cls", SEGMENTADOS)
def test_ecall_descarta_lo_que_viene_detras(cls):
    src = "li a7, 10\necall\naddi a0, zero, 99\nsw a0, 0(zero)"
    cpu = correr(cls, src)
    assert cpu.state.regs.read(10) == 0
    assert cpu.state.mem.load(0, 4, True) == 0


def test_cinco_etapas_en_cycleinfo():
    cpu = SegmentadoForwarding(parse("addi a0, zero, 1\naddi a1, zero, 2"))
    info = cpu.step()
    assert list(info.stages) == ["IF", "ID", "EX", "MEM", "WB"]
    assert info.stages["IF"].op == "addi" and info.stages["ID"] is None
    info = cpu.step()
    assert info.stages["ID"].rd == 10 and info.stages["IF"].rd == 11


def test_hazards_para_la_gui():
    cpu = SegmentadoStalls(parse("addi a0, zero, 1\nadd a1, a0, a0"))
    vistos = set()
    while not cpu.halted:
        vistos |= cpu.step().hazards
    assert "datos" in vistos


def test_periodos():
    p = parse("nop")
    # con forwarding el ciclo es mas largo (mux extra en EX)
    assert SegmentadoStalls(p).period_ps == 320
    assert SegmentadoForwarding(p).period_ps == 350
