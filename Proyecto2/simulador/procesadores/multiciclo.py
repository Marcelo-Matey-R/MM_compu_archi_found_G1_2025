"""Procesador multiciclo"""

from enum import Enum

from ..core import latencias as L
from ..core.instr import Instr, Fmt
from ..core.isa import ExResult, execute, mem_access, wb_value
from .base import Processor, CycleInfo, Mod


class Estado(Enum):
    FETCH = "S0 Fetch"
    DECODE = "S1 Decode"
    MEMADR = "S2 MemAdr"
    MEMREAD = "S3 MemRead"
    MEMWB = "S4 MemWB"
    MEMWRITE = "S5 MemWrite"
    EXEC_R = "S6 ExecuteR"
    ALUWB = "S7 ALUWB"
    EXEC_I = "S8 ExecuteI"
    JAL = "S9 JAL"
    BEQ = "S10 BEQ"
    # extensiones
    EXEC_U = "EXEC_U"
    JALR = "JALR"
    JALR_LINK = "JALR_LINK"
    SYS = "SYS"


# Estados en los que la ALU calcula con los operandos de la instruccion.
ESTADOS_EXEC = {Estado.MEMADR, Estado.EXEC_R, Estado.EXEC_I, Estado.EXEC_U,
                Estado.JAL, Estado.JALR, Estado.BEQ, Estado.SYS}


def estado_tras_decode(i: Instr) -> Estado:
    """Despacho de la FSM despues de Decode, segun la instruccion."""
    if i.is_load or i.is_store:
        return Estado.MEMADR
    if i.is_branch:
        return Estado.BEQ
    if i.op == "jal":
        return Estado.JAL
    if i.op == "jalr":
        return Estado.JALR
    if i.op in ("lui", "auipc"):
        return Estado.EXEC_U
    if i.fmt is Fmt.SYS:
        return Estado.SYS
    if i.fmt is Fmt.R:
        return Estado.EXEC_R
    return Estado.EXEC_I            # addi, slti, xori, slli...


def modulos_estado(estado: Estado, i: Instr, tomado: bool = False) -> set[Mod]:
    """Modulos del datapath de H&H que se encienden en un estado."""
    m = {Mod.CONTROL}               # la FSM siempre esta activa

    if estado is Estado.FETCH:
        # Instr <- Mem[PC]; PC <- PC+4 (por la ALU y el mux Result)
        m |= {Mod.PC, Mod.IMEM, Mod.SRCB_MUX, Mod.ALU, Mod.RESULT_MUX}

    elif estado is Estado.DECODE:
        # A, B <- RF; ImmExt; ALUOut <- OldPC + ImmExt (siempre, especulativo)
        m |= {Mod.SRCB_MUX, Mod.ALU}
        if i.reads_rs1 or i.reads_rs2:
            m.add(Mod.RF_READ)
        if i.fmt is not Fmt.R and i.fmt is not Fmt.SYS:
            m.add(Mod.EXTEND)

    elif estado in (Estado.MEMADR, Estado.EXEC_R, Estado.EXEC_I,
                    Estado.EXEC_U, Estado.JALR_LINK):
        m |= {Mod.SRCB_MUX, Mod.ALU}

    elif estado in (Estado.MEMREAD, Estado.MEMWRITE):
        m.add(Mod.DMEM)

    elif estado in (Estado.MEMWB, Estado.ALUWB):
        m |= {Mod.RESULT_MUX, Mod.RF_WRITE}

    elif estado in (Estado.JAL, Estado.JALR):
        # PC <- destino por el mux Result
        m |= {Mod.SRCB_MUX, Mod.ALU, Mod.RESULT_MUX, Mod.PC}

    elif estado is Estado.BEQ:
        m |= {Mod.SRCB_MUX, Mod.ALU}
        if tomado:
            m |= {Mod.RESULT_MUX, Mod.PC}

    # Estado.SYS: solo la unidad de control

    return m


