# Sel – Sed Lisp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Quick start

```shell
$ make sel.sed
$ ./sel.sed <<EOF
val main (print "Hello, World!")
EOF
Hello, World!
```

## The language

### Example

```lisp
; Comments are ;

; Define values with val
val nil ()

; Write functions by quoting the function body, or with the func keyword
func list (args)
; ^^ syntactic sugar for val list (quote (args))

; usage: (foreach function list)
func foreach (
    ; if evaluates both args, so for recursion, we can use if to pick a
    ; function, and then run it on the arguments
    (if (cadr-args) ; conditions are true if non-nil
        ; Make an anonymous function by quoting its body
        (quote (nil
            ((car-args) (caadr-args))
            (foreach (car-args) (cdadr-args))
        ))
        ; If the list is nil, do nothing
        nil
    )
    (car-args)
    (cadr-args)
)

; Use val for main instead of func
val main (foreach print
    (list
        "a warm greeting"
        "from sed lisp"
    )
)
```

### Datatypes

There are four basic datatypes:
 - Cons cells
 - Strings
 - Builtins
 - Nil

### Evaluation

Everything is eagerly evaluated, unless it is quoted (`(quote (whatever))`).

In list, each item is evaluated left-to-right, and then the head of the list
is run with the tail as its arguments.

Within a function, you can get the args using the `args` or `c[ad]+r-args`
builtins.

### Builtin functions

There are an infinite number of builtin functions:

 - `quote`: returns its first argument without evaluating anything
 - `args`: gets the arguments to the function
 - `print`: outputs its first argument, a string
 - `if`: `(if cond a b)` returns `b` if `cond` is `nil`, and `a` otherwise
 - `c[ad]+r`: standard Lisp `car`, `cdr`, `cadr`, etc, but with an unlimited number of `a`'s or `d`'s
 - `c[ad]+r-args`: `(car-args)` is equivalent to `(car (args))`, but faster and easier
 - `cons`: creates a new cons cell
 - `str-concat`: concatenates all of its arguments, which should be strings

### Dynamic symbol lookup and scope

There is no dynamic symbol lookup, and no scope.

Code is run in two steps:
 1. Parsing and name resolution. (File: `parser.sed`)

    The result is a collection of cons cells, strings, and builtins, with no
    names attached.

 2. Actually running it. (File: `runner.sed`)

### Mutability and memory management

Also none. Everything is fully immutable, and all data is leaked.

However, it's not as memory-inefficient as that makes it seem: everything
(strings, builtins, and even cons cells) is interned.

## The implementation

It's MIT licensed, so you're free to use/modify/etc it. Not sure why you'd want
to, though.

Requires GNU sed. Tested with GNU sed 4.8.

It's also *blazing fast*.  The example program `test-prog.sel` performs multiple
list traversals in *under a second!*

```shell
$ time ./sel.sed test-prog.sel 
sed lisp says: Check it out!
sed lisp says: Now with more recursion
sed lisp says: https://github.com/mb64/sel

real	0m0.816s
user	0m0.791s
sys	0m0.021s
```

