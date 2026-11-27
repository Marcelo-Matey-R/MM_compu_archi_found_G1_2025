"""Programa ya ensamblado: lo que el parser entrega al simulador."""

from dataclasses import dataclass, field

from .instr import Instr


@dataclass
class Program:
    instrs: list[Instr]  # instruccion i en la direccion 4*i
    data: bytes = b""  # contenido inicial de la memoria de datos, a partir de la direccion 0
    text_labels: dict[str, int] = field(default_factory=dict)   # nombre -> dir. de instruccion
    data_labels: dict[str, int] = field(default_factory=dict)   # nombre -> dir. de dato
    entry: int = 0 # direccion de la primera instruccion (main)

    @property
    def end_addr(self) -> int:
        """Direccion justo despues de la ultima instruccion.
        Se usa como valor inicial de ra: cuando main hace 'ret', el PC
        llega aqui, fetch() devuelve None y el programa termina.
        """
        return 4 * len(self.instrs)

    def label_at(self, addr: int) -> str | None:
        """Etiqueta de texto en una direccion (para la GUI), si hay alguna."""
        for name, a in self.text_labels.items():
            if a == addr and not name.startswith(".L"):
                return name
        return None
