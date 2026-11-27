from pathlib import Path

import pytest

from simulador.core.bits import u32
from simulador.core.isa import execute, mem_access, wb_value
from simulador.core.state import ArchState
from simulador.parser.parser import parse, parse_file, ParseError, hi20, lo12

EJEMPLOS = Path(__file__).resolve().parent.parent / "ejemplos"


def correr(prog, mem_size=4096, max_pasos=100_000):
    """Mini uniciclo para las pruebas: ejecuta hasta salirse del programa."""
    s = ArchState(prog, mem_size)
    for _ in range(max_pasos):
        i = s.fetch(s.pc)
        if i is None:
            return s
        a, b = s.regs.read(i.rs1), s.regs.read(i.rs2)
        r = execute(i, a, b, s.pc)
        ld = mem_access(i, r, s.mem)
        if i.writes_rd:
            s.regs.write(i.rd, wb_value(i, r, ld))
        s.pc = r.target if r.taken else s.pc + 4
    raise AssertionError("el programa no termino")


def campos(prog):
    return [(i.op, i.rd, i.rs1, i.rs2, i.imm) for i in prog.instrs]


# los dos formatos de Godbolt

def test_filtrado_y_completo_dan_el_mismo_programa():
    f = parse_file(EJEMPLOS / "suma_arreglo_filtrado.s")
    c = parse_file(EJEMPLOS / "suma_arreglo_completo.s")
    assert campos(f) == campos(c)
    assert f.data == c.data == bytes(40) # los .byte de debug no entran
    assert f.data_labels == c.data_labels == {"datos": 0}
    assert f.entry == c.entry == f.text_labels["main"]
    for name, addr in f.text_labels.items(): # el completo tiene etiquetas extra
        assert c.text_labels[name] == addr

@pytest.mark.parametrize("archivo", ["suma_arreglo_filtrado.s", "suma_arreglo_completo.s"])
def test_suma_arreglo_da_45(archivo):
    s = correr(parse_file(EJEMPLOS / archivo))
    assert s.regs.read(10) == 45 # a0 = valor de retorno de main
    assert [s.mem.load(4 * k, 4, False) for k in range(10)] == list(range(10))
    assert s.regs.read(2) == 4096 # sp quedo como al inicio

# %hi / %lo

@pytest.mark.parametrize("x", [0, 0x7FF, 0x800, 0xFFF, 0x12345678, 0xFFFFF800, 0xFFFFFFFF])
def test_hi_lo_reconstruyen_la_direccion(x):
    assert u32((hi20(x) << 12) + lo12(x)) == x

def test_hi_lo_caso_0x800():
    assert hi20(0x800) == 1 and lo12(0x800) == -2048

# pseudoinstrucciones

def ops(src):
    return [(i.op, i.rd, i.rs1, i.rs2, i.imm) for i in parse(src).instrs]

def test_li():
    assert ops("li a0, 5") == [("addi", 10, 0, 0, 5)]
    assert ops("li a0, -2048") == [("addi", 10, 0, 0, -2048)]
    assert ops("li a0, 0x12345") == [("lui", 10, 0, 0, 0x12), ("addi", 10, 10, 0, 0x345)]
    assert ops("li a0, 0x1000") == [("lui", 10, 0, 0, 1)]          # sin addi
    s = correr(parse("li a0, 0x12345800\nli a1, -1"))
    assert s.regs.read(10) == 0x12345800 and s.regs.read(11) == 0xFFFFFFFF

def test_pseudos_simples():
    assert ops("nop") == [("addi", 0, 0, 0, 0)]
    assert ops("mv a0, a1") == [("addi", 10, 11, 0, 0)]
    assert ops("not a0, a1") == [("xori", 10, 11, 0, -1)]
    assert ops("neg a0, a1") == [("sub", 10, 0, 11, 0)]
    assert ops("ret") == [("jalr", 0, 1, 0, 0)]
    assert ops("jr a0") == [("jalr", 0, 10, 0, 0)]

def test_saltos_e_inversiones():
    src = "L: bgt a0, a1, L\nble a0, a1, L\nbeqz a0, L\nblez a0, L\nj L\ncall L"
    assert ops(src) == [
        ("blt", 0, 11, 10, 0),      # bgt a0,a1 == blt a1,a0
        ("bge", 0, 11, 10, -4),     # ble a0,a1 == bge a1,a0
        ("beq", 0, 10, 0, -8),
        ("bge", 0, 0, 10, -12),     # blez a0 == bge zero,a0
        ("jal", 0, 0, 0, -16),
        ("jal", 1, 0, 0, -20),
    ]

def test_salto_hacia_adelante_despues_de_li_grande():
    # li grande ocupa 2 instrucciones: la etiqueta debe quedar en 12, no en 8
    p = parse("j FIN\nli a0, 0x12345\nFIN: ret")
    assert p.text_labels["FIN"] == 12 and p.instrs[0].imm == 12

def test_la_y_memoria_con_lo():
    src = ".data\nx: .word 7\ny: .word 9\n.text\nla a0, y\nlw a1, 0(a0)\nlui a2, %hi(x)\nlw a3, %lo(x)(a2)"
    s = correr(parse(src))
    assert s.regs.read(11) == 9 and s.regs.read(13) == 7

# datos

def test_directivas_de_datos():
    src = (".data\na: .byte 1, 2\n.p2align 2\nb: .half -1\nc: .word 0x11223344\n"
           "s: .asciz \"hi\"\n.text\nmain: ret")
    p = parse(src)
    assert p.data_labels == {"a": 0, "b": 4, "c": 6, "s": 10}
    assert p.data == bytes([1, 2, 0, 0, 0xFF, 0xFF, 0x44, 0x33, 0x22, 0x11]) + b"hi\0"

def test_word_con_etiqueta():
    p = parse(".text\nmain: ret\nf: ret\n.section .rodata\ntabla: .word f, main")
    assert p.data == (4).to_bytes(4, "little") + (0).to_bytes(4, "little")

def test_secciones_debug_se_ignoran():
    p = parse(".text\nmain: ret\n.section .debug_info,\"\",@progbits\nx: .word 99\n.Lbasura:")
    assert p.data == b"" and "x" not in p.data_labels and ".Lbasura" not in p.text_labels

def test_entry_es_main():
    p = parse("f: ret\nmain: call f\nret")
    assert p.entry == 4

def test_comentarios():
    assert ops("addi a0, a0, 1  # incrementa") == [("addi", 10, 10, 0, 1)]

# errores con numero de linea

@pytest.mark.parametrize("src,msg", [
    ("addi a0, a0, 1\nflw fa0, 0(a0)", "linea 2: instruccion no soportada"),
    ("j NOEXISTE", "no definida"),
    ("addi a0, a0, 5000", "fuera de rango"),
    ("L: nop\nL: nop", "repetida"),
    ("add a0, a1", "espera 3 operandos"),
    ("add a0, a1, q9", "registro desconocido"),
])
def test_errores(src, msg):
    with pytest.raises(ParseError, match=msg):
        parse(src)
