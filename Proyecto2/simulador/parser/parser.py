"""Parser de ensamblador RISC-V -> Program.

Funciona en dos pasadas:
  Pasada 1: recorre las lineas, ignora lo que no es programa, expande las
            pseudoinstrucciones y asigna una direccion a cada instruccion,
            a cada dato y a cada etiqueta. Las referencias a etiquetas
            (saltos, %hi, %lo, .word etiqueta) se dejan pendientes.
  Pasada 2: con todas las direcciones conocidas, resuelve las referencias
            y crea los Instr definitivos.

Hacen falta dos pasadas porque un salto puede ir a una etiqueta que todavia
no se ha visto, y porque 'li' o 'la' pueden ocupar 2 instrucciones, lo que
mueve las direcciones de todo lo que viene despues.

Acepta tanto la salida filtrada de Godbolt (sin directivas) como la completa.
"""

import re
from dataclasses import dataclass

from ..core.bits import s32, u32, sext, fits_signed
from ..core.instr import Instr, FORMATS, Fmt
from ..core.program import Program
from ..core.state import REG_NAMES


class ParseError(Exception):
    def __init__(self, line: int, msg: str):
        super().__init__(f"linea {line}: {msg}")
        self.line = line


# ---------------------------------------------------------------------------
# Registros: nombres ABI (a0, sp...), x0..x31 y el alias fp = s0
# ---------------------------------------------------------------------------

REGS = {name: i for i, name in enumerate(REG_NAMES)}
REGS.update({f"x{i}": i for i in range(32)})
REGS["fp"] = 8


def parse_reg(tok: str, line: int) -> int:
    try:
        return REGS[tok.strip().lower()]
    except KeyError:
        raise ParseError(line, f"registro desconocido: {tok!r}") from None


# Inmediatos. Un inmediato puede ser:
#   - un numero:            12, -4, 0x10
#   - una etiqueta:         .LBB0_1
#   - %hi(sim) / %lo(sim):  %hi(datos), %lo(arr+8)
# Mientras no se conocen las direcciones se guarda como Ref.

@dataclass(frozen=True)
class Ref:
    kind: str      # "pcrel" (salto), "hi", "lo" o "abs" (.word etiqueta)
    sym: str
    addend: int = 0


RE_RELOC = re.compile(r"^%(hi|lo)\(\s*([^)+\-\s]+)\s*(?:([+-])\s*(\w+))?\s*\)$")
RE_MEMOP = re.compile(r"^(.*)\(\s*(\w+)\s*\)$")      # imm(reg)


def parse_int(tok: str) -> int | None:
    """Numero en decimal o hex (con signo). None si no es un numero."""
    try:
        return int(tok.strip(), 0)
    except ValueError:
        return None


def parse_imm(tok: str, line: int, label_kind: str = "pcrel") -> int | Ref:
    tok = tok.strip()
    n = parse_int(tok)
    if n is not None:
        return n
    m = RE_RELOC.match(tok)
    if m:
        kind, sym, sign, add = m.groups()
        addend = 0
        if add is not None:
            addend = parse_int(add)
            if addend is None:
                raise ParseError(line, f"desplazamiento invalido en {tok!r}")
            addend = -addend if sign == "-" else addend
        return Ref(kind, sym, addend)
    if tok.startswith("%"):
        raise ParseError(line, f"reubicacion no soportada: {tok!r}")
    return Ref(label_kind, tok)               # una etiqueta


def hi20(v: int) -> int:
    """Parte alta para lui. Suma 0x800 porque la parte baja se extiende con signo."""
    return (u32(v) + 0x800) >> 12 & 0xFFFFF


def lo12(v: int) -> int:
    """Parte baja para addi, como entero con signo (-2048..2047)."""
    return s32(sext(v & 0xFFF, 12))


# Instruccion a medio armar de la pasada 1

@dataclass
class Proto:
    op: str
    rd: int = 0
    rs1: int = 0
    rs2: int = 0
    imm: int | Ref = 0
    text: str = ""
    line: int = 0


# Secciones y directivas

TEXT, DATA, IGNORE = "text", "data", "ignore"

DATA_PREFIXES = (".data", ".bss", ".rodata", ".sdata", ".sbss", ".srodata")

# Directivas que generan datos: nombre -> tamano de cada elemento
DATA_DIRECTIVES = {
    ".byte": 1,
    ".half": 2, ".short": 2, ".2byte": 2,
    ".word": 4, ".long": 4, ".4byte": 4,
}
STRING_DIRECTIVES = {".ascii": False, ".asciz": True, ".string": True}  # True = agrega \0


