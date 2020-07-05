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
    s/^(CURRENT ([0-9]+)\nCONT\nCONS ([0-9]+)\n.*\n)HEAP\n/\1HEAP\nNEW L\3:\2\n/
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
/\nCONT\nCONTEND\n/b quit
# keep looping
b main-loop

############ Some subroutines ############

###### new heap item ######
:new
# Try to find it interned already somewhere
t dummy-lbl-2
:dummy-lbl-2
s/^CURRENT [0-9]+(\n.*\n)NEW ([^\n]+)\n((.*\n)?ITEM ([0-9]+) \2\n)/CURRENT \5\1\3/
t next-cont
# It's not a copy of some other thing, gotta actually make a new id
:legit-new
# copy over the old id and increment it
s/^CURRENT [0-9]+(\n.*\n)NEW ([^\n]+\nITEM ([0-9]+) )/CURRENT \3_\1ITEM \3_ \2/
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
    # Quote: set current to tail.head, cleanup, and return
    s/^LINK [0-9]+ ([0-9]+)\nCURRENT [0-9]+\n/CURRENT \1\n/
    T error
    s/^CURRENT ([0-9]+)(\n.*\nITEM \1 L([0-9]+):)/CURRENT \3\2/
    T error
    b next-cont
}
# push cont TAIL current.tail\nDO
# set current to current.head
s/^LINK ([0-9]+) ([0-9]+)\nCURRENT [0-9]+\nCONT\n/CURRENT \1\nCONT\nTAIL \2\nDO\n/
# keep eval-ing
b eval

###### builtins ######
:do-builtin

/^Bprint\n/{
    # print the first arg, a string
    s/^Bprint\n//
    # switch to hold space and print it
    h
    t dummy-lbl-5
    :dummy-lbl-5
    s/^CURRENT ([0-9]+)\n.*ITEM \1 L([0-9]+):/\2\n&/
    T error
    s/^([0-9]+)\n.*ITEM \1 "([^\n]*)\n.*$/\2/p
    T error
    # switch back and return nil
    x
    s/^CURRENT [0-9]+\n/CURRENT 0\n/
    b next-cont
}

/^Bargs\n/ {
    # set current to args
    s/^Bargs\n//
    s/^CURRENT [0-9]+(\n.*\nARGS\n([0-9]+)\n)/CURRENT \2\1/
    b next-cont
}

/^Bc[ad]+r-args\n/ {
    # set current to args, and then do c[ad]+r
    s/-args\nCURRENT [0-9]+(\n.*\nARGS\n([0-9]+)\n)/\nCURRENT \2\1/
    s/^Bc([ad]+)r\n/\1\n/
    b c[ad]+r-loop
}

/^Bc[ad]+r\n/ {
    s/^Bc([ad]+)r\n/\1a\n/
    :c[ad]+r-loop
    t dummy-lbl-6
    :dummy-lbl-6
    s/^\n//
    t next-cont
    /^[ad]*a\n/ {
        # set current to (car current) and pop a
        s/a\nCURRENT ([0-9]+)(\n.*\nITEM \1 L([0-9]+):)/\nCURRENT \3\2/
        T error
        b c[ad]+r-loop
    }
    # set current to (cdr current) and pop d
    s/d\nCURRENT ([0-9]+)(\n.*\nITEM \1 L[0-9]+:([0-9]+)\n)/\nCURRENT \3\2/
    T error
    b c[ad]+r-loop
}

/^Bif\n/ {
    s/^Bif\n//

    # Prepend LINK head tail
    t dummy-lbl-7
    :dummy-lbl-7
    s/^CURRENT ([0-9]+)\n.*\nITEM \1 L([0-9]+):([0-9]+)\n/LINK \2 \3\n&/
    T error
    /^LINK 0 / {
        # nil -> False
        # set current to cadr tail and return
        s/^LINK 0 ([0-9]+)\nCURRENT [0-9]+(\n.*\nITEM \1 L[0-9]+:([0-9]+)\n)/CAR \3\2/
        T error
        s/^CAR ([0-9]+)(\n.*\nITEM \1 L([0-9]+):)/CURRENT \3\2/
        T error
        b next-cont
    }
    # not nil -> True
    # set current to car tail and return
    s/^LINK [0-9]+ ([0-9]+)\nCURRENT [0-9]+(\n.*\nITEM \1 L([0-9]+):)/CURRENT \3\2/
    T error
    b next-cont
}

/^Bcons\n/ {
    s/^Bcons\n//

    # Prepend LINK head tail
    t dummy-lbl-8
    :dummy-lbl-8
    s/^CURRENT ([0-9]+)\n.*\nITEM \1 L([0-9]+):([0-9]+)\n/LINK \2 \3\n&/
    T error
    # add NEW head tail.head and goto new
    s/^LINK ([0-9]+) ([0-9]+)\n(.*\nHEAP\n)((.*\n)?ITEM \2 L([0-9]+):)/\3NEW L\1:\6\n\4/
    T error
    b new
}

/^Bstr-concat\n/ {
    s/^Bstr-concat\n//

    # Prepend "...\nREST rest\n
    s/^CURRENT ([0-9]+)\n/"\nREST \1\n&/

    t str-concat-loop
    :str-concat-loop
    /\nREST 0\n/ {
        # Done concatenating! Now add new item
        s/^("[^\n]*)\nREST 0\n(.*\nHEAP\n)/\2NEW \1\n/
        b new
    }
    s/^("[^\n]*)\nREST ([0-9]+)\n(.*\nITEM \2 L([0-9]+):([0-9]+)\n)/\1\nADD \4\nREST \5\n\3/
    T error
    s/^("[^\n]*)\nADD ([0-9]+)\n(.*\nITEM \2 "([^\n]*)\n)/\1\4\n\3/
    T error
    b str-concat-loop
}

# Not a builtin
s/^B([^\n]+)\n.*/Error: \1: not a builtin/
p
q 1

:error
s/.*/Error!/
p
q 1

:quit
q
