abstract Particular = Gruter ** {
  flags startcat = Contract;
  fun
    Always, BlueMoon            : WhenPredicate;
    Party_A, Party_B, Party_C   : Party;
    Pay_Kind, Deliver_Kind      : ActionKind;
    Pay_Act                     : Action Pay_Kind;
    Deliver_Act                 : Action Deliver_Kind;
    Pay_Exp                     : ActionExp Pay_Kind;
    Deliver_Exp                 : ActionExp Deliver_Kind;
}
