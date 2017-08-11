from typing import Union, List, Any
from util import is_singleton_string_list
from constants_and_defined_types import SExpr

STRING_LITERAL_MARKER = "STRLIT"
COMMENT_LITERAL_MARKER = "COMMENT"
LINE_COMMENT_START_CHAR = ';'

left_groupers = {'(','{','[','‹','❪'}
right_groupers = {')','}',']','›','❫'}
grouper_map = {'(':')', '{':'}', '[':']', '‹':'›', '❪':'❫', '"':'"', "'":"'", '`':'`', LINE_COMMENT_START_CHAR:'\n'}
quotelike = {"'",'"','`'}
double_splits_word_only = {':=','+=','-=','==','<=', '>=', '->', '=>', '<-'}
splits_word_only = {':','=',','}
all_symb_tags = quotelike.union(left_groupers).union(';')


class TaggedList(list):
    def __init__(self,symb,lst:list=None, line:int=None, col:int=None) -> None:
        super().__init__(lst if lst else [])
        self.symb = symb
        self.line = line
        self.col = col
        assert isinstance(symb,str) and symb in all_symb_tags

class SExprBuilder:
    def __init__(self) -> None:
        # stack of growing S-Expressions
        self.stack : List[List[Any]] = [[]]

    def openParenSeq(self,symb,line:int=None,col:int=None):
        self.stack.append(TaggedList(symb, [], line, col))

    def appendTokenInCurScope(self,token): 
        self.curScope.append(token)

    def closeParenSeq(self,closesymb,line,col):
        temp = self.stack.pop()
        assert temp is not None and grouper_map[temp.symb] == closesymb, ("Found " + closesymb + " while expecting " + grouper_map[temp.symb] + "\n" +
                                                                          "Left symbol line {} col {}\n".format(temp.line,temp.col) +
                                                                          "Right symbol line {} col {}".format(line,col) )
        self.curScope.append(temp)

    @property
    def curScope(self):
        return self.stack[-1] 

    def __repr__(self):
        return '*' + repr(self.stack) + '*'




def parse(string:str, debug=False, strip_comments=True) -> SExpr:
    """
    >>> parse("(+ 5 (+ 3 5))")
    [['+', '5', ['+', '3', '5']]]
    >>> parse("+ 5 (+ 3 5)")
    ['+', '5', ['+', '3', '5']]
    >>> parse("(f a)")
    [['f', 'a']]
    >>> parse("f a")
    ['f', 'a']
    >>> parse("'f () is a string' a")
    [['STRLIT', 'f () is a string'], 'a']
    >>> parse('"one string" \\'another string\\'')
    [['STRLIT', 'one string'], ['STRLIT', 'another string']]
    >>> parse('"quote ` in string"')
    [['STRLIT', 'quote ` in string']]
    """
    builder = SExprBuilder() 
    word = '' 
    
    # str_lit_opened_at = None
    in_str_lit = False
    in_comment = False
    skip_next_char = False
    str_lit_quote = None
    
    i,line,col = 0,1,1

    def maybeAppendToken():
        nonlocal word, builder
        if word:
            builder.appendTokenInCurScope(word)
            word = ''

    for i in range(len(string)):
        char = string[i]

        assert not in_comment or not in_str_lit

        if not skip_next_char:
            if in_comment:
                if char == '\n':
                    in_comment = False
                    if not strip_comments:
                        maybeAppendToken()
                        builder.closeParenSeq(char, line, col)
                else:
                    if not strip_comments:
                        word += char

            elif (char in left_groupers) and not in_str_lit:
                maybeAppendToken()
                builder.openParenSeq(char, line, col)

            elif (char in right_groupers) and not in_str_lit:
                maybeAppendToken()
                builder.closeParenSeq(char,line,col)

            elif char == LINE_COMMENT_START_CHAR and not in_str_lit and not in_comment:
                in_comment = True
                if not strip_comments:
                    builder.openParenSeq(char,line,col)
                    builder.appendTokenInCurScope(COMMENT_LITERAL_MARKER)

            elif char in (' ', '\n', '\t') and not in_str_lit:
                maybeAppendToken()

            elif char in quotelike and ((not in_str_lit) or (str_lit_quote == char)):
                if in_str_lit:
                    in_str_lit = False
                    str_lit_quote = None
                    # str_lit_opened_at = None
                    builder.appendTokenInCurScope(word)
                    word = ''
                    builder.closeParenSeq(char,line,col)
                else:
                    in_str_lit = True
                    str_lit_quote = char
                    # str_lit_opened_at = (i,line,col)
                    builder.openParenSeq(char)
                    builder.appendTokenInCurScope(STRING_LITERAL_MARKER)

            elif i < len(string)-1 and (char + string[i+1]) in double_splits_word_only:
                maybeAppendToken()
                word = char + string[i+1]
                skip_next_char = True
                maybeAppendToken()

            elif char in splits_word_only:
                maybeAppendToken()
                word = char
                maybeAppendToken()

            elif in_str_lit and char == '\n':
                assert False, "\nNo linebreaks in strings, just to prevent hard-to-diagnose syntax errors. See line {} column {}".format(line,col)

            else:
                word += char
        else:
            skip_next_char = False

        if char == '\n':
            line += 1
            col = 1  
        else:
            col += 1        

        if debug:
            print(char, repr(builder.stack))

    maybeAppendToken()        
    
    if debug:
        print(char, repr(builder.stack))
        print("stack size: ", len(builder.stack))

    return builder.curScope

