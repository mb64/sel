-- A haskell implementation of the Sed Lisp execution strategy.
-- vim:ts=2 sw=2

import qualified Data.IntMap.Strict as M
import Control.Monad
import Control.Monad.State
import Control.Monad.Except

data Builtin = Quote | Car | Cdr | Print | Args deriving (Show, Eq, Ord)

data Item = Link Int Int
          | String String
          | Builtin Builtin
          deriving (Show, Eq, Ord)

data Cont = Tail Int
          | Cons Int
          | Do
          | PopArgs
          deriving (Show, Eq, Ord)

-- The contents of the Hold space
data Hold = Hold
    { getHeap :: M.IntMap Item
    , getArgs :: [Int]
    , getCont :: [Cont]
    , getCurrent :: Int
    } deriving (Show, Eq, Ord)

starting :: Hold
starting = Hold (M.fromList h) [] [] 13
  where h = [ (1, Builtin Quote)
            , (2, Builtin Print)
            , (3, String "a warm greeting")
            , (4, Link 3 0)
            , (5, Link 2 4)
            , (6, Link 5 0)
            , (7, String "from sed lisp")
            , (8, Link 7 0)
            , (9, Link 2 8)
            , (10, Link 9 6)
            , (11, Link 0 0)
            , (12, Link 1 11)
            , (13, Link 12 10)
            ]

type SelM = StateT Hold (ExceptT String IO)

run :: Builtin -> SelM ()
run Quote = throwError "can't run quote"
run Car = do
  Hold heap args cont curr <- get
  let Just (Link x _) = M.lookup curr heap
  case M.lookup x heap of
    Just (Link hd _) -> put $ Hold heap args cont hd
    _ -> throwError "not a node"
run Cdr = do
  Hold heap args cont curr <- get
  let Just (Link x _) = M.lookup curr heap
  case M.lookup x heap of
    Just (Link _ tl) -> put $ Hold heap args cont tl
    _ -> throwError "not a node"
run Print = do
  Hold heap args cont curr <- get
  let Just (Link x _) = M.lookup curr heap
  case M.lookup x heap of
    Just (String s) -> do
      liftIO $ putStrLn s
      put $ Hold heap args cont 0 -- TODO should it return nil?
    _ -> throwError "not a string"
run Args = StateT $ \(Hold heap (a:as) cont _) -> pure $ ((),Hold heap (a:as) cont a)

step :: SelM ()
step = do
  hold <- get
  case hold of
    Hold _ _ [] _ -> throwError "quit"
    Hold heap args (Do:cont) curr -> case M.lookup curr heap of
      Just (Link hd tl) -> case M.lookup hd heap of
        Just (Builtin b) -> do
          put $ Hold heap args cont tl
          run b
        Just (Link _ _) -> do
          put $ Hold heap (tl:args) (PopArgs:cont) hd
          eval
        _ -> throwError "do: must be a builtin or a cons cell"
      _ -> throwError "should be a node"
    Hold heap args (Tail 0:cont) curr -> put $ Hold heap args (Cons curr:cont) 0
    Hold heap args (Tail val:cont) curr -> case M.lookup val heap of
      Just (Link hd tl) -> do
        put $ Hold heap args (Tail tl:Cons curr:cont) hd
        eval
      _ -> throwError "should be a node"
    Hold heap args (Cons val:cont) curr -> do
      let newLink = 1 + fst (M.findMax heap)
      put $ Hold (M.insert newLink (Link val curr) heap) args cont newLink
    Hold heap (a:as) (PopArgs:cont) curr -> put $ Hold heap as cont curr

eval :: SelM ()
eval = do
  Hold heap args cont curr <- get
  case M.lookup curr heap of
    Just (Link hd tl) -> do
      if M.lookup hd heap == Just (Builtin Quote)
      then put $ Hold heap args cont tl
      else do
        put $ Hold heap args (Tail tl:Do:cont) hd
        eval
    _ -> pure ()

sel :: Hold -> IO String
sel st = do
  answer <- runExceptT $ evalStateT (eval >> forever step) st
  case answer of
    Right _ -> error "unreachable"
    Left s -> pure s

main :: IO ()
main = do
  msg <- sel starting
  putStrLn $ "Result: " ++ msg
