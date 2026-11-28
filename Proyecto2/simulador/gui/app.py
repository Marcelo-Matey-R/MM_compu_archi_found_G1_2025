"""GUI del simulador: dos procesadores lado a lado (solo libreria estandar).

Ejecutar desde Proyecto2:   python3 -m simulador.gui.app

Cubre el enunciado (Proyecto Grupal 2, seccion 1):
  4.  modulos de hardware iluminados segun el ciclo (canvas)
  5.  dos procesadores simultaneos, cada uno elegible entre los cuatro
      + instruccion en cada etapa del pipeline
  6.  metricas en dos columnas + historial de 10 ejecuciones por lado
  9.  modos: paso a paso, a ritmo, completa, y "hasta riesgo"
  11. ciclo, tiempo, PC, registros, memoria desde 0 hasta la ultima celda
La GUI solo usa la interfaz de procesadores/base.py.
"""

import tkinter as tk
from collections import deque
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from ..core.bits import hex32, s32
from ..core.state import REG_NAMES
from ..parser.parser import parse
from ..procesadores.base import Mod
from ..procesadores.multiciclo import Multiciclo
from ..procesadores.segmentado_forwarding import SegmentadoForwarding
from ..procesadores.segmentado_stalls import SegmentadoStalls
from ..procesadores.uniciclo import Uniciclo

PROCESADORES = {
    "Uniciclo": Uniciclo,
    "Multiciclo": Multiciclo,
    "Segmentado (stalls)": SegmentadoStalls,
    "Segmentado (forwarding)": SegmentadoForwarding,
}

MONO = ("Courier", 9)
ACTIVO, APAGADO, CAMBIO = "#ffd54f", "#eceff1", "#ffe082"

# Distribucion simplificada del datapath: fila 0 = fetch, 1 = decode/execute,
# 2 = memoria y escritura. Cada modulo se ilumina cuando info.active lo trae.
GRID = [
    [Mod.PC_MUX, Mod.PC, Mod.PC_PLUS4, Mod.PC_TARGET, Mod.IMEM],
    [Mod.CONTROL, Mod.RF_READ, Mod.EXTEND, Mod.SRCB_MUX, Mod.ALU],
    [Mod.DMEM, Mod.RESULT_MUX, Mod.RF_WRITE],
]

EJEMPLO = """\
# Dependencia de datos (RAW), load-use y salto tomado
addi t0, zero, 5
addi t1, t0, 3        # RAW con la anterior
sw   t1, 0(zero)
lw   t2, 0(zero)
add  t3, t2, t1       # load-use
beq  t1, t2, fin      # tomado: flush en el segmentado
addi t4, zero, 1
fin:
li   a7, 10
ecall
"""


