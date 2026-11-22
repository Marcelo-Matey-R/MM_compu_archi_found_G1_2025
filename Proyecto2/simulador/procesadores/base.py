"""Interfaz comun de los cuatro procesadores.
La GUI solo conoce esta interfaz: puede manejar dos procesadores cualesquiera
sin saber cuales son. Cada procesador implementa unicamente:
    period_ps   cuanto dura su ciclo (a partir de core.latencias)
    step()      que pasa en un ciclo
Todo lo demas (contadores, run, metricas) es igual para los cuatro.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum

from ..core.instr import Instr
from ..core.program import Program
from ..core.state import ArchState


class Mod(Enum):
    """Modulos de hardware que la GUI puede iluminar."""
    PC = "PC"
    PC_PLUS4 = "Sumador PC+4"
    PC_TARGET = "Sumador PC+imm"
    PC_MUX = "Mux PC"
    IMEM = "Memoria de instrucciones"
    CONTROL = "Unidad de control"
    RF_READ = "Banco de registros (lectura)"
    EXTEND = "Extension de inmediato"
    SRCB_MUX = "Mux entrada B de la ALU"
    ALU = "ALU"
    DMEM = "Memoria de datos"
    RESULT_MUX = "Mux de resultado"
    RF_WRITE = "Banco de registros (escritura)"


@dataclass
class CycleInfo:
    """Lo que paso en un ciclo."""
    cycle: int # numero de ciclo (1, 2, 3...)
    stages: dict[str, Instr | None] # etapa -> instruccion
    active: set[Mod] = field(default_factory=set)
    events: list[str] = field(default_factory=list)
    halted: bool = False


class Processor(ABC):
    name: str = "procesador"

    def __init__(self, program: Program, mem_size: int = 4096):
        self.state = ArchState(program, mem_size)
        self.cycle = 0 # ciclos ejecutados
        self.retired = 0  # instrucciones terminadas
        self.halted = False

    # lo que implementa cada procesador

    @property
    @abstractmethod
    def period_ps(self) -> int:
        """Duracion de un ciclo de reloj en picosegundos."""

    @abstractmethod
    def step(self) -> CycleInfo:
        """Avanza exactamente un ciclo de reloj."""

    # comun a todos

    @property
    def time_ps(self) -> int:
        """Tiempo desde la primera instruccion."""
        return self.cycle * self.period_ps

    def run(self, max_cycles: int = 1_000_000) -> CycleInfo | None:
        """Ejecucion completa. Devuelve el ultimo CycleInfo."""
        info = None
        while not self.halted:
            if self.cycle >= max_cycles:
                raise RuntimeError(f"{self.name}: se supero el limite de {max_cycles} ciclos")
            info = self.step()
        return info

    def metrics(self) -> dict[str, float | int]:
        cpi = self.cycle / self.retired if self.retired else 0.0
        return {
            "ciclos": self.cycle,
            "instrucciones": self.retired,
            "CPI": round(cpi, 3),
            "periodo_ps": self.period_ps,
            "tiempo_ps": self.time_ps,
        }

    # utilidades para las subclases-

    def _syscall(self, instr: Instr, events: list[str]) -> bool:
        """Maneja ecall/ebreak. Devuelve True si el programa debe terminar.
        El numero de llamada va en a7; a7 = 10 es 'exit'.
        """
        if instr.op == "ebreak":
            events.append("ebreak: fin del programa")
            return True
        a7 = self.state.regs.read(17)
        if a7 == 10:
            events.append("ecall exit: fin del programa")
            return True
        events.append(f"ecall con a7={a7}: llamada no soportada, se ignora")
        return False
