from model.GlobalVarDec import GlobalVarDec
from model.ContractParamDec import ContractParamDec
from model.GlobalStateTransformStatement import LocalVarDec
from model.Term import Term


class BoundVar(Term):
    def __init__(self) -> None:
        super().__init__()
        pass

    def __str__(self):
        return self.name
    def __repr__(self):
        return self.name

    @property
    def name(self) -> str:
        raise NotImplementedError


class LocalVar(BoundVar):
    def __init__(self, vardec: LocalVarDec) -> None:
        super().__init__()
        self.vardec : LocalVarDec = vardec

    @property
    def name(self) -> str:
        return self.vardec.varname


class GlobalVar(BoundVar):
    def __init__(self, vardec:GlobalVarDec) -> None:
        super().__init__()
        self.vardec : GlobalVarDec = vardec

    @property
    def name(self) -> str:
        return self.vardec.name


class ContractParam(BoundVar):
    def __init__(self, paramdec:ContractParamDec) -> None:
        super().__init__()
        self.paramdec : ContractParamDec = paramdec

    @property
    def name(self) -> str:
        return self.paramdec.name