class Multiciclo(Processor):
    name = "Multiciclo"
    STAGE = "Multiciclo"            # la GUI ve una sola "etapa": la instruccion

    def __init__(self, program, mem_size: int = 4096):
        super().__init__(program, mem_size)
        self.estado = Estado.FETCH
        # Registros internos del datapath
        self.ir: Instr | None = None        # Instr
        self.old_pc = 0                     # OldPC
        self.a = 0                          # A
        self.b = 0                          # B
        self.ex: ExResult | None = None     # ALUOut (+ decision de salto)
        self.loaded: int | None = None      # Data

    # ------------------------------------------------------------------
    @property
    def period_ps(self) -> int:
        """El ciclo lo fija el estado mas lento (Harris & Harris, cap. 7).
        Memorias separadas: no hay mux de direccion en Fetch ni en MEM.
        """
        # Fetch: PC -> IMEM, en paralelo con PC -> mux -> ALU -> mux Result -> PC
        t_fetch = L.T_PCQ + max(L.T_MEM, L.T_MUX + L.T_ALU + L.T_MUX) + L.T_SETUP
        # Decode: ImmExt (decodificar + extender) -> mux srcB -> ALU -> ALUOut.
        t_dec = L.T_PCQ + L.T_DEC + max(L.T_ALU, L.T_MEM) + 2*L.T_MUX + L.T_SETUP
        # Execute: mux -> ALU -> (AND-OR de PCSrc) -> mux Result -> PC
        t_ex = L.T_PCQ + L.T_MUX + L.T_ALU + L.T_ANDOR + L.T_MUX + L.T_SETUP
        t_mem = L.T_PCQ + L.T_MEM + L.T_SETUP
        t_wb = L.T_PCQ + L.T_MUX + L.T_RF_SETUP
        return max(t_fetch, t_dec, t_ex, t_mem, t_wb)

    # ------------------------------------------------------------------
    def _siguiente(self, estado: Estado) -> Estado | None:
        """Estado que sigue a 'estado'. None = la instruccion termino."""
        i = self.ir
        if estado is Estado.FETCH:
            return Estado.DECODE
        if estado is Estado.DECODE:
            return estado_tras_decode(i)
        if estado is Estado.MEMADR:
            return Estado.MEMREAD if i.is_load else Estado.MEMWRITE
        if estado is Estado.MEMREAD:
            return Estado.MEMWB
        if estado in (Estado.EXEC_R, Estado.EXEC_I, Estado.EXEC_U, Estado.JAL):
            return Estado.ALUWB
        if estado is Estado.JALR:
            return Estado.JALR_LINK
        if estado is Estado.JALR_LINK:
            return Estado.ALUWB
        # MEMWB, MEMWRITE, ALUWB, BEQ, SYS terminan la instruccion
        return None

    # ------------------------------------------------------------------
    def step(self) -> CycleInfo:
        s = self.state
        if self.halted:
            return CycleInfo(self.cycle, {self.STAGE: None}, halted=True)

        # Fin del programa: solo se detecta al inicio de una instruccion.
        if self.estado is Estado.FETCH and s.fetch(s.pc) is None:
            self.halted = True
            return CycleInfo(self.cycle, {self.STAGE: None}, events=["fin del programa"], halted=True)

        self.cycle += 1
        estado = self.estado
        events: list[str] = []

        if estado is Estado.FETCH:
            # Instr <- Mem[PC]; OldPC <- PC; PC <- PC+4 (la ALU hace la suma)
            self.ir = s.fetch(s.pc)
            self.old_pc = s.pc
            s.pc = s.pc + 4

        i = self.ir                        # instruccion en curso

        if estado is Estado.DECODE:
            # A, B <- RF[rs1], RF[rs2]. (ALUOut <- OldPC+imm
            self.a = s.regs.read(i.rs1)
            self.b = s.regs.read(i.rs2)

        elif estado in ESTADOS_EXEC:
            self.ex = execute(i, self.a, self.b, self.old_pc)
            if self.ex.taken:              # beq tomado, jal, jalr
                s.pc = self.ex.target
                events.append(f"PC <- 0x{self.ex.target:08X}")
            if estado is Estado.SYS and self._syscall(i, events):
                self.halted = True

        elif estado is Estado.MEMREAD:
            self.loaded = mem_access(i, self.ex, s.mem)

        elif estado is Estado.MEMWRITE:
            mem_access(i, self.ex, s.mem)

        elif estado in (Estado.MEMWB, Estado.ALUWB):
            # rd <- Data (load) o ALUOut (resto). Escribir x0 no tiene efecto.
            s.regs.write(i.rd, wb_value(i, self.ex, self.loaded))

        # Estado.JALR_LINK: ALUOut <- OldPC+4. execute() ya lo dejo en ex.alu.

        tomado = bool(self.ex and self.ex.taken)
        activos = modulos_estado(estado, i, tomado)
        events.insert(0, f"{estado.value}: {i}")

        # Transicion de la FSM
        sig = self._siguiente(estado)
        if sig is None:
            self.retired += 1
            self.estado = Estado.FETCH
            self.ex = None
            self.loaded = None
        else:
            self.estado = sig

        return CycleInfo(self.cycle, {self.STAGE: i}, activos, events, self.halted)