from enum import Enum
from typing import NamedTuple, Optional, Any, Dict, Sequence, List
from datetime import timedelta

from src.model.constants_and_defined_types import ActionId, RoleId, ABAPSubst, Data, ABAPNamedSubst, \
    ContractParamId, AParamsSubst

class EventType(Enum):
    use_floating_permission = 'use_floating_permission'
    fulfill_floating_obligation = 'fulfill_floating_obligation'
    party_next = 'party_next'
    env_next = 'env_next'

class Event(NamedTuple):
    action_id: ActionId
    role_id: RoleId
    timestamp: int
    params_by_abap_name: Optional[ABAPNamedSubst]
    params: Optional[AParamsSubst]
    type: EventType

def breachSectionId(*role_ids:str):
    return "Breach_" + "_".join(role_ids)


Trace = Sequence[Event]
class CompleteTrace(NamedTuple):
    contract_param_subst: Dict[str, Any]
    events: Trace
    final_section: str  # will need to be a SectionId
    final_values: Optional[Dict[str,Any]] = None

