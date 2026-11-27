"""Procesador segmentado de 5 etapas (IF, ID, EX, MEM, WB).

Parte comun de las dos versiones segmentadas:
    segmentado_stalls.py      riesgos de datos resueltos solo con stalls
    segmentado_forwarding.py  unidad de riesgos + adelantamiento

Cada version implementa unicamente:
    period_ps        duracion del ciclo
    hay_stall()      si la instruccion en ID debe esperar
    operandos_ex()   de donde salen a y b en EX (banco o forwarding)

Decisiones de diseno (Harris & Harris, cap. 7):
  - Los saltos se resuelven en EX. Se predice "no tomado": si el salto
    se toma, se vacian IF/ID e ID/EX (flush, 2 burbujas).
  - El banco de registros escribe en la primera mitad del ciclo y lee en
    la segunda. Para modelarlo, step() hace las etapas al reves
    (WB primero, IF de ultimo): asi ID ya ve lo que WB escribio.
  - ecall se atiende en WB: para entonces todas las instrucciones
    anteriores ya escribieron a7.
"""

from abc import abstractmethod
from dataclasses import dataclass, field

from ..core.instr import Instr, Fmt
from ..core.isa import ExResult, execute, mem_access, wb_value
from ..core.program import Program
from .base import Processor, CycleInfo, Mod
from .uniciclo import active_modules


ETAPAS = ("IF", "ID", "EX", "MEM", "WB")

# Modulos del datapath que pertenecen a cada etapa.
# Se cruzan con active_modules() del uniciclo para no repetir esa logica.
MODULOS_ETAPA = {
    "IF":  {Mod.PC, Mod.IMEM, Mod.PC_PLUS4, Mod.PC_MUX},
    "ID":  {Mod.CONTROL, Mod.RF_READ, Mod.EXTEND},
    "EX":  {Mod.SRCB_MUX, Mod.ALU, Mod.PC_TARGET},
    "MEM": {Mod.DMEM},
    "WB":  {Mod.RESULT_MUX, Mod.RF_WRITE},
}


# Registros de pipeline. instr = None significa burbuja.

@dataclass
class IFID:
    instr: Instr | None = None
    pc: int = 0


@dataclass
class IDEX:
    instr: Instr | None = None
    pc: int = 0
    a: int = 0          # valor de rs1 leido del banco en ID
    b: int = 0          # valor de rs2 leido del banco en ID


@dataclass
class EXMEM:
    instr: Instr | None = None
    ex: ExResult | None = None


@dataclass
class MEMWB:
    instr: Instr | None = None
    ex: ExResult | None = None
    loaded: int | None = None   # dato leido de memoria (solo cargas)


@dataclass
class PipeCycleInfo(CycleInfo):
    """CycleInfo con lo que necesita la GUI del segmentado.

    hazards: tipos de riesgo que hubo en este ciclo, para el modo
             "correr hasta encontrar un riesgo". Valores posibles:
             "datos" (stall), "load-use" (stall), "control" (flush),
             "forwarding".
    pc:      PC al final del ciclo.
    """
    hazards: set[str] = field(default_factory=set)
    pc: int = 0


def depende_de(instr: Instr, rd: int) -> bool:
    """True si instr lee el registro rd (x0 nunca genera dependencia)."""
    if rd == 0:
        return False
    if instr.reads_rs1 and instr.rs1 == rd:
        return True
    if instr.reads_rs2 and instr.rs2 == rd:
        return True
    return False


