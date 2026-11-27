"""Procesador segmentado con unidad de riesgos y adelantamiento.

Forwarding: en EX, si el operando lo esta produciendo una instruccion
que va adelante (en MEM o en WB), se toma de ahi en vez del valor viejo
que se leyo del banco en ID.
    Prioridad 1: EX/MEM (el dato mas reciente)
    Prioridad 2: MEM/WB
    Si no:       el valor leido en ID

El unico caso que el forwarding no resuelve es load-use: el dato de un
lw sale de memoria al final de MEM, demasiado tarde para la instruccion
que viene justo despues. Ahi la unidad de riesgos mete 1 stall.
"""

from ..core import latencias as L
from ..core.instr import Instr
from ..core.isa import wb_value
from .segmentado_base import Segmentado, depende_de


class SegmentadoForwarding(Segmentado):
    name = "Segmentado (forwarding)"

    @property
    def period_ps(self) -> int:
        """El ciclo lo fija la etapa mas lenta (Harris & Harris, cap. 7).
        EX con forwarding: el libro cuenta 4 muxes en el camino critico
        (uno de ellos es el mux de forwarding).
        """
        t_if = L.T_PCQ + L.T_MEM + L.T_SETUP
        t_id = 2 * (L.T_RF_READ + L.T_SETUP)
        t_ex = L.T_PCQ + 4 * L.T_MUX + L.T_ALU + L.T_ANDOR + L.T_SETUP
        t_mem = L.T_PCQ + L.T_MEM + L.T_SETUP
        t_wb = 2 * (L.T_PCQ + L.T_MUX + L.T_RF_SETUP)
        return max(t_if, t_id, t_ex, t_mem, t_wb)

    @property
    def tipo_stall(self) -> str:
        return "load-use"

    def hay_stall(self, instr_id: Instr) -> str | None:
        # Solo load-use: un load en EX cuyo destino lee la instruccion en ID.
        prod = self.id_ex.instr
        if prod is not None and prod.is_load and prod.writes_rd:
            if depende_de(instr_id, prod.rd):
                return f"load-use: {instr_id} espera x{prod.rd} de '{prod}'"
        return None

    def forward(self, reg: int, valor_id: int, nombre: str,
                events: list[str], hazards: set[str]) -> int:
        """Mux de forwarding de un operando de la ALU.

        reg:      registro fuente (rs1 o rs2)
        valor_id: valor que se leyo del banco en ID
        nombre:   "A" o "B", para el mensaje de la GUI
        """
        if reg == 0:
            return valor_id                 # x0 siempre vale 0

        # Prioridad 1: instruccion en MEM (registro EX/MEM)
        prod = self.ex_mem.instr
        if prod is not None and prod.writes_rd and prod.rd == reg and not prod.is_load:
            events.append(f"forward EX/MEM -> {nombre}: x{reg} de '{prod}'")
            hazards.add("forwarding")
            return self.ex_mem.ex.alu

        # Prioridad 2: instruccion en WB (registro MEM/WB)
        prod = self.mem_wb.instr
        if prod is not None and prod.writes_rd and prod.rd == reg:
            events.append(f"forward MEM/WB -> {nombre}: x{reg} de '{prod}'")
            hazards.add("forwarding")
            return wb_value(prod, self.mem_wb.ex, self.mem_wb.loaded)

        # Sin dependencia: el valor del banco esta bien
        return valor_id

    def operandos_ex(self, events, hazards) -> tuple[int, int]:
        instr = self.id_ex.instr
        a, b = self.id_ex.a, self.id_ex.b
        if instr.reads_rs1:
            a = self.forward(instr.rs1, a, "A", events, hazards)
        if instr.reads_rs2:
            b = self.forward(instr.rs2, b, "B", events, hazards)
        return a, b
