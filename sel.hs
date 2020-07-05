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
starting = Hold (M.fromList h) [] [] 10
  where h = [ (10, Link 0 9)
            , (9, Link 8 5)
            , (8, Link 1 7)
            , (7, Link 6 0)
            , (6, String "a warm greeting")
            , (5, Link 4 0)
            , (4, Link 1 3)
            , (3, Link 2 0)
            , (2, String "from sed lisp")
            , (1, Builtin Print)
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
        _ -> do
          put $ Hold heap (tl:args) (PopArgs:cont) hd
          eval
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
      then case M.lookup tl heap of
        Just (Link x _) -> put $ Hold heap args cont x
        _ -> throwError "quote: bad arguments"
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
