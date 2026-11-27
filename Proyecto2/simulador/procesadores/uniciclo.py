"""Procesador uniciclo"""

from ..core import latencias as L
from ..core.instr import Instr, Fmt
from ..core.isa import execute, mem_access, wb_value
from .base import Processor, CycleInfo, Mod

# Modulos que usa toda instruccion
ALWAYS = {Mod.PC, Mod.IMEM, Mod.CONTROL, Mod.PC_PLUS4, Mod.PC_MUX}


def active_modules(instr: Instr) -> set[Mod]:
    """Modulos del datapath uniciclo que usa cada tipo de instruccion."""
    m = set(ALWAYS)
    if instr.reads_rs1 or instr.reads_rs2:
        m.add(Mod.RF_READ)
    if instr.fmt is not Fmt.R and instr.fmt is not Fmt.SYS:
        m.add(Mod.EXTEND) # todos los formatos con inmediato
    if instr.fmt in (Fmt.I, Fmt.S):
        m |= {Mod.SRCB_MUX, Mod.ALU} # ALU con el inmediato
    if instr.fmt is Fmt.R:
        m |= {Mod.SRCB_MUX, Mod.ALU} # ALU con rs2
    if instr.fmt is Fmt.B:
        m |= {Mod.SRCB_MUX, Mod.ALU, Mod.PC_TARGET} # ALU compara, sumador calcula destino
    if instr.op in ("jal", "auipc"):
        m.add(Mod.PC_TARGET) # PC + imm
    if instr.is_load or instr.is_store:
        m.add(Mod.DMEM)
    if instr.writes_rd:
        m |= {Mod.RESULT_MUX, Mod.RF_WRITE}
    return m


class Uniciclo(Processor):
    name = "Uniciclo"
    STAGE = "Uniciclo" # una sola etapa: la instruccion completa

    @property
    def period_ps(self) -> int:
        """Camino critico de lw (Harris & Harris, ec. del periodo uniciclo):
        PC -> memoria de instrucciones -> (lectura de registros  ||
        decodificar + extender + mux de ALUSrc) -> ALU -> memoria de datos
        -> mux de resultado -> setup del banco de registros.
        Leer registros y extender ocurren en paralelo: cuenta el mas lento.
        """
        return (L.T_PCQ + L.T_MEM
                + max(L.T_RF_READ, L.T_DEC + L.T_EXT + L.T_MUX)
                + L.T_ALU + L.T_MEM + L.T_MUX + L.T_RF_SETUP)

    def step(self) -> CycleInfo:
        s = self.state
        if self.halted:
            return CycleInfo(self.cycle, {self.STAGE: None}, halted=True)

        instr = s.fetch(s.pc)
        if instr is None:
            # El PC se salio del programa (ret de main): termina sin gastar ciclo.
            self.halted = True
            return CycleInfo(self.cycle, {self.STAGE: None},
                             events=["fin del programa"], halted=True)

        self.cycle += 1
        events: list[str] = []

        # Toda la instruccion ocurre en este mismo ciclo.
        a, b = s.regs.read(instr.rs1), s.regs.read(instr.rs2)
        ex = execute(instr, a, b, s.pc)
        loaded = mem_access(instr, ex, s.mem)
        if instr.writes_rd:
            s.regs.write(instr.rd, wb_value(instr, ex, loaded))

        if instr.fmt is Fmt.SYS and self._syscall(instr, events):
            self.halted = True

        if ex.taken:
            events.append(f"salto a 0x{ex.target:08X}")
            s.pc = ex.target
        else:
            s.pc = s.pc + 4

        self.retired += 1
        return CycleInfo(self.cycle, {self.STAGE: instr},
                         active_modules(instr), events, self.halted)
