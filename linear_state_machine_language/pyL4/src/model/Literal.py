from datetime import timedelta
from typing import Any

from src.model.constants_and_defined_types import SUPPORTED_TIMEUNITS
from src.model.Term import Term


class Literal(Term):
    def __init__(self) -> None:
        self.lit : Any
    def __repr__(self):
        return str(self)

class FloatLit(Literal):
    def __init__(self,lit:float) -> None:
        super().__init__()
        self.lit = lit

    def __str__(self) -> str:
        return str(self.lit)

class IntLit(Literal):
    def __init__(self, lit:int) -> None:
        super().__init__()
        self.lit = lit
    def __str__(self):
        return str(self.lit)

class BoolLit(Literal):
    def __init__(self, lit:bool) -> None:
        super().__init__()
        self.lit = lit
    def __str__(self):
        return str(self.lit)

class DeadlineLit(Literal):
    def __init__(self, lit:str) -> None:
        super().__init__()
        self.lit = lit
    def __str__(self):
        return str(self.lit)

class StringLit(Literal):
    def __init__(self, lit:str) -> None:
        super().__init__()
        self.lit = lit
    def __str__(self):
        return "'" + self.lit + "'"

class SimpleTimeDeltaLit(Literal):
    """
    REVERSED because this AST node is for literals like 1M or 4D --> Take an L4Contract instead of a string like 'd','h','w' etc to avoid the use of more than one unit in a contract (which is what `timestamp` is for)

    NOTE some of this functionality is duplicated in interpreter.py
    """
    def __init__(self, num:int, unit:str) -> None:
        super().__init__()
        assert unit in SUPPORTED_TIMEUNITS, f'time unit {unit} unsupported'
        self.num = num
        self.unit = unit
        if self.unit == 'd':
            self.timedelta = timedelta(days=self.num)
        elif self.unit == 'h':
            self.timedelta = timedelta(hours=self.num)
        elif self.unit == 'w':
            self.timedelta = timedelta(weeks=self.num)
        elif self.unit == 'm':
            self.timedelta = timedelta(minutes=self.num)
        else:
            assert self.unit == 's'
            self.timedelta = timedelta(seconds=self.num)

    # Are these used???
    def __lt__(self, other: 'SimpleTimeDeltaLit'):
        return self.timedelta < other.timedelta

    def __le__(self, other: 'SimpleTimeDeltaLit'):
        return self.timedelta <= other.timedelta

    def __str__(self) -> str:
        return f"{self.num}{self.unit}"

    def __repr__(self) -> str:
        return f"SimpleTimeDeltaLit({self.num},{self.unit})"
