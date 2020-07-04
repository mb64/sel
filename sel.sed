#!/usr/bin/sed -Ef

x
s/^$/CURRENT 100\
CONT\
DO\
CONTEND\
ARGS\
ARGEND\
HEAP\
ITEM 1 Shello\
ITEM 2 L1:0\
ITEM 3 Bprint\
ITEM 4 L11:10\
HEAPEND\
INPUT:/
H
s/INPUT:\n/INPUT /
s/_/\\u/g
s/@/\\a/g

:main-loop

# Execute the continuation!

/\nCONT\nDO/{
    # drop DO
    s/\nCONT\nDO\n/\nCONT\n/
    # deref current, push to top of pat space ^HEAD num\nTAIL num\n
    t dummy-lbl-0
    :dummy-lbl-0
    s/^(CURRENT ([0-9]+)\n.*\nITEM \2 L([0-9]+):([0-9]+)\n)/\1\nHEAD \3\nTAIL \4\n/
    T error
    # if current.head is a builtin:
    #   change to ^B...\nCURRENT num\n
    #   do builtin
    s/^HEAD ([0-9]+)\nTAIL ([0-9]+)\nCURRENT [0-9]+\n(.*\nITEM \1 (B[^\n]+)\n)/\4\nCURRENT \2\n\3/
    t do-builtin
    # else:
    #   push TAIL to ARGS, set current to HEAD
    s/^HEAD ([0-9]+)\nTAIL ([0-9])+\nCURRENT [0-9]+(\n.*\nARGS\n)/CURRENT \1\3\2\n/
    #   push POPARGS continuation
    s/\nCONT\n/\nCONT\nPOPARGS\n/
    #   goto eval
    b eval
}

/\nCONT\nTAIL/{
    # push CONS current behind TAIL value
    s/^(CURRENT ([0-9]+)\nCONT\nTAIL [0-9]+\n)/\1CONS \2/
    # if value is nil:
    /\nCONT\nTAIL 0\n/{
        # set current to 0
        s/^CURRENT [0-9]+\n/CURRENT 0\n/
        b pop-cont
    }
    # set value to value.tail and current to value.head
    t dummy-lbl-1
    :dummy-lbl-1
    s/^CURRENT [0-9]+\nCONT\nTAIL ([0-9]+)(\n.*ITEM \1 L([0-9]+):([0-9]+)\n)/CURRENT \3\nCONT\nTAIL \4\2/
    T error
    b done-cont
}

/\nCONT\nCONS/{
    # push heap NEW Lvalue:current and goto new
    s/^(CURRENT ([0-9]+)\nCONT\nCONS ([0-9]+)\n.*\n)HEAPEND/\1NEW L\3:\2\nHEAPEND/
    b new
}

/\nCONT\nPOPARGS/{
    # pop args
    s/\nARGS\n[0-9]+\n/\nARGS\n/
    b pop-cont
}

# Next continutation!
:pop-cont
s/\nCONT\n[^\n]*\n/\nCONT\n/
:next-cont
/\nCONT\nCONTEND\n/b done
# keep looping
b main-loop

############ Some subroutines ############

###### new heap item ######
:new
# Try to find it interned already somewhere
t dummy-lbl-2
:dummy-lbl-2
s/\nNEW ([^\n]+)$(.*\nITEM ([0-9]+) \1\n.*\nCURRENT )[0-9]+\n/\2\1\n/m
t main-loop
# It's not a copy of some other thing, gotta actually make a new id
:legit-new
# copy over the old id and increment it
s/(\nITEM ([0-9]+) [^\n]+\n)NEW /\1ITEM \2_ /
t increment-loop
:increment-loop
s/\b_/1/
s/8_/9/
s/7_/8/
s/6_/7/
s/5_/6/
s/4_/5/
s/3_/4/
s/2_/3/
s/1_/2/
s/0_/1/
t main-loop
s/9_/_0/
t dummy-lbl-3
:dummy-lbl-3
b increment-loop

###### eval ######
:eval
# TODO
b main-loop

###### builtins ######
:do-builtin
# It should look like ^BUILTIN B...\nCURRENT [0-9]+\n
# TODO
b main-loop

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
#       else: (current.head is likely a cons cell)
#           push current.tail to ARGS
#           set current to current.head
#           (TODO: add TCO by checking if there's already a POPARGS continuation)
#           push POPARGS continuation
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
#       create new cons cell Lvalue:current
#       set current to result
#   POPARGS:
#       pretty self-explanatory
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
#
#
#
# ARGS grows UP
# CONT grows UP
# HEAP grows DOWN
