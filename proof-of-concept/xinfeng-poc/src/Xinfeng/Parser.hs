module Xinfeng.Parser where

import Xinfeng.Syntax
import qualified Data.Map as Map

-- | A simple S-expression type for intermediate representation
data SExpr
  = SSym String
  | SNum Int
  | SList [SExpr]
  deriving (Show, Eq)

-- | Tokenize and parse S-expressions
parseSExprs :: String -> Either String [SExpr]
parseSExprs input = case run input of
  Left err -> Left err
  Right es -> Right es
  where
    run s = case parseOne (filterComments s) of
      Right (e, "") -> Right [e]
      Right (e, rest) -> case run rest of
        Right es -> Right (e:es)
        Left _   -> Right [e]
      Left err -> Left err

filterComments :: String -> String
filterComments [] = []
filterComments (';':rest) = filterComments (dropWhile (/= '\n') rest)
filterComments (c:rest) = c : filterComments rest

parseOne :: String -> Either String (SExpr, String)
parseOne (' ' : rest) = parseOne rest
parseOne ('\n': rest) = parseOne rest
parseOne ('\r': rest) = parseOne rest
parseOne ('\t': rest) = parseOne rest
parseOne ('(' : rest) = parseList rest
parseOne (')' : _) = Left "unexpected ')'"
parseOne s =
  let (tok, rest) = span (\c -> notElem c " ()" && c /= ';' && c /= '\n' && c /= '\r' && c /= '\t') s
  in case tok of
    "" -> Left "empty token"
    _ | all (`elem` "0123456789") tok ->
      Right (SNum (read tok), rest)
    _ -> Right (SSym tok, rest)

parseList :: String -> Either String (SExpr, String)
parseList s = go [] s
  where
    go acc s = case parseOne s of
      Left err -> Left err
      Right (e, rest) -> case rest of
        (')' : rest') -> Right (SList (reverse (e:acc)), rest')
        _ -> go (e:acc) rest

-- | Convert SExpr to Definition
sexprToDef :: SExpr -> Either String Definition
sexprToDef (SList (SSym "data" : SSym name : cons)) = do
  constructors <- mapM parseConstructor cons
  return $ Definition
    { defName = name
    , defType = Type 0  -- data types are in Type₀ by default
    , defBody = Data (DataDef name constructors)
    }
  where
    parseConstructor (SSym cname) =
      return $ Constructor cname []
    parseConstructor (SList (SSym cname : params)) = do
      paramTerms <- mapM sexprToTerm params
      return $ Constructor cname paramTerms
    parseConstructor _ = Left "invalid constructor"

sexprToDef (SList (SSym "define" : SSym name : ty : body : [])) = do
  typ <- sexprToTerm ty
  bod <- sexprToTerm body
  return $ Definition name typ bod

sexprToDef _ = Left "expected (data ...) or (define ...)"

-- | Convert SExpr to Term
sexprToTerm :: SExpr -> Either String Term
sexprToTerm (SNum n) = Right (Con (show n))
sexprToTerm (SSym name)
  | Just n <- stripPrefix "Type" name
  , all (`elem` "0123456789") n
  = Right (Type (if null n then 0 else read n))
  | otherwise = Right (Ref name)

sexprToTerm (SList []) = Left "empty list"
-- λ abstraction
sexprToTerm (SList (SSym "λ" : SSym v : body)) = do
  b <- sexprToTerm (head body)
  return (Lam v b)
sexprToTerm (SList (SSym "λ" : SList vs : body)) = do
  vars <- mapM (\e -> case e of SSym v -> Right v; _ -> Left "λ expects variable names") vs
  b <- sexprToTerm (head body)
  return $ foldr Lam b vars
-- Π type: (Π (x : A) B)
sexprToTerm (SList (SSym "Π" : SList [SSym v, SSym ":", a] : body)) = do
  at <- sexprToTerm a
  bt <- sexprToTerm (head body)
  return (Pi v at bt)
-- Π type without colon: (Π (x A) B)
sexprToTerm (SList (SSym "Π" : SList [SSym v, a] : body)) = do
  at <- sexprToTerm a
  bt <- sexprToTerm (head body)
  return (Pi v at bt)
-- match
sexprToTerm (SList (SSym "match" : scrut : branches)) = do
  s <- sexprToTerm scrut
  brs <- mapM parseBranch branches
  return (Match s brs)
  where
    parseBranch (SList (SSym c : varsAndBody))
      | all isSymVar varsAndBody = do
          -- No bound variables, just body
          let body = last varsAndBody
              vars = map (\(SSym v) -> v) (init varsAndBody)
          b <- sexprToTerm body
          return (Branch c vars b)
      where isSymVar (SSym _) = True
            isSymVar _ = False
    parseBranch _ = Left "invalid match branch"
-- application or nested expression
sexprToTerm (SList (e : args)) = do
  fn <- sexprToTerm e
  argTerms <- mapM sexprToTerm args
  return $ foldl App fn argTerms

-- | Parse a complete definition
parseDefinition :: String -> Either String Definition
parseDefinition input = case parseSExprs input of
  Left err -> Left err
  Right [sexpr] -> sexprToDef sexpr
  Right _ -> Left "expected exactly one definition"

-- | Parse multiple definitions
parseDefinitions :: String -> Either String [Definition]
parseDefinitions input = case parseSExprs input of
  Left err -> Left err
  Right sexprs -> mapM sexprToDef sexprs

stripPrefix :: String -> String -> Maybe String
stripPrefix pref s
  | take (length pref) s == pref = Just (drop (length pref) s)
  | otherwise = Nothing
