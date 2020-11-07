# From Zippers to Continuations

Functional programming without functions, and how it's used in Sed Lisp

## Intro

Before writing Sed Lisp, interpreting using continuations was foreign to me –
I didn't fully understand how it worked.

The goal of this document is in part for future me, to document the inner
workings of Sed Lisp, in part for past me, to try to explain continuations in
a way the past me would have understood, and in part in case it's interesting to
people other than me, too.

Programming in `sed` is a fairly unique mishmash of different paradigms:
 - The gotos, global state, and lack of any kind of subroutines or functions
   feels like a bad imperative language, like the TI BASIC that runs on the
   TI-83 and 84 graphing calculators.
 - On the other hand, since pattern matching is literally the only way to get
   things done, functional data structures feel right at home.

I'll use Haskell in this, because despite its "everything is a function" vs.
`sed`'s "what's a function lol", Haskell's pattern matching and ADTs make the
algorithm clearest.

## `eval` #1: travsering the AST

Our first "eval" will simply traverse the AST, print all its strings, and then
build it back up again, without evaluating anything yet.

To this end, our first AST has just three types:
```haskell
data AST = Cons AST AST -- ^ Cons cells, with a head and a tail
         | Str String   -- ^ Strings
         | Nil          -- ^ Nil, representing an empty list
         deriving (Show, Eq)

infixr 5 `Cons`
```

For example, the program
```lisp
("Let's" ("traverse" "this"))
```
Would be represented (using arrows down for the head of a cons cell, and to the
right for the tail):
```
cons ——→ cons ——→ nil
 ↓        ↓
"Let's"  cons ——→ cons ——→ nil
          ↓        ↓
      "traverse"  "this"
```
This represents a list of strings and other lists.  But from a different
perspective, it's a binary tree, with each cons cell branching off to two
subtrees.