def pretty(l:Union[str,TaggedList],nspaces=0) -> str:
    indent = " "*nspaces
    if isinstance(l,str):
        return indent + l
    elif isinstance(l,list) and len(l) >= 1 and l[0] == STRING_LITERAL_MARKER:
        return indent + "`" + l[1] + "`"
    else:
        lsymb = l.symb if isinstance(l,TaggedList) else "("
        rsymb = grouper_map[l.symb] if isinstance(l,TaggedList) else ")"
        s = ""
        line_broke = False
        for x in l:
            if isinstance(x,str):
                s += " " + x
            elif isinstance(x,list) and len(x) == 0:
                s += "()"
            elif isinstance(x,TaggedList) and x.symb == '[' and is_singleton_string_list(x):
                s += " [" + x[0] + "]"
            elif isinstance(x,list) and len(x) >= 1 and x[0] == STRING_LITERAL_MARKER:
                s += " `" + x[1] + "`"    
            else:
                s += "\n" + pretty(x,nspaces+4)
                line_broke = True
        if line_broke:
            s = indent + lsymb + s 
            s += "\n"+indent + rsymb
        else:
            s = indent + lsymb + s
            s += " " + rsymb    
        return s
        # return indent + lsymb + "\n" + "\n".join([pretty(x,nspaces+2) for x in l]) + "\n" + indent + rsymb        
    


# FILES = (
#     '/Users/dustin/NoLockin/NoLockin Datatypes/Collections/Unordered/Set/SetMonotonic.nlo',
#     '/Users/dustin/NoLockin/NoLockin Datatypes/Collections/Unordered/Set/Set.nlo',
#     '/Users/dustin/Sites/legalese/legalese-compiler/singlethreaded-statemachine-language/examples/hvitved_printer_sexpr.LSM',
#     '/Users/dustin/Sites/legalese/legalese-compiler/flat-nonconcurrent-language/sexpr_language/printer_sexpr.L4fnc'
# )

if __name__ == '__main__':
    # import sys
    # if 'test' in sys.argv:
    import doctest
    print("Running tests")
    doctest.testmod()

    # if 'file' in sys.argv:
    #     for path in FILES:
    #         print("\nLooking at file " + path + ":\n")
    #         fil = open(path,'r')
    #         parsed = parse(fil.read())
    #         print( parsed, "\n")
    #         print( pretty(parsed) )