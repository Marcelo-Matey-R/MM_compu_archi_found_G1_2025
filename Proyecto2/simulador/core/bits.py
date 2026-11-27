XLEN = 32
MASK32 = 0xFFFFFFFF


def u32(x: int) -> int:
    """Cualquier int -> patron de 32 bits sin signo (0 .. 2^32-1)."""
    return x & MASK32


def s32(x: int) -> int:
    """Patron de 32 bits -> entero con signo (-2^31 .. 2^31-1)."""
    x &= MASK32
    return x - (1 << 32) if x & 0x80000000 else x


def sext(x: int, bits: int) -> int:
    """Extiende el signo de un valor de 32 bits."""
    mask = (1 << bits) - 1
    x &= mask
    sign_bit = 1 << (bits - 1)
    if x & sign_bit:
        x -= 1 << bits          # valor negativo en Python
    return u32(x)


def zext(x: int, bits: int) -> int:
    """Extension con ceros."""
    return x & ((1 << bits) - 1)


def fits_signed(x: int, bits: int) -> bool:
    """True si x (entero con signo) cabe en 'bits' bits en complemento a 2."""
    return -(1 << (bits - 1)) <= x < (1 << (bits - 1))


def hex32(x: int) -> str:
    """Formato para la GUI: 0x0000002A."""
    return f"0x{u32(x):08X}"
