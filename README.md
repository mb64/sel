# Sel – Sed Lisp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Quick start

```shell
$ ./sel.sed <<EOF
val main (print "Hello, World!")
EOF
Hello, World!
```

## The language

### Example

```lisp
# I'm not sure if I like # for comments, I might change it

# Define values with val
val nil ()
# Function with func
func list (args)

# use: (foreach function list)
func foreach (
    # if evaluates both args, so for recursion, we can use if to pick a
    # function, and then run it on the arguments
    (if (cadr-args) # conditions are true if non-nil
        # Make an anoymous function by quoting its body
        (quote (nil
            ((car-args) (caadr-args))
            (foreach (car-args) (cdadr-args))
        ))
        # If the list is nil, do nothing
        nil
    )
    (car-args)
    (cadr-args)
)

# Use val for main instead of func
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
