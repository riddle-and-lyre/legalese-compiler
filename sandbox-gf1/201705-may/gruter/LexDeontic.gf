interface LexDeontic = open Syntax in {
  param
    DOp = Oblig | Forb | Perm ;

  oper
    Deon : Type = { d   : DOp
                  ; pol : Pol
                  ; vv  : VV };
    
    D_Shall   : Deon = { d = Oblig; pol = positivePol; vv = Deontic_must_VV };
    D_MustNot : Deon = { d = Forb;  pol = negativePol; vv = Deontic_must_VV };
    D_May     : Deon = { d = Perm;  pol = positivePol; vv = Deontic_may_VV };

}
