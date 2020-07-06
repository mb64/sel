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

# some builtins
print("ITEM 47 Bcaar-args")
print("ITEM 46 Bstr-reverse-concatl")
print("ITEM 45 Bstr-reverse-concat")
print("ITEM 44 Bstr-concatl")
print("ITEM 43 Bstr-concat")
print("ITEM 42 Bdigit-add-carry")
print("ITEM 41 Bdigit-add")

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

# numbers are little-endian lists of numbers
arith_funcs = '''
func num-to-str (str-reverse-concatl (car-args))

; (add-carry x y) == x + y + 1
; Also deals with if x and/or y is nil
func add-carry (
    (if (car-args)
        (if (cadr-args)
            (quote ( ; Both! hope I got this right
                (quote (cons (cdar-args)
                    ((if (caar-args) add-carry add)
                        (cdaadr-args)
                        (cdadadr-args)
                    )
                ))
                (digit-add-carry (caar-args) (caadr-args))
                (args)
            ))
            (quote ; Yes x, but no y: add 1 to x
                (add (car-args) (quote ("1")))
            )
        )
        (if (cadr-args)
            (quote ; Yes y, but no x: add 1 to y
                (add (cadr-args) (quote ("1")))
            )
            (quote ; Both are nil: just return ("1")
                (quote ("1"))
            )
        )
    )
    (car-args)
    (cadr-args)
)

; (add x y) == x + y
; Also deals with if x and/or y is nil
func add (
    (if (car-args)
        (if (cadr-args)
            (quote ( ; Both -- I sincerely hope to never type cdadadr again in my life
                (quote (cons (cdar-args)
                    ((if (caar-args) add-carry add)
                        (cdaadr-args)
                        (cdadadr-args)
                    )
                ))
                (digit-add (caar-args) (caadr-args))
                (args)
            ))
            (quote (car-args)) ; Yes x, but no y: return x
        )
        (if (cadr-args)
            (quote (cadr-args)) ; Yes y, but no x: return y
            () ; Both are nil: return nil
        )
    )
    (car-args)
    (cadr-args)
)
'''

print(arith_funcs)
