#!/usr/bin/sed -Ef

x
s/^$/HEAP\nITEM 100 N11:10\nITEM 11 Bprint\nITEM 10 N1:0\nITEM 1 Shello\nHEAPEND\nARGS 0\nCONT\nDO\nCONTEND\nCURRENT 100\nINPUT:/
H
s/INPUT:\n/INPUT /
s/_/\\u/g
s/@/\\a/g

# Main executing loop
:exe

# Execute the continuation!

/\nCONT\nDO Bputc/{
    # set current to car(current)
    s/(\nITEM ([01]+) L([01]+):[01]+\n.*\nCURRENT) \2\n/\1 \3\n/
    T error
    # lookup char for current and print (in hold space)
    h
    s/.*\nITEM ([01]+) C(.|\\\\|\\a|\\u|\\n)\n.*\nCURRENT \1\n.*/\2/
    T error
    s/\\u/_/
    s/\\a/@/
    s/\\n/\n/
    s/\\\\/\\/
    p
    # back to pattern space and set result to nil
    x
    s/\nCURRENT [01]+\n/\nCURRENT 0\n/
    b pop-cont
}
/\nCONT\nDO Bcar/{
    # set current to car(current)
    s/(\nITEM ([01]+) L([01]+):[01]+\n.*\nCURRENT) \2\n/\1 \3\n/
    T error
    b pop-cont
}
/\nCONT\nDO Bcdr/{
    # set current to cdr(current)
    s/(\nITEM ([01]+) L[01]+:([01]+)\n.*\nCURRENT) \2\n/\1 \3\n/
    T error
    b pop-cont
}

/\nCONT\nDO L/{
    # set args from current
    s/\nARGS [01]+\n(.*)\nCURRENT ([01]+)\n/\nARGS \2\n\1\nCURRENT \2\n/
    # uhh
    # TODO
    b error
}

/\nCONT\nNEXT /{
    # 0 is already evaluated
    /\nCONT\nNEXT 0\n/b don't-eval
    b do-eval
    :don't-eval
    # replace with CONS current, set current to 0
    s/\nCONT\nNEXT 0(\n.*\nCURRENT )([01]+)\n/\nCONT\nCONS \2\10\n/
    b done-cont
    :do-eval
    # lookup
    s/(\nITEM ([01]+) L([01]+):([01]+)\n.*\nCONT\nNEXT \2\n.*)$/\1\nHEAD \3\nTAIL \4/
    T error
    # replace with CONS current, NEXT tail
    # if head is cons cell:
    #    if head.head is Bquote:
    #        set current to head.tail
    #    else:
    #        push DO head.head, set c
}

# Next continutation!
:pop-cont
s/\nCONT\n[^\n]*\n/\nCONT\n/
:done-cont

/\nCONT\nCONTEND\n/b done
# keep looping
b exe

:error
s/.*/error/
p

:done
z


# New plan
# How continuations work:
#   DO:
#       if current.head is a builtin:
#           set current to current.tail
#           ... do builtin stuff on current ...
#           set current to the result
#       else current.head is a cons cell:
#           set ARGS to current.tail
#           set current to current.head
#           eval current
#   TAIL value:
#       push CONS current
#       if value is nil:
#           set current to nil
#       else value is a cons cell:
#           push TAIL value.tail
#           set current to value.head
#           eval current
#   CONS value:
#       create new cons cell Nvalue:current
#       set current to result
# How eval current works:
#   if current is a cons cell:
#       if current.head is Bquote:
#           set current to current.tail
#       else:
#           push DO
#           push TAIL current.tail
#           set current to current.head
#           goto eval current
#   else current is not a cons cell:
#       do nothing
