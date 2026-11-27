from dataclasses import dataclass
from enum import Enum


class Fmt(Enum):
    """Formato de codificacion RISC-V (green card)."""
    R = "R"   # add, sub, and, mul...       rd, rs1, rs2
    I = "I"   # addi, lw, jalr, slli...     rd, rs1, imm
    S = "S"   # sw, sh, sb                  rs1, rs2, imm
    B = "B"   # beq, bne, blt...            rs1, rs2, imm (offset)
    U = "U"   # lui, auipc                  rd, imm
    J = "J"   # jal                         rd, imm (offset)
    SYS = "SYS"  # ecall, ebreak


# Formato de cada instruccion soportada..
FORMATS: dict[str, Fmt] = {
    # R
    **{op: Fmt.R for op in ("add", "sub", "sll", "slt", "sltu", "xor",
                             "srl", "sra", "or", "and",
                             "mul", "mulh", "mulhsu", "mulhu",
                             "div", "divu", "rem", "remu")},
    # I (aritmeticas, cargas y jalr)
    **{op: Fmt.I for op in ("addi", "slti", "sltiu", "xori", "ori", "andi",
                             "slli", "srli", "srai",
                             "lb", "lh", "lw", "lbu", "lhu", "jalr")},
    # S
    **{op: Fmt.S for op in ("sb", "sh", "sw")},
    # B
    **{op: Fmt.B for op in ("beq", "bne", "blt", "bge", "bltu", "bgeu")},
    # U y J
    "lui": Fmt.U, "auipc": Fmt.U, "jal": Fmt.J,
    # sistema
    "ecall": Fmt.SYS, "ebreak": Fmt.SYS,
}

LOADS = {"lb", "lh", "lw", "lbu", "lhu"}
STORES = {"sb", "sh", "sw"}


@dataclass(frozen=True)
class Instr:
    op: str          # instruccion real: "add", "lw", "beq"...
    rd: int = 0      # registro destino 0..31
    rs1: int = 0     # registro fuente 1
    rs2: int = 0     # registro fuente 2
    imm: int = 0     # inmediato con signo; en saltos, offset en bytes
    text: str = ""   # linea original, para mostrarla en la GUI
    line: int = 0    # numero de linea en el archivo fuente (0 = desconocida)

    def __post_init__(self):
        if self.op not in FORMATS:
            raise ValueError(f"instruccion no soportada: {self.op!r}")
        for name in ("rd", "rs1", "rs2"):
            r = getattr(self, name)
            if not 0 <= r <= 31:
                raise ValueError(f"{name}={r} fuera de rango en {self.op}")

    @property
    def fmt(self) -> Fmt:
        return FORMATS[self.op]

    # --- Preguntas que hacen los procesadores, la GUI y la hazard unit ---

    @property
    def writes_rd(self) -> bool:
        """True si escribe el banco de registros (S, B y SYS no escriben).
        Escribir en x0 no cuenta.
        """
        return self.fmt in (Fmt.R, Fmt.I, Fmt.U, Fmt.J) and self.rd != 0

    @property
    def reads_rs1(self) -> bool:
        return self.fmt in (Fmt.R, Fmt.I, Fmt.S, Fmt.B)

    @property
    def reads_rs2(self) -> bool:
        return self.fmt in (Fmt.R, Fmt.S, Fmt.B)

    @property
    def is_load(self) -> bool:
        return self.op in LOADS

    @property
    def is_store(self) -> bool:
        return self.op in STORES

    @property
    def is_branch(self) -> bool:
        return self.fmt is Fmt.B

    @property
    def is_jump(self) -> bool:
        return self.op in ("jal", "jalr")

    def __str__(self) -> str:
        return self.text or self.op