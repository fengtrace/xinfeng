module Main where

import Xinfeng.Syntax
import Xinfeng.Parser
import Xinfeng.Checker
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr)

-- | Debug: show token stream
dbgTokens :: String -> IO ()
dbgTokens input = do
  let tokens = lexer input
  putStrLn "=== TOKENS ==="
  mapM_ (putStrLn . ("  " ++) . show) tokens

-- | Pretty print a term in Haskell-like syntax
ppTerm :: Term -> String
ppTerm (Type n) = "Type" ++ show n
ppTerm (Pi "_" a b) = ppTerm a ++ " → " ++ ppTerm b
ppTerm (Pi x a b) = "(" ++ x ++ " : " ++ ppTerm a ++ ") → " ++ ppTerm b
ppTerm (Lam x b) = "λ" ++ x ++ ". " ++ ppTerm b
ppTerm (App f a) = ppTerm f ++ " " ++ ppAtom a
ppTerm (Ref n) = n
ppTerm (Con "True") = "True"
ppTerm (Con "False") = "False"
ppTerm (Con n) = n
ppTerm (Data d) = "data " ++ dataName d
ppTerm (Match s bs) = "match " ++ ppTerm s ++ "\n" ++
  unlines (map ppBranch bs)

ppAtom :: Term -> String
ppAtom t@(App _ _) = "(" ++ ppTerm t ++ ")"
ppAtom t = ppTerm t

ppBranch :: Branch -> String
ppBranch (Branch c [] body) = "  | " ++ c ++ " → " ++ ppTerm body
ppBranch (Branch c vars body) =
  "  | " ++ c ++ " " ++ unwords vars ++ " → " ++ ppTerm body

-- | Pretty print a type error
ppError :: TypeError -> String
ppError (TypeMismatch expected actual term _ty) =
  "type mismatch"
ppError (UniverseMismatch expected actual) =
  "universe mismatch (expected " ++ show expected ++ ", got " ++ show actual ++ ")"
ppError (NotAFunctionType t) =
  "not a function type: " ++ ppTerm t
ppError (UnknownName n) =
  "unknown name: " ++ n
ppError (InvalidDataType n) =
  "invalid data type: " ++ n
ppError (MatchBranchMismatch c t1 t2) =
  "match branch mismatch for " ++ c
ppError (Other msg) = msg

-- | Render interface only (type sigs, no bodies)
renderInterface :: [Definition] -> String
renderInterface = unlines . map defInterface
  where
    defInterface d = case defBody d of
      Data dt -> "data " ++ dataName dt ++
                 " = " ++ intercalate " | " (map conName (dataCons dt))
      _       -> defName d ++ " : " ++ ppTerm (defType d)
    intercalate sep [] = ""
    intercalate sep [x] = x
    intercalate sep (x:xs) = x ++ sep ++ intercalate sep xs

-- | JSON output types
data JsonValue
  = JStr String
  | JNum Int
  | JBool Bool
  | JList [JsonValue]
  | JObj [(String, JsonValue)]
  | JNull

toJson :: JsonValue -> String
toJson (JStr s) = show s
toJson (JNum n) = show n
toJson (JBool b) = if b then "true" else "false"
toJson JNull = "null"
toJson (JList vs) = "[" ++ commaSep (map toJson vs) ++ "]"
toJson (JObj kvs) = "{" ++ commaSep (map (\(k,v) -> show k ++ ": " ++ toJson v) kvs) ++ "]"

-- | JSON helper - safely escape and build
renderJson :: [(String, JsonValue)] -> String
renderJson fields = "{" ++ commaSep (map (\(k,v) -> jsonStr k ++ ": " ++ toJson v) fields) ++ "}"

jsonStr :: String -> String
jsonStr s = "\"" ++ escape s ++ "\""
  where
    escape = concatMap (\c -> case c of
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\n' -> "\\n"
      '\t' -> "\\t"
      c -> [c])

commaSep :: [String] -> String
commaSep [] = ""
commaSep [x] = x
commaSep (x:xs) = x ++ "," ++ commaSep xs

-- | Check definitions and return results
checkAndReturn :: String -> IO (Either String [Definition])
checkAndReturn input = case parseDefinitions input of
  Left err -> return (Left err)
  Right defs -> return (Right defs)

-- | Run type checks on definitions
runChecks :: [Definition] -> [(String, Either TypeError ())]
runChecks defs = go [] defs
  where
    go _ [] = []
    go ctx (d : rest) =
      let result = check ctx (defBody d) (defType d)
          ctx' = (defName d, (defType d, defBody d)) : ctx
      in (defName d, result) : go ctx' rest

-- | Print the result for a definition (human-readable)
printResult :: Definition -> Either TypeError () -> IO ()
printResult d (Right ()) =
  putStrLn $ "✅ " ++ defName d ++ " : " ++ ppTerm (defType d)
printResult d (Left err) = do
  hPutStrLn stderr $ "❌ " ++ defName d ++ " — " ++ ppError err
  hPutStrLn stderr $ "  Definition body: " ++ ppTerm (defBody d)

-- | Load definitions and type check them (human mode)
loadAndCheck :: String -> IO ()
loadAndCheck input = case parseDefinitions input of
  Left err -> do
    hPutStrLn stderr $ "Parse error: " ++ err
    exitFailure
  Right defs -> do
    let results = runChecks defs
    sequence_ (zipWith printResult defs results)

-- | Output JSON results
outputJSON :: String -> IO ()
outputJSON input = do
  case parseDefinitions input of
    Left err -> do
      putStrLn $ renderJson
        [("status", JStr "error")
        ,("message", JStr err)
        ]
      exitFailure
    Right defs -> do
      let results = runChecks defs
      let defResults = map (\(d, r) -> case r of
            Right () ->
              renderJson
                [("name", JStr (defName d))
                ,("status", JStr "pass")
                ,("type", JStr (ppTerm (defType d)))
                ]
            Left e ->
              renderJson
                [("name", JStr (defName d))
                ,("status", JStr "fail")
                ,("type", JStr (ppTerm (defType d)))
                ,("error", JStr (ppError e))
                ]
            ) (zip defs results)
      let allPass = all (\(_,r) -> case r of Right () -> True; Left _ -> False) results
      putStrLn $ renderJson
        [("status", JStr (if allPass then "pass" else "fail"))
        ,("definitions", JStr "[" ++ commaSep defResults ++ "]")
        ]

main :: IO ()
main = do
  args <- getArgs
  case args of
    ("--tokens" : file : _) -> do
      content <- readFile file
      dbgTokens content
    ("--tokens" : _) -> do
      content <- getContents
      dbgTokens content
    ("--interface" : file : _) -> do
      content <- readFile file
      case parseDefinitions content of
        Left err -> do
          hPutStrLn stderr $ "Parse error: " ++ err
          exitFailure
        Right defs -> putStrLn (renderInterface defs)
    ("--interface" : _) -> do
      content <- getContents
      case parseDefinitions content of
        Left err -> do
          hPutStrLn stderr $ "Parse error: " ++ err
          exitFailure
        Right defs -> putStrLn (renderInterface defs)
    ("--json" : file : _) -> do
      content <- readFile file
      outputJSON content
    ("--json" : _) -> do
      content <- getContents
      outputJSON content
    [] -> do
      input <- getContents
      loadAndCheck input
    [file] -> do
      content <- readFile file
      loadAndCheck content
    _ -> do
      hPutStrLn stderr "Usage: xinfeng-poc [--json|--interface|--tokens] [file]"
      exitFailure
