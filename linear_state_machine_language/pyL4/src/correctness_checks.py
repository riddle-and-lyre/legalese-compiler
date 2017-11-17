import logging
from typing import Set, Union

from model.ActionWithDestination import is_derived_destination_id, is_derived_trigger_id
from model.constants_and_defined_types import *
from model.L4Contract import L4Contract

# just for typing!!
class L4ContractConstructor:
    top : L4Contract
    referenced_section_ids: Set[SectionId]
    referenced_action_ids: Set[ActionId]

def referenced_nonderived_section_ids_equal_defined_nonderived_section_ids(it:any) -> bool:
    referenced_nonderived_section_ids = set(filter( lambda x: not is_derived_destination_id(x), it.top.section_ids())
                                            ).union([FULFILLED_SECTION_LABEL])
    if  it.referenced_section_ids != set(referenced_nonderived_section_ids):
        logging.warning(
        f"""
ISSUE: Set of referenced nonderived section ids ≠ set of declared nonderived section ids (plus '{FULFILLED_SECTION_LABEL}'):
Referenced             : {str(sorted(it.referenced_section_ids))} 
Defined (+ '{FULFILLED_SECTION_LABEL}'): {str(sorted(set(referenced_nonderived_section_ids)))}"""
        )
        return False
    return True

def referenced_nonderived_action_ids_equal_defined_nonderived_action_ids(it:any) -> bool:
    referenced_nonderived_action_ids = set(filter( lambda x: not is_derived_trigger_id(x), it.top.action_ids()))
    if  it.referenced_action_ids != set(referenced_nonderived_action_ids):
        logging.warning(
        f"""
ISSUE: Set of referenced nonderived action ids ≠ set of declared nonderived action ids:
Referenced  : {str(sorted(it.referenced_action_ids))} 
Defined     : {str(sorted(set(referenced_nonderived_action_ids)))}"""
        )
        return False

    return True

test_fns = [
    referenced_nonderived_section_ids_equal_defined_nonderived_section_ids,
    referenced_nonderived_action_ids_equal_defined_nonderived_action_ids
]
