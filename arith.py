#!/usr/bin/python

# Arithmetic in Sel
#
# math is hard in sed
# so we're gonna have a lookup table for digit addition
# Items 100 through 199 are the sums of 00 through 99
# However, 1xy only exists for x ≤ y
# This makes there be fewer items (smaller pattern space, faster execution)
# and also comparisons are possible (x ≤ y iff 1xy exists)
#
# 100-199 are single-item lists, whose item is a cons cell with:
#   car: truthy if carry, nil if not carry
#   cdr: the digit sum
#
# digits are stored as single-digit strings
#
# items 10-19 are digits
# items 20-29 are results for addition without carry
# items 30-39 are results for addition with carry


# Output sum table
for x in reversed(range(10)):
    for y in reversed(range(x, 10)):
        print("ITEM 1{}{} L{}:0".format(x, y, 20 + x + y))

# Output results for addition with carry
for x in reversed(range(10)):
    print("ITEM 3{x} L1:1{x}".format(x=x))

# Output results for addition without carry
for x in reversed(range(10)):
    print("ITEM 2{x} L0:1{x}".format(x=x))

# Output digits
for x in reversed(range(10)):
    print("ITEM 1{x} \"{x}".format(x=x))

# Bc we're capitalizing all the low-number cons cells with this, might as well
# make items 1-9 some commonly used builtins
print("ITEM 9 Bcadr-args")
print("ITEM 8 Bcdr-args")
print("ITEM 7 Bcar-args")
print("ITEM 6 Bcadr")
print("ITEM 5 Bcdr")
print("ITEM 4 Bcar")
print("ITEM 3 Bargs")
print("ITEM 2 Bprint")
print("ITEM 1 Bquote")

# Program section!
print("PROGRAM")