class Lado:
    """Un procesador con todo lo que se muestra de el."""

    def __init__(self, app, parent, titulo, por_defecto):
        self.app, self.titulo, self.proc = app, titulo, None
        self.historial = deque(maxlen=10)
        self.frame = ttk.LabelFrame(parent, text=f"Procesador {titulo}")

        top = ttk.Frame(self.frame)
        top.pack(fill="x", padx=4, pady=2)
        self.sel = ttk.Combobox(top, values=list(PROCESADORES), state="readonly", width=24)
        self.sel.set(por_defecto)
        self.sel.pack(side="left")
        self.sel.bind("<<ComboboxSelected>>", lambda e: app.cargar())
        self.estado = ttk.Label(top, font=MONO)
        self.estado.pack(side="left", padx=8)

        # Datapath: un rectangulo por modulo
        self.canvas = tk.Canvas(self.frame, width=530, height=170, bg="white",
                                highlightthickness=0)
        self.canvas.pack(padx=4)
        self.rects = {}
        for r, fila in enumerate(GRID):
            for c, mod in enumerate(fila):
                x, y = 6 + c * 104, 6 + r * 54
                self.rects[mod] = self.canvas.create_rectangle(
                    x, y, x + 96, y + 46, fill=APAGADO, outline="#607d8b")
                self.canvas.create_text(x + 48, y + 23, text=mod.value, width=88,
                                        font=("TkDefaultFont", 8))

        self.etapas = tk.Label(self.frame, font=MONO, justify="left", anchor="nw",
                               height=5, relief="sunken")
        self.etapas.pack(fill="x", padx=4, pady=2)
        self.eventos = tk.Label(self.frame, font=MONO, justify="left", anchor="nw",
                                height=4, wraplength=520, fg="#37474f")
        self.eventos.pack(fill="x", padx=4)

        abajo = ttk.Frame(self.frame)
        abajo.pack(fill="both", expand=True, padx=4, pady=2)
        self.regs = self._tabla(abajo, ("reg", "abi", "hex", "dec"), (40, 50, 90, 80), 9)
        self.mem = self._tabla(abajo, ("dir", "hex", "dec"), (60, 90, 80), 9)

    @staticmethod
    def _tabla(parent, cols, anchos, alto):
        cont = ttk.Frame(parent)
        cont.pack(side="left", fill="both", expand=True)
        t = ttk.Treeview(cont, columns=cols, show="headings", height=alto)
        for c, w in zip(cols, anchos):
            t.heading(c, text=c)
            t.column(c, width=w, anchor="e")
        sb = ttk.Scrollbar(cont, command=t.yview)
        t.configure(yscrollcommand=sb.set)
        t.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        t.tag_configure("chg", background=CAMBIO)
        return t

    # ciclo de vida

    def reset(self, proc):
        self.proc = proc
        self.registrado = False
        self.prev_regs = [0] * 32
        self.prev_mem, self.snap = {}, None
        self.regs.delete(*self.regs.get_children())
        for i in range(32):
            self.regs.insert("", "end", iid=str(i))
        self.etapas.config(text="")
        self.eventos.config(text="")
        self.refresh(None)

    def refresh(self, info):
        p, s = self.proc, self.proc.state
        fin = "   [FIN]" if p.halted else ""
        self.estado.config(
            text=f"Ciclo {p.cycle}  Tiempo {p.time_ps} ps  PC {hex32(s.pc)}{fin}")

        activos = info.active if info else set()
        for mod, rid in self.rects.items():
            self.canvas.itemconfig(rid, fill=ACTIVO if mod in activos else APAGADO)

        if info:
            self.etapas.config(text="\n".join(
                f"{etapa:<10}{instr if instr is not None else '- (burbuja)'}"
                for etapa, instr in info.stages.items()))
            lineas = list(info.events[:4])
            riesgos = getattr(info, "hazards", None)
            if riesgos:
                lineas.append("riesgos: " + ", ".join(sorted(riesgos)))
            self.eventos.config(text="\n".join(lineas))

        regs = s.regs.as_list()
        for i, v in enumerate(regs):
            self.regs.item(str(i), tags=("chg",) if v != self.prev_regs[i] else (),
                           values=(f"x{i}", REG_NAMES[i], hex32(v), s32(v)))
        self.prev_regs = regs
        self._memoria(s.mem)

    def _memoria(self, mem):
        snap = bytes(mem._b) # copia para saber si hubo cambios
        if snap == self.snap:
            return
        self.snap = snap
        fin = max(64, (mem.last_used() // 4 + 1) * 4) # hasta la ultima celda usada
        palabras = mem.words(0, fin)
        self.mem.delete(*self.mem.get_children())
        for addr, w in palabras:
            cambio = w != self.prev_mem.get(addr, 0)
            self.mem.insert("", "end", tags=("chg",) if cambio else (),
                            values=(hex32(addr), hex32(w), s32(w)))
        self.prev_mem = dict(palabras)

    def registrar_fin(self, programa):
        """Al terminar el programa, guarda la ejecucion en el historial."""
        p = self.proc
        if p.halted and not self.registrado:
            self.registrado = True
            m = p.metrics()
            self.historial.append((self.titulo, p.name, programa, m["ciclos"],
                                   m["instrucciones"], m["CPI"], m["tiempo_ps"]))
            return True
        return False


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Simulador RISC-V - CE 1107")
        self.geometry("1360x900")
        self.programa, self.activo, self.modo = "editor", False, "ritmo"

        # Barra superior: editor + controles
        top = ttk.Frame(self)
        top.pack(fill="x", padx=6, pady=4)
        self.editor = tk.Text(top, height=9, width=60, font=MONO)
        self.editor.insert("1.0", EJEMPLO)
        self.editor.pack(side="left")

        ctl = ttk.Frame(top)
        ctl.pack(side="left", padx=10, anchor="n")
        botones = [("Abrir .s", self.abrir), ("Cargar / Reiniciar", self.cargar),
                   ("Paso (1 ciclo)", self.paso_manual), ("Correr a ritmo", self.correr_ritmo),
                   ("Pausa", self.detener), ("Ejecucion completa", self.completa),
                   ("Correr hasta riesgo", self.correr_riesgo)]
        for i, (txt, cmd) in enumerate(botones):
            ttk.Button(ctl, text=txt, command=cmd).grid(row=i // 2, column=i % 2, sticky="ew", padx=2, pady=2)
       
        ttk.Label(ctl, text="ms por ciclo").grid(row=4, column=0, sticky="e")
        self.vel = tk.Scale(ctl, from_=20, to=1000, orient="horizontal", length=140)
        self.vel.set(300)
        self.vel.grid(row=4, column=1)
        ttk.Label(ctl, text="detener en").grid(row=5, column=0, sticky="e")
        self.filtro = ttk.Combobox(ctl, state="readonly", width=12, values=["cualquiera", "datos", "load-use", "control", "forwarding"])
        self.filtro.set("control")
        self.filtro.grid(row=5, column=1, sticky="w")

        # Dos procesadores
        cuerpo = ttk.Frame(self)
        cuerpo.pack(fill="both", expand=True, padx=6)
        self.lados = [Lado(self, cuerpo, "A", "Segmentado (stalls)"),
                      Lado(self, cuerpo, "B", "Segmentado (forwarding)")]
        for lado in self.lados:
            lado.frame.pack(side="left", fill="both", expand=True, padx=3)

        # Metricas (dos columnas) e historial
        inf = ttk.Frame(self)
        inf.pack(fill="x", padx=6, pady=4)
        self.metricas_t = ttk.Treeview(inf, columns=("m", "A", "B"), show="headings", height=7)
        for c, w in (("m", 110), ("A", 110), ("B", 110)):
            self.metricas_t.heading(c, text={"m": "Metrica"}.get(c, f"Procesador {c}"))
            self.metricas_t.column(c, width=w)
        self.metricas_t.pack(side="left")
        cols = ("lado", "procesador", "programa", "ciclos", "instr", "CPI", "tiempo_ps")
        self.hist_t = ttk.Treeview(inf, columns=cols, show="headings", height=7)
        for c in cols:
            self.hist_t.heading(c, text=c)
            self.hist_t.column(c, width=70 if c != "procesador" else 150)
        self.hist_t.pack(side="left", fill="x", expand=True, padx=8)

        self.cargar()

    # carga

    def abrir(self):
        ruta = filedialog.askopenfilename(
            filetypes=[("Ensamblador", "*.s *.S *.asm"), ("Todos", "*")])
        if ruta:
            self.editor.delete("1.0", "end")
            self.editor.insert("1.0", Path(ruta).read_text(encoding="utf-8"))
            self.programa = Path(ruta).name
            self.cargar()

    def cargar(self):
        self.detener()
        try:
            prog = parse(self.editor.get("1.0", "end"))
        except Exception as e: # ParseError u otro
            messagebox.showerror("Error al ensamblar", str(e))
            return
        for lado in self.lados:
            lado.reset(PROCESADORES[lado.sel.get()](prog))
        self.actualizar_metricas()

    # ejecucion

    def paso(self):
        """Un ciclo en cada procesador (un ciclo no dura lo mismo en todos)."""
        infos = []
        for lado in self.lados:
            if lado.proc.halted:
                infos.append(None)
                continue
            try:
                info = lado.proc.step()
            except Exception as e:                   # p. ej. acceso invalido a memoria
                self.detener()
                messagebox.showerror(f"Error en el procesador {lado.titulo}", str(e))
                return infos
            lado.refresh(info)
            lado.registrar_fin(self.programa)
            infos.append(info)
        self.actualizar_metricas()
        return infos

    def terminado(self):
        return all(lado.proc.halted for lado in self.lados)

    def paso_manual(self):
        self.detener()
        self.paso()

    def correr_ritmo(self):
        self._iniciar("ritmo")

    def correr_riesgo(self):
        self._iniciar("riesgo")

    def _iniciar(self, modo):
        self.detener()
        self.modo, self.activo = modo, True
        self._tick()

    def detener(self):
        self.activo = False

    def _coincide(self, info):
        if info is None:
            return False
        riesgos = set(getattr(info, "hazards", ()))
        if self.filtro.get() == "cualquiera":
            return bool(riesgos - {"forwarding"})
        return self.filtro.get() in riesgos

    def _tick(self):
        if not self.activo:
            return
        infos = self.paso()
        if not self.activo: # error durante el paso
            return
        if self.terminado() or (self.modo == "riesgo" and any(self._coincide(i) for i in infos)):
            self.activo = False
            return
        self.after(int(self.vel.get()) if self.modo == "ritmo" else 1, self._tick)

    def completa(self):
        self.detener()
        for lado in self.lados:
            try:
                info = lado.proc.run()
            except Exception as e:
                messagebox.showerror(f"Error en el procesador {lado.titulo}", str(e))
                return
            lado.refresh(info)
            lado.registrar_fin(self.programa)
        self.actualizar_metricas()

    # metricas e historial

    def actualizar_metricas(self):
        ms = [lado.proc.metrics() for lado in self.lados]
        claves = list(dict.fromkeys(k for m in ms for k in m))
        self.metricas_t.delete(*self.metricas_t.get_children())
        for k in claves:
            self.metricas_t.insert("", "end", values=(k, ms[0].get(k, "-"), ms[1].get(k, "-")))
        self.hist_t.delete(*self.hist_t.get_children())
        for lado in self.lados:
            for fila in lado.historial:
                self.hist_t.insert("", "end", values=fila)


def main():
    App().mainloop()


if __name__ == "__main__":
    main()