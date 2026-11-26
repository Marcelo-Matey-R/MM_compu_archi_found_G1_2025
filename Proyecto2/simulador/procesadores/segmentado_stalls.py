"""Procesador segmentado sin adelantamiento: los riesgos de datos se
resuelven solo con stalls.

La unidad de riesgos detiene la instruccion en ID mientras alguna
instruccion en EX o en MEM vaya a escribir un registro que ella lee.
Cuando el productor llega a WB ya no hace falta esperar, porque el banco
escribe en la primera mitad del ciclo y lee en la segunda.

Costo: 2 stalls por cada dependencia con la instruccion anterior.
"""

from ..core import latencias as L
from ..core.instr import Instr
from .segmentado_base import Segmentado, depende_de


class SegmentadoStalls(Segmentado):
    name = "Segmentado (stalls)"

    @property
    def period_ps(self) -> int:
        """El ciclo lo fija la etapa mas lenta (Harris & Harris, cap. 7).
        EX sin forwarding: un mux menos en el camino critico que con
        forwarding (los muxes de forwarding de A y B van en paralelo).
        """
        t_if = L.T_PCQ + L.T_MEM + L.T_SETUP
        t_id = 2 * (L.T_RF_READ + L.T_SETUP)
        t_ex = L.T_PCQ + 3 * L.T_MUX + L.T_ALU + L.T_ANDOR + L.T_SETUP
        t_mem = L.T_PCQ + L.T_MEM + L.T_SETUP
        t_wb = 2 * (L.T_PCQ + L.T_MUX + L.T_RF_SETUP)
        return max(t_if, t_id, t_ex, t_mem, t_wb)

    def hay_stall(self, instr_id: Instr) -> str | None:
        # productores que todavia no han escrito el banco
        productores = (("EX", self.id_ex.instr), ("MEM", self.ex_mem.instr))
        for etapa, prod in productores:
            if prod is None or not prod.writes_rd:
                continue
            if depende_de(instr_id, prod.rd):
                return f"{instr_id} espera x{prod.rd} de '{prod}' (en {etapa})"
        return None

    def operandos_ex(self, events, hazards) -> tuple[int, int]:
        # Sin forwarding: los valores son los que se leyeron del banco en ID.
        return self.id_ex.a, self.id_ex.b