So let's traverse the tree, pretty-print it, and build it back up, using a
Zipper: (If you're not familiar with zippers, the [Haskell wikibooks
article](https://en.wikibooks.org/wiki/Haskell/Zippers) and
[LYAH](http://learnyouahaskell.com/zippers) are great.)

```haskell
data ZipperItem = Tail AST -- ^ The current tree is the head of a cons cell, and this holds its tail
                | Head AST -- ^ The current tree is the tail of a cons cell, and this holds its head

type Zipper = ([ZipperItem], AST)

printStrs :: AST -> IO AST
printStrs x = zipDown ([], x)

-- zipDown makes the current item smaller, adding new ZipperItems
-- zipUp re-builds the AST from the ZipperItems

zipDown :: Zipper -> IO AST
zipDown (zipper, Cons hd tl) -- If it's a cons cell, descend further
    = zipDown (Tail tl:zipper, hd)
-- If it's a leaf, we gotta go back up
zipDown (zipper, Str s) = do
    putStrLn s
    zipUp (zipper, Str s) -- Reached a leaf, go back up
zipDown (zipper, Nil) = zipUp (zipper, Nil)

zipUp :: Zipper -> IO AST
zipUp (Tail tl:rest, hd) -- Already looked at the head, now look at the tail
    = zipDown (Head hd:rest, tl)
zipUp (Head hd:rest, tl) -- Already looked at both, now move back up
    = zipUp (rest, Cons hd tl)
zipUp ([], x) = return x 
```

Testing it out:
```haskell
GHCi> printStrs $ Str "Let's" `Cons` (Str "traverse" `Cons` Str "this" `Cons` Nil) `Cons` Nil
Let's
traverse
this
Cons (Str "Let's") (Cons (Cons (Str "traverse") (Cons (Str "this") Nil)) Nil)
```
It works, but it's hardly an interpreter yet.

### How's this any better than regular recursion?

Two ways:
 - It's tail-recursive. Both `zipUp` and `zipDown` just inspect their arguments,
   maybe do some IO, and then call either `zipUp` and `zipDown` again.  The
   implication for Sed Lisp is it can be done with only `goto`s.
 - We only ever have one kind of state: the zipper.  Again, the implication for
   Sed Lisp is we can use global state for it.

---

Before going on, we're going to do some sneaky renaming:
 - `ZipperItem` → `Cont`, for `Cont`inuation
 - `zipDown` will be called `eval`
 - `zipUp` will be called `doCont`

## `eval` #2: built-in functions

Now we'll finally get to something that resembles an interpreter.  Our second
AST will support the built-in functions `concat` and `print`:

```haskell
data Builtin = Concat -- ^ takes two strings as arguments and concatenates them
             | Print  -- ^ takes a single string as an argument and prints it
             deriving (Show, Eq)

data AST = Cons AST AST -- ^ Cons cells, with a head and a tail
         | Str String   -- ^ Strings
         | Nil          -- ^ Nil, representing an empty list
         | Func Builtin -- ^ A built-in function
         deriving (Show, Eq)
```

Again, an example:

```lisp
(print (concat "Hello, " "World!"))
```

There are two things new from last time:
 - We're still traversing the whole AST, but instead of building the exact same
   AST back up, we're building up an evaluated version of it.
 - The program needs some way to know when to actually run the list it's built
   up.  For this, we can add a new ~~zipper item~~ continuation:

```haskell
-- Previously ZipperItem
data Cont = Tail AST -- ^ The current item is the head of a cons cell, and this holds its tail
          | Head AST -- ^ The current item is the tail of a cons cell, and this holds its head
          | Do -- ^ The current item is a list that needs to be executed
```

The code now looks like this:

```haskell
run :: AST -> IO AST
run x = eval ([], x)

doBuiltin :: Builtin -> AST -> IO AST
doBuiltin Print args = case args of
    Cons (Str message) Nil -> putStrLn message $> Nil
    _ -> fail "Print: bad arguments"
doBuiltin Concat args = case args of
    Str a `Cons` Str b `Cons` Nil -> return (Str (a ++ b))
    _ -> fail "Concat: bad arguments"

-- Previously zipDown
-- `eval` will fully evaluate its argument, including running any lists
eval :: ([Cont], AST) -> IO AST
eval (cont, Cons hd tl) = eval (Tail tl:Do:cont, hd) -- Add `Do` so it'll be run
eval (cont, x) = doCont (cont, x)

-- Previously zipUp
doCont :: ([Cont], AST) -> IO AST
doCont (Tail tl:cont, hd) = case tl of
    -- Can't just `eval tl`, since we haven't built up the whole list yet
    Cons hd' tl' -> eval (Tail tl':Head hd:cont, hd')
    Nil          -> eval (         Head hd:cont, Nil)
    _ -> fail "the tail of a cons cell should be a cons cell or Nil"
doCont (Head hd:cont, tl) = doCont (cont, Cons hd tl)
doCont (Do:cont, l) = case l of
    Cons (Builtin b) args -> do
        result <- doBuiltin b args
        doCont (cont, result)
    _ -> error "Unreachable"
doCont ([], x) = return x -- Nothing left to do, we traversed the whole AST
```

Trying it out:
```haskell
GHCi> let concatSubExpr = Func Concat `Cons` Str "Hello, " `Cons` Str "World!" `Cons` Nil
GHCi> let expr = Func Print `Cons` concatSubExpr `Cons` Nil
GHCi> run expr
Hello, World!
Nil
```

Fantastic! It printed the message, and `Print` returned `Nil`. We've succeeded
in interpreting a small language using continuation.

## I thought continuations were supposed to be functions!

Continuations are supposed to be functions, but we haven't used a single
closure!  Is this really continuation-passing style, if we aren't passing around
functions?

The answer is that our continuations, despite not being implemented with
closures, *semantically represent* functions.  Currying `doCont` shows that
it's actually mapping each Zipper-like continuation `[Cont]` to the function
`AST -> IO AST` that it represents:

```haskell
doCont       :: ([Cont], AST) -> IO AST
curry doCont :: [Cont] -> (AST -> IO AST)
```

The idea of representing functions using datatypes is not a new trick:
**defunctionalization** has been around for a while. If you haven't heard of
defunctionalization before, or even if you have, [there was a great talk about
it](http://www.pathsensitive.com/2019/07/the-best-refactoring-youve-never-heard.html)
at Compose 2019.

## `eval` #3: choose your own continuations

Since our zipper-like `[Cont]` is actually building up a representation for a
function, adding new *function*-ality (hah) can mean adding new `Cont`s.  I'm not
going to show any new Haskell code, though.

Here's a few extra `Cont`s that are used in Sed Lisp:

 - Sed Lisp remembers the arguments list for user functions in a stack. When
   a function is called, it pushed the arguments list to the stack, and adds
   a `PopArgs` continuation to be run when the function is done.
 - In an `if` statement, only one of the branches should be interpreted. When
   the interpreter sees the `if` built-in, it pushs a `TailIf` continuation
   instead of the regular `Tail` continuation.  When `doCont` sees the `TailIf`
   continuation, it chooses a branch to evaluate based on the truthiness of the
   current value.

And a few extra `Cont`s that aren't used, but could be:

 - A `MkHashMap` continuation could be added to support hash map literals.
 - For exceptions and `try`/`catch`, a `Catch handler` continuation could be
   added.  The `throw` function would go through the continuation until it
   found the first `Catch handler`, and run `handler` on the exception.

## Takeaways

 - Continuations aren't that scary, and can be useful: the resulting code is
   fully tail-recursive, and fairly extensible.
 - FP isn't all about lambdas and closures: just because you don't have
   functions doesn't mean you can't write functional code.

I hope you learned something, or at least found it interesting. :)
