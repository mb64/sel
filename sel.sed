#!/usr/bin/sed -nEf

x
s/^$/CURRENT 13\
CONT\
CONTEND\
ARGS\
ARGEND\
HEAP\
ITEM 1 Bquote\
ITEM 2 Bprint\
ITEM 3 Sa warm greeting\
ITEM 4 L3:0\
ITEM 5 L2:4\
ITEM 6 L5:0\
ITEM 7 Sfrom sed lisp\
ITEM 8 L7:0\
ITEM 9 L2:8\
ITEM 10 L9:6\
ITEM 11 L0:0\
ITEM 12 L1:11\
ITEM 13 L12:10\
HEAPEND\
INPUT:/
G
s/INPUT:\n/INPUT /
s/_/\\u/g
s/@/\\a/g

b eval

:main-loop

# Execute the continuation!

/\nCONT\nDO/{
    # drop DO
    s/\nCONT\nDO\n/\nCONT\n/
    # prepend ^LINK head tail\n
    t dummy-lbl-0
    :dummy-lbl-0
    s/^CURRENT ([0-9]+)\n.*\nITEM \1 L([0-9]+):([0-9]+)\n/LINK \2 \3\n&/
    T error
    # if current.head is a builtin:
    #   change to ^B...\nCURRENT tail\n
    #   do builtin
    s/^LINK ([0-9]+) ([0-9]+)\nCURRENT [0-9]+\n(.*\nITEM \1 (B[^\n]+)\n)/\4\nCURRENT \2\n\3/
    t do-builtin
    # else:
    #   push tail to ARGS, set current to head
    s/^LINK ([0-9]+) ([0-9]+)\nCURRENT [0-9]+(\n.*\nARGS\n)/CURRENT \1\3\2\n/
    #   push POPARGS continuation
    s/\nCONT\n/\nCONT\nPOPARGS\n/
    #   goto eval
    b eval
}

/\nCONT\nTAIL/{
    # push CONS current behind TAIL value
    s/^CURRENT ([0-9]+)\nCONT\nTAIL [0-9]+\n/&CONS \1\n/
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
    b eval
}

/\nCONT\nCONS/{
    # push heap NEW Lvalue:current, drop CONS value, and goto new
    s/^(CURRENT ([0-9]+)\nCONT\nCONS ([0-9]+)\n.*\n)HEAPEND/\1NEW L\3:\2\nHEAPEND/
    s/\nCONT\nCONS [0-9]+\n/\nCONT\n/
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
# FIXME: this doesn't work for some reason...
s/^CURRENT [0-9]+(\n.*\nITEM ([0-9]+) ([^\n]+)$.*\n)NEW \3\n/CURRENT \2\3/m
t next-cont
# It's not a copy of some other thing, gotta actually make a new id
:legit-new
# copy over the old id and increment it
s/^CURRENT [0-9]+(\n.*\nITEM ([0-9]+) [^\n]+\n)NEW /CURRENT \2_\1ITEM \2_ /
t increment-loop
:increment-loop
s/\b_/1/g
s/8_/9/g
s/7_/8/g
s/6_/7/g
s/5_/6/g
s/4_/5/g
s/3_/4/g
s/2_/3/g
s/1_/2/g
s/0_/1/g
t next-cont
s/9_/_0/g
t dummy-lbl-3
:dummy-lbl-3
b increment-loop

###### eval ######
:eval
t dummy-lbl-4
:dummy-lbl-4
# Prepend ^LINK head tail\n
s/^CURRENT ([0-9]+)\n.*\nITEM \1 L([0-9]+):([0-9]+)\n/LINK \2 \3\n&/
# if it's not a cons cell, do nothing
T next-cont
/^LINK ([0-9]+) .*\nITEM \1 Bquote\n/{
    # Quote: set current to tail, cleanup, and return
    s/^LINK [0-9]+ ([0-9]+)\nCURRENT [0-9]+\n/CURRENT \1\n/
    b next-cont
}
# push cont TAIL current.tail\nDO
# set current to current.head
s/^LINK ([0-9]+) ([0-9]+)\nCURRENT [0-9]+\nCONT\n/CURRENT \1\nCONT\nTAIL \2\nDO\n/
# keep eval-ing
b eval

###### builtins ######
:do-builtin
# It should look like ^B...\nCURRENT [0-9]+\n
/^Bprint/{
    # print the first arg, a string
    t dummy-lbl-5
    :dummy-lbl-5
    s/^Bprint\n//
    T error
    # switch to hold space and print it
    h
    s/^CURRENT ([0-9]+)\n.*ITEM \1 L([0-9]+):/\2\n&/
    T error
    s/^([0-9]+)\n.*ITEM \1 S([^\n]*)\n.*$/\2/p
    T error
    # switch back and return
    x
    b next-cont
}
b next-cont

:error
s/.*/error/
p

:done
z


# Plan
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
# ARGS grows UP
# CONT grows UP
# HEAP grows DOWN
