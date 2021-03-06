from typing import Optional, List, NamedTuple

from src.model.PartialEvalTerm import PartialEvalTerm
from src.model.Term import Term
from src.model.constants_and_defined_types import *
from src.model.util import indent, mapjoin


class ActionRule:
    def __init__(self,
                 role_id: RoleId,
                 action_id: ActionId,
                 args: Optional[List[RuleBoundActionParamId]],
                 entrance_enabled_guard: Optional[Term]) -> None:
        self.role_id = role_id
        self.action_id = action_id
        self.entrance_enabled_guard = entrance_enabled_guard
        self.time_constraint: Term
        self.where_clause: Optional[Term] = None

        self.args = args
        self.args_name_to_ind = {self.args[i]:i for i in range(len(self.args))} if self.args else None

    def toStr(self, i:int) -> str:
        raise NotImplemented

    def __str__(self) -> str:
        return self.toStr(0)

    def __repr__(self) -> str:
        return self.toStr(0)
    
def common_party_action_rule_toStr(ar:Union['PartyFutureActionRule', 'PartyNextActionRule'], i:int) -> str:
    rv: str = ""
    indent_level = i
    if ar.entrance_enabled_guard:
        rv = indent(indent_level) + "if " + str(ar.entrance_enabled_guard) + ":\n"
        indent_level += 1

    if ar.action_id == FULFILLED_SECTION_LABEL and str(ar.time_constraint) == 'immediately':
        rv += indent(indent_level) + FULFILLED_SECTION_LABEL
        return rv

    if ar.role_id == ENV_ROLE:
        rv += indent(indent_level) + ar.action_id
    else:
        rv += indent(indent_level) + f"{ar.role_id} {ar.deontic_keyword} {ar.action_id}"

    if ar.args:
        rv += f"({mapjoin(str , ar.args, ', ')})"

    if ar.role_id == ENV_ROLE and str(ar.time_constraint) == 'immediately':
        return rv

    if ar.time_constraint:
        rv += " " + str(ar.time_constraint)

    if ar.where_clause:
        rv += " where " + str(ar.where_clause)

    return rv

class PartyFutureActionRule(ActionRule):
    def __init__(self,
                 src_action_id: ActionId,
                 role_id: RoleId,
                 action_id: ActionId,
                 args: Optional[List[RuleBoundActionParamId]],
                 entrance_enabled_guard: Optional[Term],
                 deontic_keyword: DeonticKeyword) -> None:
        super().__init__(role_id, action_id, args, entrance_enabled_guard)
        self.src_action_id = src_action_id
        self.deontic_keyword = deontic_keyword

    def toStr(self, i:int) -> str:
        return common_party_action_rule_toStr(self, i)


class PartlyInstantiatedPartyFutureActionRule(NamedTuple):
    # todo QUESTION: Should time constraint be partially evaluated??
    """
    It's derived from, and points at, a PartyFutureActionRule. Call that its parent rule.
    Its parent rule's `entrance_enabled_guard` evaluated to True when this thing was created.
    It has values for all `GlobalVarId`s that occur in its parent's `where_clause` or `time_constraint`.
    It has values for all `ActionBoundActionParamId`s that occur in its parent's `where_clause`  or `time_constraint`. Such variables can only
    occur if its parent rule is defined in a `FollowingSection` declaration, since that is the only way that
    an `ActionBoundActionParamId` can be in the scope of a `where_clause` or `time_constraint`.
    It has values for none of the `RuleBoundActionParamId`s that occur in its `where_clause` or `time_constraint`.
    """
    rule : PartyFutureActionRule
    pe_where_clause : Optional[PartialEvalTerm] # "pe" for PartialEval
    # pe_time_constraint : PartialEvalTerm

    # not necessary because comes from .pe_where_clause.gvar_subst (== .pe_time_constraint.gvar_subst):
    #   gvar_vals : GVarSubst
    # not necessary because comes from .pe_where_clause.abap_subst (== .pe_time_constraint.abap_subst)
    #   ab_aparam_vals : List[Any] # "ab_aparam" short for action-bound action-param.
    #   aba_param_vals_dict : Dict[ActionBoundActionParamId,Any]  # shouldn't be necessary except maybe for debugging

    def __repr__(self) -> str:
        return str(self.rule) + " with partly-instantiated where clause " + str(self.pe_where_clause)
        # return "PartlyInstantiatedPartyFutureActionRule..."

class NextActionRule(ActionRule):
    def __init__(self,
                 src_id: SectionId,
                 role_id: RoleId,
                 action_id: ActionId,
                 args: Optional[List[RuleBoundActionParamId]],
                 entrance_enabled_guard: Optional[Term]) -> None:
        super().__init__(role_id, action_id, args, entrance_enabled_guard)
        self.src_id = src_id


class PartyNextActionRule(NextActionRule):
    def __init__(self,
                 src_id: SectionId,
                 role_id: RoleId,
                 action_id: ActionId,
                 args: Optional[List[RuleBoundActionParamId]],
                 entrance_enabled_guard: Optional[Term],
                 deontic_keyword: DeonticKeyword) -> None:
        super().__init__(src_id, role_id, action_id, args, entrance_enabled_guard)

        self.deontic_keyword = deontic_keyword

    def toStr(self, i:int) -> str:
        return common_party_action_rule_toStr(self, i)


class EnvNextActionRule(NextActionRule):
    def __init__(self,
                 src_id: SectionId,
                 action_id: ActionId,
                 args: Optional[List[RuleBoundActionParamId]],
                 entrance_enabled_guard: Optional[Term]) -> None:
        super().__init__(src_id, ENV_ROLE, action_id, args, entrance_enabled_guard)

    def toStr(self, i:int) -> str:
        rv : str = ""
        indent_level = i
        if self.entrance_enabled_guard:
            rv = indent(indent_level) + "if " + str(self.entrance_enabled_guard) + ":\n"
            indent_level += 1

        assert self.role_id == ENV_ROLE
        rv += indent(indent_level) + self.action_id

        if self.args:
            rv += f"({mapjoin(str , self.args, ', ')})"

        if str(self.time_constraint) == 'immediately':
            return rv

        if self.time_constraint:
            rv += " " + str(self.time_constraint)

        return rv



