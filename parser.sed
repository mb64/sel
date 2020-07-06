# First, read all input
/^%include / {
    # sadly the easiest way to read an arbitrary file is with cat
    s/^%include /cat/
    e
}
H
$!d
z
x
s/^\n//

# remove comments
s/$/\n/
s/;[^\n]*\n/\n/g

# some things you're not allowed to do
/_/ {
    s/.*/Error: the _ character is disallowed/
    p
    q 1
}
/@/ {
    s/.*/Error: the @ character is disallowed/
    p
    q 1
}

###### Preprocessing ######

s/^/\n/
# If there's no PROGRAM, add one
/\nPROGRAM/!s/^/\nPROGRAM/
# If there's no START, add one
/\nSTART/!s/\nPROGRAM/\nSTART main\nPROGRAM/
# If there's no initial ITEMs, add one
/\nITEM /!s/\nSTART/\nITEM 1 Bquote\nSTART/
s/^\n//

###### Strings ######

# Add a marker that we're doing strings, so new knows where to return to
s/$/\nstrings/

:strings-loop
t parser-dummy-lbl-0
:parser-dummy-lbl-0
s/\nPROGRAM\n([^"]*)"(([^"\n]|\\")*)"/\nPROGRAM\n"\2\n\1@/
T done-strings
s/^(.*\nPROGRAM\n)("[^\n]*\n)/NEW \2\1/
b parser-new
:done-strings
s/\nstrings$//
# Can unescape \" now
s/\\"/"/g

# Check for remaining quotes
/\nPROGRAM.*"/ {
    s/.*/Parse error: mismatched quotes/
    p
    q 1
}

###### Lists ######

# new return marker
s/$/\nlists/

:lists-loop
t lists-inner
:lists-inner
s/(\nPROGRAM\n.*)\)/\1 0]/
t lists-inner
s/^(.*\nPROGRAM\n.*[^a-zA-Z0-9?-])([a-zA-Z0-9?-]+)\s+([0-9]+)\]/NEW L\2:\3\n\1@]/
t parser-new
s/\(\s*([0-9]+)\]/\1/g
t lists-inner
s/\nfunc\s+([a-zA-Z0-9?-]+)\s+([a-zA-Z0-9?-]+)/\nval \1 (quote \2)/
t lists-inner

s/\nlists$//
# If there's any parens left over, they were mismatched
/\nPROGRAM\n.*[)(]/ {
    s/.*/Parse error: mismatched parentheses/
    p
    q 1
}

###### builtins ######

# collect all used builtins
s/^/\n/
s/\nSTART/&@/
t find-builtins-loop
:find-builtins-loop
s/(.*\nITEM [0-9]+ L(quote|print|args|c[ad]+r|c[ad]+r-args|if|cons|str-concat|digit-add|digit-add-carry))(:.*)@(.*)$/\1@\3\4\nbuiltin \2/
t find-builtins-loop
s/@//
s/^\n//

# new return marker
s/$/\nbuiltins/

:builtins-loop
t parser-dummy-lbl-1
:parser-dummy-lbl-1
s/^(.*\nPROGRAM.*\n)builtin ([a-zA-Z0-9?-]+)/NEW B\2\n\1val \2 @/
t parser-new

s/\nbuiltins$//

###### resolve names ######

# Normalize defs
s/\nval\s+([a-zA-Z0-9?-]+)\s+([a-zA-Z0-9?-]+)/\nval \1 \2/g

# Add dummy item for the start symbol
s/^.*\nSTART ([a-zA-Z0-9?-]+)/\nITEM 0 L\1:\n&/

# FIXME: this will loop infinitely with things like val x x
:resolve-names-loop
s/(\nITEM [0-9]+ L)([a-zA-Z0-9?-]*[a-zA-Z?-][a-zA-Z0-9?-]*)(:.*\nval \2 ([a-zA-Z0-9?-]+))/\1\4\3/
t resolve-names-loop

# check for unresolved identifiers
/\nITEM [0-9]+ L[0-9]*[a-zA-Z?-]/ {
    s/.*\nITEM [0-9]+ L([a-zA-Z0-9?-]*[a-zA-Z?-][a-zA-Z0-9?-]*):.*/Parse error: unresolved name \1/
    p
    q 1
}

###### other setup ######

s/^\nITEM 0 L([0-9]+):\n/CURRENT \1\
CONT\
CONTEND\
ARGS\
ARGSEND\
HEAP\
/
s/\nSTART.*/\nHEAPEND\n/
s/\n+/\n/g

###### Done! ######
b parser-done

############ Some subroutines ############

###### new heap item ######
# the place to put the number should be marked by @
:parser-new
# Try to find it interned already somewhere
t parser-dummy-lbl-2
:parser-dummy-lbl-2
s/^NEW ([^\n]+)\n((.*\n)?ITEM ([0-9]+) \1\n.*)@/\2\4/
t done-parser-new
# It's not a copy of some other thing, gotta actually make a new id
# copy over the old id and increment it
s/^NEW ([^\n]+\nITEM ([0-9]+) .*)@/ITEM \2_ \1\2_/
t parser-new-increment-loop
:parser-new-increment-loop
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
t done-parser-new
s/9_/_0/g
t parser-dummy-lbl-3
:parser-dummy-lbl-3
b parser-new-increment-loop
:done-parser-new
/strings$/b strings-loop
/lists$/b lists-loop
/builtins$/b builtins-loop
s/.*/internal error in new/
p
q 1

:parser-done
