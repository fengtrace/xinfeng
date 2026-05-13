module Main where

import Xinfeng.Syntax
import Xinfeng.Parser
import Xinfeng.Checker
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

-- | Pretty print a term (simple version)
ppTerm :: Term -> String
ppTerm (Type n) = "Type" ++ show n
ppTerm (Pi "_" a b) = ppTerm a ++ " → " ++ ppTerm b
ppTerm (Pi x a b) = "(Π (" ++ x ++ " : " ++ ppTerm a ++ ") " ++ ppTerm b ++ ")"
ppTerm (Lam x b) = "λ" ++ x ++ ". " ++ ppTerm b
ppTerm (App (App (Ref "match") scrut) branches) =
  "match " ++ ppTerm scrut ++ " { ... }"
ppTerm (App f a) = "(" ++ ppTerm f ++ " " ++ ppTerm a ++ ")"
ppTerm (Ref n) = n
ppTerm (Con n) = n
ppTerm (Data d) = "data " ++ dataName d
ppTerm (Match s bs) = "match " ++ ppTerm s ++ " { " ++
  unwords (map ppBranch bs) ++ " }"
ppTerm (Lam x (Lam y b)) = "λ" ++ x ++ " " ++ y ++ ". " ++ ppTerm b

ppBranch :: Branch -> String
ppBranch (Branch c vars body) = "(" ++ c ++ " " ++ unwords vars ++ " " ++ ppTerm body ++ ")"

-- | Pretty print a type error
ppError :: TypeError -> String
ppError (TypeMismatch expected actual term ty) =
  "❌ Type mismatch\n" ++
  "  Expected type: " ++ ppTerm expected ++ "\n" ++
  "  Actual type:   " ++ ppTerm actual ++ "\n" ++
  "  Term:          " ++ ppTerm term
ppError (UniverseMismatch expected actual) =
  "❌ Universe mismatch\n" ++
  "  Expected universe: " ++ show expected ++ "\n" ++
  "  Actual universe:   " ++ show actual
ppError (NotAFunctionType t) =
  "❌ Not a function type:\n  " ++ ppTerm t
ppError (UnknownName n) =
  "❌ Unknown name: " ++ n
ppError (InvalidDataType n) =
  "❌ Invalid data type: " ++ n
ppError (MatchBranchMismatch c t1 t2) =
  "❌ Match branch mismatch for " ++ c ++ "\n" ++
  "  Expected: " ++ ppTerm t1 ++ "\n" ++
  "  Actual:   " ++ ppTerm t2
ppError (Other msg) = "❌ " ++ msg

-- | Load definitions and type check them
loadAndCheck :: String -> IO ()
loadAndCheck input = case parseDefinitions input of
  Left err -> do
    hPutStrLn stderr $ "Parse error: " ++ err
    exitFailure
  Right defs -> do
    let results = checkDefinitions [] defs
    sequence_ (zipWith printResult defs results)

-- | Check a list of definitions sequentially, building context
checkDefinitions :: Context -> [Definition] -> [Either TypeError ()]
checkDefinitions ctx [] = []
checkDefinitions ctx (d : rest) =
  let result = check ctx (defBody d) (defType d)
      ctx' = (defName d, (defType d, defBody d)) : ctx
  in result : checkDefinitions ctx' rest

-- | Print the result for a definition
printResult :: Definition -> Either TypeError () -> IO ()
printResult d (Right ()) =
  putStrLn $ "✅ " ++ defName d ++ " : " ++ ppTerm (defType d)
printResult d (Left err) = do
  hPutStrLn stderr $ "❌ " ++ defName d ++ " — " ++ ppError err
  hPutStrLn stderr $ "  Definition body: " ++ ppTerm (defBody d)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> do
      -- Read from stdin
      input <- getContents
      loadAndCheck input
    [file] -> do
      content <- readFile file
      loadAndCheck content
    _ -> do
      hPutStrLn stderr "Usage: xinfeng-poc [file]"
      exitFailure
