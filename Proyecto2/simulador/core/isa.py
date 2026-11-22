"""Semantica de RV32IM.

Se separa en tres funciones, una por cada parte del datapath:
    execute(instr, a, b, pc) -> ExResult    etapa EX  (ALU y saltos)
    mem_access(instr, ex, mem) -> int|None  etapa MEM (cargas y stores)
    wb_value(instr, ex, loaded) -> int      etapa WB  (mux ResultSrc)
Ninguna lee el banco de registros: reciben los
operandos ya resueltos, para que el forwarding pueda darles el valor
adelantado en lugar del que esta en el banco.
"""

from dataclasses import dataclass

from .bits import u32, s32, MASK32
from .instr import Instr, Fmt
from .state import DataMemory


@dataclass(frozen=True)
class ExResult:
    alu: int            # resultado de la ALU; en lw/sw es la direccion;
                        # en jal/jalr es pc+4 (lo que se guarda en rd)
    taken: bool         # True si el PC no sigue en pc+4
    target: int         # nuevo PC si taken
    store_val: int = 0  # dato a escribir en memoria (sb/sh/sw)


def _div(a: int, b: int) -> int:
    x, y = s32(a), s32(b)
    if y == 0:
        return MASK32                       # division entre cero -> -1
    if x == -2**31 and y == -1:
        return u32(x)                       # desbordamiento -> -2^31
    q = abs(x) // abs(y)                    # truncar hacia cero, no hacia -inf
    return u32(q if (x < 0) == (y < 0) else -q)


def _rem(a: int, b: int) -> int:
    x, y = s32(a), s32(b)
    if y == 0:
        return u32(x)                       # rem entre cero -> dividendo
    if x == -2**31 and y == -1:
        return 0
    r = abs(x) % abs(y)                     # el signo del resto es el del dividendo
    return u32(r if x >= 0 else -r)


def _divu(a: int, b: int) -> int:
    return MASK32 if b == 0 else a // b


def _remu(a: int, b: int) -> int:
    return a if b == 0 else a % b


ALU_OPS = {
    "add":  lambda a, b: a + b,
    "sub":  lambda a, b: a - b,
    "sll":  lambda a, b: a << (b & 0x1F),
    "slt":  lambda a, b: int(s32(a) < s32(b)),
    "sltu": lambda a, b: int(a < b),
    "xor":  lambda a, b: a ^ b,
    "srl":  lambda a, b: a >> (b & 0x1F),
    "sra":  lambda a, b: s32(a) >> (b & 0x1F),
    "or":   lambda a, b: a | b,
    "and":  lambda a, b: a & b,
    # extension M
    "mul":    lambda a, b: a * b,                         # 32 bits bajos
    "mulh":   lambda a, b: (s32(a) * s32(b)) >> 32,       # altos, con signo
    "mulhsu": lambda a, b: (s32(a) * b) >> 32,            # rs1 con signo, rs2 sin
    "mulhu":  lambda a, b: (a * b) >> 32,                 # altos, sin signo
    "div":  _div,
    "divu": _divu,
    "rem":  _rem,
    "remu": _remu,
}

# addi -> add, slti -> slt, ...
IMM_TO_ALU = {
    "addi": "add", "slti": "slt", "sltiu": "sltu", "xori": "xor",
    "ori": "or", "andi": "and", "slli": "sll", "srli": "srl", "srai": "sra",
}

BRANCH_COND = {
    "beq":  lambda a, b: a == b,
    "bne":  lambda a, b: a != b,
    "blt":  lambda a, b: s32(a) < s32(b),
    "bge":  lambda a, b: s32(a) >= s32(b),
    "bltu": lambda a, b: a < b,
    "bgeu": lambda a, b: a >= b,
}

# Cargas y stores
MEM_SIZE = {
    "lb": (1, True), "lh": (2, True), "lw": (4, True),
    "lbu": (1, False), "lhu": (2, False),
    "sb": (1, False), "sh": (2, False), "sw": (4, False),
}


# Etapa EX

def execute(instr: Instr, a: int, b: int, pc: int) -> ExResult:
    """Calcula la ALU y decide el salto.

    a = valor de rs1, b = valor de rs2.
    """
    op, imm = instr.op, instr.imm
    pc4 = u32(pc + 4)

    if op in ALU_OPS:                                   # R
        return ExResult(u32(ALU_OPS[op](a, b)), False, 0)

    if op in IMM_TO_ALU:                                # I aritmeticas
        return ExResult(u32(ALU_OPS[IMM_TO_ALU[op]](a, u32(imm))), False, 0)

    if instr.is_load:                                   # direccion efectiva
        return ExResult(u32(a + imm), False, 0)

    if instr.is_store:                                  # direccion + dato
        return ExResult(u32(a + imm), False, 0, store_val=b)

    if op in BRANCH_COND:                               # B
        taken = BRANCH_COND[op](a, b)
        return ExResult(0, taken, u32(pc + imm))

    if op == "jal":                                     # J
        return ExResult(pc4, True, u32(pc + imm))

    if op == "jalr":                                    # destino con bit 0 en 0
        return ExResult(pc4, True, u32(a + imm) & ~1 & MASK32)

    if op == "lui":                                     # U
        return ExResult(u32(imm << 12), False, 0)

    if op == "auipc":
        return ExResult(u32(pc + (imm << 12)), False, 0)

    if instr.fmt is Fmt.SYS:                            # ecall / ebreak:
        return ExResult(0, False, 0)                    # los maneja el procesador

    raise NotImplementedError(op)


# Etapa MEM

def mem_access(instr: Instr, ex: ExResult, mem: DataMemory) -> int | None:
    """Hace la carga o el store. Devuelve el valor leido, o None."""
    if instr.is_load:
        nbytes, signed = MEM_SIZE[instr.op]
        return mem.load(ex.alu, nbytes, signed)
    if instr.is_store:
        nbytes, _ = MEM_SIZE[instr.op]
        mem.store(ex.alu, ex.store_val, nbytes)
    return None


# Etapa WB

def wb_value(instr: Instr, ex: ExResult, loaded: int | None) -> int:
    """Mux ResultSrc: dato de memoria en cargas, resultado de la ALU en lo demas.
    Solo tiene sentido si instr.writes_rd es True.
    """
    return loaded if instr.is_load else ex.alu