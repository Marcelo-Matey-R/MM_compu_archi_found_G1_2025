"""Estado arquitectonico: banco de registros, memoria de datos y programa.
Memoria de instrucciones y memoria dedatos separadas.
"""

from .bits import u32, sext, zext, hex32
from .instr import Instr
from .program import Program

REG_NAMES = (
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
)


class MemoryError_(Exception):
    """Acceso invalido a memoria."""


class RegisterFile:
    """32 registros de 32 bits. x0 siempre vale 0."""

    def __init__(self):
        self._r = [0] * 32

    def read(self, idx: int) -> int:
        return self._r[idx]

    def write(self, idx: int, value: int) -> None:
        if idx != 0:                    # escribir en x0 no tiene efecto
            self._r[idx] = u32(value)

    def as_list(self) -> list[int]:
        """Copia de los 32 valores, para la GUI o para comparar estados."""
        return list(self._r)


class DataMemory:
    """Memoria de datos direccionada por bytes, little-endian.

    Una palabra en la direccion A ocupa los bytes A, A+1, A+2, A+3, y el
    byte A es el menos significativo.
    """

    def __init__(self, size: int = 4096):
        self.size = size
        self._b = bytearray(size)

    def _check(self, addr: int, nbytes: int) -> None:
        if addr < 0 or addr + nbytes > self.size:
            raise MemoryError_(f"acceso fuera de rango: {hex32(addr)} ({nbytes} bytes)")
        if addr % nbytes != 0:
            raise MemoryError_(f"acceso desalineado: {hex32(addr)} ({nbytes} bytes)")

    def load(self, addr: int, nbytes: int, signed: bool) -> int:
        """Lee 1, 2 o 4 bytes y devuelve el valor extendido a 32 bits.

        lb: (1, True)  lbu: (1, False)  lh: (2, True)  lhu: (2, False)  lw: (4, ...)
        """
        addr = u32(addr)
        self._check(addr, nbytes)
        raw = int.from_bytes(self._b[addr:addr + nbytes], "little")
        bits = 8 * nbytes
        return sext(raw, bits) if signed else zext(raw, bits)

    def store(self, addr: int, value: int, nbytes: int) -> None:
        """Escribe los 'nbytes' bytes bajos de value (sb: 1, sh: 2, sw: 4)."""
        addr = u32(addr)
        self._check(addr, nbytes)
        value &= (1 << (8 * nbytes)) - 1
        self._b[addr:addr + nbytes] = value.to_bytes(nbytes, "little")

    def words(self, start: int = 0, end: int | None = None) -> list[tuple[int, int]]:
        """Lista de (direccion, palabra) para mostrar la memoria en la GUI."""
        end = self.size if end is None else end
        return [(a, int.from_bytes(self._b[a:a + 4], "little"))
                for a in range(start, end, 4)]

    def last_used(self) -> int:
        """Direccion del ultimo byte distinto de 0 (-1 si todo esta en 0).
        """
        for a in range(self.size - 1, -1, -1):
            if self._b[a]:
                return a
        return -1


class ArchState:
    """Todo el estado visible: PC, registros, memoria y programa."""

    def __init__(self, program: Program | list[Instr], mem_size: int = 4096):
        if isinstance(program, list): # comodidad para pruebas a mano
            program = Program(program)
        if len(program.data) > mem_size:
            raise MemoryError_(f"los datos ({len(program.data)} B) no caben en {mem_size} B")
        self.program = program
        self.regs = RegisterFile()
        self.mem = DataMemory(mem_size)
        self.mem._b[:len(program.data)] = program.data
        self.pc = program.entry
        # La pila crece hacia abajo desde el final de la memoria.
        # El codigo de clang usa sp desde la primera instruccion.
        self.regs.write(2, mem_size)
        # Cuando main haga ret, saltara al final del programa y terminara.
        self.regs.write(1, program.end_addr)

    def fetch(self, pc: int) -> Instr | None:
        """Instruccion en la direccion pc, o None si se sale del programa."""
        if pc % 4 != 0:
            raise MemoryError_(f"PC desalineado: {hex32(pc)}")
        i = pc // 4
        instrs = self.program.instrs
        return instrs[i] if 0 <= i < len(instrs) else None