def section_kind(name: str) -> str:
    if name.startswith(".text"):
        return TEXT
    if name.startswith(DATA_PREFIXES):
        return DATA
    return IGNORE                           # .debug_*, .note.*, .comment...


def split_operands(s: str) -> list[str]:
    """Separa por comas, respetando las que estan dentro de comillas."""
    out, cur, in_str = [], "", False
    for ch in s:
        if ch == '"':
            in_str = not in_str
        if ch == "," and not in_str:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def strip_comment(s: str) -> str:
    """Quita lo que sigue a '#', salvo si esta dentro de comillas."""
    in_str = False
    for i, ch in enumerate(s):
        if ch == '"':
            in_str = not in_str
        elif ch == "#" and not in_str:
            return s[:i]
    return s


# El parser

class Parser:
    def __init__(self):
        self.protos: list[Proto] = []          # instrucciones (pasada 1)
        self.data = bytearray()                # memoria de datos inicial
        self.data_fixups: list[tuple[int, int, Ref, int]] = []  # (dir, tamano, ref, linea)
        self.text_labels: dict[str, int] = {}
        self.data_labels: dict[str, int] = {}
        self.pending: list[tuple[str, int]] = []  # etiquetas sin direccion aun
        self.section = TEXT                    # sin directivas, todo empieza en .text

    # etiquetas pendientes

    def _define(self, name: str, table: dict, addr: int, line: int):
        if name in self.text_labels or name in self.data_labels:
            raise ParseError(line, f"etiqueta repetida: {name}")
        table[name] = addr

    def _flush_text(self):
        for name, line in self.pending:
            self._define(name, self.text_labels, 4 * len(self.protos), line)
        self.pending.clear()

    def _flush_data(self):
        for name, line in self.pending:
            self._define(name, self.data_labels, len(self.data), line)
        self.pending.clear()

    # pasada 1

    def parse(self, source: str) -> Program:
        for n, raw in enumerate(source.splitlines(), start=1):
            self._line(raw, n)
        # etiquetas al final del archivo: apuntan al final de su seccion
        self._flush_data() if self.section == DATA else self._flush_text()
        return self._resolve()

    def _line(self, raw: str, n: int):
        s = strip_comment(raw).strip()
        while s:
            # una o varias etiquetas al inicio de la linea: "fin: ret"
            m = re.match(r"^([A-Za-z_.$][\w.$]*):\s*(.*)$", s)
            if not m:
                break
            if self.section != IGNORE:
                self.pending.append((m.group(1), n))
            s = m.group(2)
        if not s:
            return
        if s.startswith("."):
            self._directive(s, n)
        elif self.section != IGNORE:
            self._instruction(s, raw.strip(), n)

    def _directive(self, s: str, n: int):
        parts = s.split(None, 1)
        name, args = parts[0], (parts[1] if len(parts) > 1 else "")

        # cambio de seccion
        if name in (".text", ".data", ".bss", ".rodata"):
            self._change_section(section_kind(name))
            return
        if name == ".section":
            self._change_section(section_kind(args.split(",")[0].strip()))
            return

        if self.section == IGNORE:
            return

        # directivas de datos. Si aparecen en .text (salida filtrada de
        # Godbolt, que no muestra .bss/.data), igual van a la memoria de datos.
        if name in (".zero", ".space"):
            self._emit_data(bytes(self._num(split_operands(args)[0], n)), n)
        elif name in DATA_DIRECTIVES:
            size = DATA_DIRECTIVES[name]
            for item in split_operands(args):
                v = parse_imm(item, n, label_kind="abs")
                if isinstance(v, Ref):
                    self._flush_data()
                    self.data_fixups.append((len(self.data), size, v, n))
                    v = 0
                self._emit_data((v & ((1 << 8 * size) - 1)).to_bytes(size, "little"), n)
        elif name in STRING_DIRECTIVES:
            text = args.strip()
            if not (text.startswith('"') and text.endswith('"')):
                raise ParseError(n, f"cadena invalida: {args!r}")
            data = text[1:-1].encode().decode("unicode_escape").encode("latin-1")
            if STRING_DIRECTIVES[name]:
                data += b"\0"
            self._emit_data(data, n)
        elif name in (".p2align", ".align", ".balign"):
            if self.section == DATA:
                a = self._num(split_operands(args)[0], n)
                align = a if name == ".balign" else 1 << a
                while len(self.data) % align:
                    self.data.append(0)
        # el resto (.globl, .type, .size, .loc, .cfi_*, .file, ...) se ignora

    def _change_section(self, kind: str):
        if self.section == DATA:
            self._flush_data()
        elif self.section == TEXT:
            self._flush_text()
        else:
            self.pending.clear()
        self.section = kind

    def _emit_data(self, data: bytes, n: int):
        self._flush_data()
        self.data += data

    def _num(self, tok: str, n: int) -> int:
        v = parse_int(tok)
        if v is None:
            raise ParseError(n, f"se esperaba un numero: {tok!r}")
        return v

    # instrucciones y pseudoinstrucciones

    def _emit(self, proto: Proto):
        self._flush_text()
        self.protos.append(proto)

    def _instruction(self, s: str, text: str, n: int):
        parts = s.split(None, 1)
        op = parts[0].lower()
        ops = split_operands(parts[1]) if len(parts) > 1 else []
        protos = self._expand(op, ops, n)
        for i, p in enumerate(protos):
            p.line = n
            p.text = text if len(protos) == 1 else f"{text}  [{i + 1}/{len(protos)}]"
            self._emit(p)

    def _expand(self, op: str, ops: list[str], n: int) -> list[Proto]:
        """Traduce una linea a una o mas instrucciones reales."""
        R = lambda i: parse_reg(ops[i], n)
        I = lambda i, kind="pcrel": parse_imm(ops[i], n, kind)

        def need(k: int):
            if len(ops) != k:
                raise ParseError(n, f"{op} espera {k} operandos, recibio {len(ops)}")

        # pseudoinstrucciones
        if op == "nop":
            need(0); return [Proto("addi")]
        if op == "li":
            need(2)
            v = parse_int(ops[1])
            if v is None:
                raise ParseError(n, f"li necesita un numero: {ops[1]!r}")
            return self._load_imm(R(0), v)
        if op == "la":
            need(2)
            sym = ops[1]
            return [Proto("lui", rd=R(0), imm=Ref("hi", sym)),
                    Proto("addi", rd=R(0), rs1=R(0), imm=Ref("lo", sym))]
        if op == "mv":
            need(2); return [Proto("addi", rd=R(0), rs1=R(1))]
        if op == "not":
            need(2); return [Proto("xori", rd=R(0), rs1=R(1), imm=-1)]
        if op == "neg":
            need(2); return [Proto("sub", rd=R(0), rs2=R(1))]
        if op == "seqz":
            need(2); return [Proto("sltiu", rd=R(0), rs1=R(1), imm=1)]
        if op == "snez":
            need(2); return [Proto("sltu", rd=R(0), rs2=R(1))]
        if op == "sltz":
            need(2); return [Proto("slt", rd=R(0), rs1=R(1))]
        if op == "sgtz":
            need(2); return [Proto("slt", rd=R(0), rs2=R(1))]
        # saltos contra cero
        zero_br = {"beqz": ("beq", False), "bnez": ("bne", False),
                   "bltz": ("blt", False), "bgez": ("bge", False),
                   "blez": ("bge", True), "bgtz": ("blt", True)}
        if op in zero_br:
            need(2)
            real, swap = zero_br[op]
            rs1, rs2 = (0, R(0)) if swap else (R(0), 0)
            return [Proto(real, rs1=rs1, rs2=rs2, imm=I(1))]
        # saltos con operandos invertidos: bgt a,b == blt b,a
        swapped = {"bgt": "blt", "ble": "bge", "bgtu": "bltu", "bleu": "bgeu"}
        if op in swapped:
            need(3); return [Proto(swapped[op], rs1=R(1), rs2=R(0), imm=I(2))]
        if op == "j":
            need(1); return [Proto("jal", imm=I(0))]
        if op == "jr":
            need(1); return [Proto("jalr", rs1=R(0))]
        if op == "ret":
            need(0); return [Proto("jalr", rs1=1)]
        if op == "call":
            need(1); return [Proto("jal", rd=1, imm=I(0))]
        if op == "tail":
            need(1); return [Proto("jal", imm=I(0))]

        # instrucciones reales
        if op not in FORMATS:
            raise ParseError(n, f"instruccion no soportada: {op!r}")
        fmt = FORMATS[op]

        if op == "jal": # jal etiqueta  |  jal rd, etiqueta
            if len(ops) == 1:
                return [Proto("jal", rd=1, imm=I(0))]
            need(2); return [Proto("jal", rd=R(0), imm=I(1))]
        if op == "jalr":  # jalr rs | jalr rd, imm(rs1) | jalr rd, rs1, imm
            if len(ops) == 1:
                return [Proto("jalr", rd=1, rs1=R(0))]
            if len(ops) == 2:
                imm, rs1 = self._memop(ops[1], n)
                return [Proto("jalr", rd=R(0), rs1=rs1, imm=imm)]
            need(3); return [Proto("jalr", rd=R(0), rs1=R(1), imm=I(2, "abs"))]
        if fmt is Fmt.R:
            need(3); return [Proto(op, rd=R(0), rs1=R(1), rs2=R(2))]
        if op in ("lb", "lh", "lw", "lbu", "lhu"):
            need(2)
            imm, rs1 = self._memop(ops[1], n)
            return [Proto(op, rd=R(0), rs1=rs1, imm=imm)]
        if fmt is Fmt.I:
            need(3); return [Proto(op, rd=R(0), rs1=R(1), imm=I(2, "abs"))]
        if fmt is Fmt.S:
            need(2)
            imm, rs1 = self._memop(ops[1], n)
            return [Proto(op, rs1=rs1, rs2=R(0), imm=imm)]
        if fmt is Fmt.B:
            need(3); return [Proto(op, rs1=R(0), rs2=R(1), imm=I(2))]
        if fmt is Fmt.U:
            need(2); return [Proto(op, rd=R(0), imm=I(1, "abs"))]
        if fmt is Fmt.SYS:
            need(0); return [Proto(op)]
        raise ParseError(n, f"formato no manejado: {op}")

    def _memop(self, tok: str, n: int) -> tuple[int | Ref, int]:
        """'12(sp)' -> (12, 2).  '%lo(x)(a0)' -> (Ref('lo','x'), 10)."""
        m = RE_MEMOP.match(tok.strip())
        if not m:
            raise ParseError(n, f"se esperaba imm(registro): {tok!r}")
        imm_s = m.group(1).strip() or "0"
        return parse_imm(imm_s, n, "abs"), parse_reg(m.group(2), n)

    @staticmethod
    def _load_imm(rd: int, v: int) -> list[Proto]:
        """li: 1 instruccion si cabe en 12 bits, si no lui (+ addi)."""
        v = s32(u32(v))
        if fits_signed(v, 12):
            return [Proto("addi", rd=rd, imm=v)]
        out = [Proto("lui", rd=rd, imm=hi20(v))]
        if lo12(v) != 0:
            out.append(Proto("addi", rd=rd, rs1=rd, imm=lo12(v)))
        return out

    # pasada 2

    def _addr_of(self, ref: Ref, line: int) -> int:
        if ref.sym in self.data_labels:
            return self.data_labels[ref.sym] + ref.addend
        if ref.sym in self.text_labels:
            return self.text_labels[ref.sym] + ref.addend
        raise ParseError(line, f"etiqueta no definida: {ref.sym}")

    def _resolve(self) -> Program:
        instrs = []
        for i, p in enumerate(self.protos):
            imm = p.imm
            if isinstance(imm, Ref):
                if imm.kind == "pcrel":
                    if imm.sym not in self.text_labels:
                        raise ParseError(p.line, f"salto a etiqueta no definida: {imm.sym}")
                    imm = self.text_labels[imm.sym] + imm.addend - 4 * i
                elif imm.kind == "hi":
                    imm = hi20(self._addr_of(imm, p.line))
                elif imm.kind == "lo":
                    imm = lo12(self._addr_of(imm, p.line))
                else:   # "abs": una etiqueta usada como numero
                    imm = self._addr_of(imm, p.line)
            self._check_range(p.op, imm, p.line)
            instrs.append(Instr(p.op, p.rd, p.rs1, p.rs2, imm, p.text, p.line))

        for addr, size, ref, line in self.data_fixups:
            v = self._addr_of(ref, line) & ((1 << 8 * size) - 1)
            self.data[addr:addr + size] = v.to_bytes(size, "little")

        entry = self.text_labels.get("main", 0)
        return Program(instrs, bytes(self.data), dict(self.text_labels),
                       dict(self.data_labels), entry)

    @staticmethod
    def _check_range(op: str, imm: int, line: int):
        fmt = FORMATS[op]
        if op in ("slli", "srli", "srai"):
            ok = 0 <= imm <= 31
        elif fmt in (Fmt.I, Fmt.S):
            ok = fits_signed(imm, 12)
        elif fmt is Fmt.B:
            ok = fits_signed(imm, 13) and imm % 2 == 0
        elif fmt is Fmt.J:
            ok = fits_signed(imm, 21) and imm % 2 == 0
        elif fmt is Fmt.U:
            ok = 0 <= imm <= 0xFFFFF or fits_signed(imm, 20)
        else:
            ok = True
        if not ok:
            raise ParseError(line, f"inmediato fuera de rango para {op}: {imm}")


def parse(source: str) -> Program:
    """Punto de entrada: texto de ensamblador -> Program."""
    return Parser().parse(source)


def parse_file(path: str) -> Program:
    with open(path, encoding="utf-8") as f:
        return parse(f.read())