class Segmentado(Processor):
    name = "Segmentado"

    def __init__(self, program: Program, mem_size: int = 4096):
        super().__init__(program, mem_size)
        # registros de pipeline, todos empiezan como burbuja
        self.if_id = IFID()
        self.id_ex = IDEX()
        self.ex_mem = EXMEM()
        self.mem_wb = MEMWB()
        # contadores extra para las metricas
        self.stalls = 0
        self.flushes = 0

    # lo que implementa cada version

    @abstractmethod
    def hay_stall(self, instr_id: Instr) -> str | None:
        """Unidad de deteccion de riesgos.
        Devuelve None si la instruccion en ID puede avanzar, o un texto
        que explica el stall (se muestra en la GUI).
        """

    @abstractmethod
    def operandos_ex(self, events: list[str], hazards: set[str]) -> tuple[int, int]:
        """Valores (a, b) que entran a la ALU en EX."""

    @property
    def tipo_stall(self) -> str:
        """Nombre del riesgo de datos para el campo hazards."""
        return "datos"

    # utilidades

    def pipeline_vacio(self) -> bool:
        return (self.if_id.instr is None and self.id_ex.instr is None
                and self.ex_mem.instr is None and self.mem_wb.instr is None)

    def etapas_actuales(self, instr_if: Instr | None) -> dict[str, Instr | None]:
        """Que instruccion hay en cada etapa durante este ciclo."""
        return {
            "IF": instr_if,
            "ID": self.if_id.instr,
            "EX": self.id_ex.instr,
            "MEM": self.ex_mem.instr,
            "WB": self.mem_wb.instr,
        }

    @staticmethod
    def modulos_activos(etapas: dict[str, Instr | None]) -> set[Mod]:
        """Modulos encendidos: los de cada etapa que usa su instruccion."""
        activos = set()
        for etapa, instr in etapas.items():
            if instr is not None:
                activos |= active_modules(instr) & MODULOS_ETAPA[etapa]
        return activos

    def metrics(self) -> dict[str, float | int]:
        m = super().metrics()
        m["stalls"] = self.stalls
        m["flushes"] = self.flushes
        return m

    # un ciclo de reloj

    def step(self) -> PipeCycleInfo:
        s = self.state

        if self.halted:
            return PipeCycleInfo(self.cycle, self.etapas_actuales(None),
                                 halted=True, pc=s.pc)

        # Instruccion que entraria a IF en este ciclo (None si el PC
        # se salio del programa).
        instr_if = s.fetch(s.pc)

        # Fin del programa: no hay nada que buscar y el pipeline ya se vacio.
        if instr_if is None and self.pipeline_vacio():
            self.halted = True
            return PipeCycleInfo(self.cycle, self.etapas_actuales(None),
                                 events=["fin del programa"], halted=True, pc=s.pc)

        self.cycle += 1
        events: list[str] = []
        hazards: set[str] = set()
        etapas = self.etapas_actuales(instr_if)
        activos = self.modulos_activos(etapas)

        # 1. WB: escribe el banco de registros

        instr_wb = self.mem_wb.instr
        if instr_wb is not None:
            if instr_wb.writes_rd:
                valor = wb_value(instr_wb, self.mem_wb.ex, self.mem_wb.loaded)
                s.regs.write(instr_wb.rd, valor)
            self.retired += 1

            if instr_wb.fmt is Fmt.SYS and self._syscall(instr_wb, events):
                # Termina aqui: las instrucciones mas jovenes (MEM, EX, ID, IF)
                # se descartan sin ejecutarse.
                self.halted = True
                return PipeCycleInfo(self.cycle, etapas, activos, events,
                                     halted=True, hazards=hazards, pc=s.pc)

        # 2. MEM: carga o store

        instr_mem = self.ex_mem.instr
        loaded = None
        if instr_mem is not None:
            loaded = mem_access(instr_mem, self.ex_mem.ex, s.mem)

        # 3. EX: ALU y decision de saltos

        instr_ex = self.id_ex.instr
        ex = None
        flush = False
        if instr_ex is not None:
            a, b = self.operandos_ex(events, hazards)
            ex = execute(instr_ex, a, b, self.id_ex.pc)
            if ex.taken:
                flush = True

        # 4. ID: unidad de riesgos y lectura del banco

        instr_id = self.if_id.instr
        stall = False
        a_id, b_id = 0, 0
        if instr_id is not None:
            motivo = self.hay_stall(instr_id)
            if motivo is not None and not flush:
                # Si hay flush la instruccion en ID se descarta igual,
                # asi que el stall no importa.
                stall = True
                events.append(f"stall: {motivo}")
                hazards.add(self.tipo_stall)
                self.stalls += 1
            # Se lee despues de WB: ve el valor que WB acaba de escribir.
            a_id = s.regs.read(instr_id.rs1)
            b_id = s.regs.read(instr_id.rs2)

        # 5. IF ya se hizo arriba (instr_if)

        # 6. Flanco de reloj: calcular los registros nuevos

        # MEM/WB y EX/MEM siempre avanzan
        self.mem_wb = MEMWB(instr_mem, self.ex_mem.ex, loaded)
        self.ex_mem = EXMEM(instr_ex, ex)

        if flush:
            # Salto tomado: lo que estaba en IF e ID era el camino equivocado.
            events.append(f"flush: {instr_ex} tomado, salto a 0x{ex.target:08X}")
            hazards.add("control")
            self.flushes += 1
            self.id_ex = IDEX()
            self.if_id = IFID()
            s.pc = ex.target

        elif stall:
            # ID se queda con la misma instruccion, PC no avanza,
            # y a EX entra una burbuja.
            self.id_ex = IDEX()
            # self.if_id y s.pc no cambian

        else:
            # Avance normal
            self.id_ex = IDEX(instr_id, self.if_id.pc, a_id, b_id)
            self.if_id = IFID(instr_if, s.pc)
            if instr_if is not None:
                s.pc = s.pc + 4
            # si instr_if es None el PC se queda quieto y entra una burbuja

        return PipeCycleInfo(self.cycle, etapas, activos, events,
                             halted=False, hazards=hazards, pc=s.pc)
