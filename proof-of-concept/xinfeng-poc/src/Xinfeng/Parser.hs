module Xinfeng.Parser where

import Xinfeng.Syntax
import Data.Char (isAlpha, isDigit, isAlphaNum, isSpace)

-- ============================================================
-- Lexer: String → [Token]
-- ============================================================

data Token
  = TokIdent String
  | TokNum Int
  | TokArrow           -- -> or →
  | TokColon           -- :
  | TokEquals          -- =
  | TokPipe            -- |
  | TokLambda          -- \
  | TokDot             -- .
  | TokLParen          -- (
  | TokRParen          -- )
  | TokNewline         -- \n
  | TokEOF
  deriving (Show, Eq)

lexer :: String -> [Token]
lexer = reverse . lex' []
  where
    spaceOnly c = c == ' ' || c == '\t'
    lex' acc [] = TokEOF : acc
    lex' acc s@(c : rest)
      | c == '\n'          = lex' (TokNewline : acc) rest
      | c == '\r'          = lex' (TokNewline : acc) rest
      | spaceOnly c        = lex' acc (dropWhile spaceOnly s)
      | c == '-' && take 1 rest == "-" =
                                lex' acc (dropWhile (/= '\n') s)
      | c == ';' && take 1 rest == ";" =
                                lex' acc (dropWhile (/= '\n') s)
      | isAlpha c || c == '_'
        = let (id, rest') = span (\x -> isAlphaNum x || x == '_' || x == '\'') s
          in lex' (TokIdent id : acc) rest'
      | isDigit c
        = let (n, rest') = span isDigit s
          in lex' (TokNum (read n) : acc) rest'
      | c == '-' && take 1 rest == ">"
        = lex' (TokArrow : acc) (drop 2 s)
      | c == '→'           = lex' (TokArrow : acc) rest
      | c == ':'           = lex' (TokColon : acc) rest
      | c == '='           = lex' (TokEquals : acc) rest
      | c == '|'           = lex' (TokPipe : acc) rest
      | c == '\\'          = lex' (TokLambda : acc) rest
      | c == '.'           = lex' (TokDot : acc) rest
      | c == '('           = lex' (TokLParen : acc) rest
      | c == ')'           = lex' (TokRParen : acc) rest
      | c == '\n'          = lex' (TokNewline : acc) rest
      | c == '\r'          = lex' (TokNewline : acc) rest
      | otherwise          = lex' acc rest  -- skip unknown

-- ============================================================
-- Parser utilities
-- ============================================================

-- Skip newline tokens (used between top-level items)
eatNewlines :: [Token] -> [Token]
eatNewlines (TokNewline : rest) = eatNewlines rest
eatNewlines ts = ts

-- Skip at most one newline (used between type sig and fun body)
skipOneNewline :: [Token] -> [Token]
skipOneNewline (TokNewline : rest) = rest
skipOneNewline ts = ts

-- ============================================================
-- Top-level definition parser
-- ============================================================

-- | Token list → [Definition]
parseDefinitions :: String -> Either String [Definition]
parseDefinitions input =
  case parseTopLevel (lexer input) of
    Left err -> Left err
    Right (defs, rest) -> case rest of
      (TokEOF : _) -> Right defs
      [] -> Right defs
      _ -> Left ("unexpected tokens after definitions: " ++ show (take 5 rest))

parseTopLevel :: Parser [Definition]
parseTopLevel = go []
  where
    go acc [] = Right (reverse acc, [])
    go acc (TokEOF : _) = Right (reverse acc, [])
    go acc ts@(TokNewline : _) = go acc (eatNewlines ts)
    go acc ts = do
      (def, rest) <- parseDef ts
      go (def : acc) (eatNewlines rest)

-- ============================================================
-- Single definition
-- ============================================================

-- Possible forms:
--   data Bool = True | False
--   not : Bool -> Bool / not b = match b ...
--   id : (a : Type0) -> a -> a / id a x = x
parseDef :: Parser Definition
parseDef (TokIdent "data" : rest) = parseDataDef rest
parseDef ts = parseFunDef ts

-- ============================================================
-- Data definition: data Name = Con1 | Con2
-- ============================================================

parseDataDef :: Parser Definition
parseDataDef (TokIdent name : TokEquals : rest) = do
  (cons, rest') <- parseConList rest
  let def = Definition name (Type 0) (Data (DataDef name cons))
  Right (def, rest')
parseDataDef ts =
  Left ("expected 'data Name = ...', got " ++ show (take 5 ts))

parseConList :: Parser [Constructor]
parseConList (TokIdent name : rest) = do
  (more, rest') <- parseConRest rest
  Right (Constructor name [] : more, rest')
parseConList ts =
  Left ("expected constructor name, got " ++ show (take 3 ts))

parseConRest :: Parser [Constructor]
parseConRest (TokPipe : rest) = parseConList rest
parseConRest (TokNewline : rest) = Right ([], rest)
parseConRest ts = Right ([], ts)

-- ============================================================
-- Function definition: type sig + body
-- ============================================================

-- Two forms:
--   1.  name : type       (type signature seen first)
--       name args = body  (body follows on next line(s))
--   2.  name args = body  (bare function, will try to infer type)

parseFunDef :: Parser Definition
parseFunDef (TokIdent name : TokColon : rest) = do
  -- Type signature: name : type
  (ty, rest1) <- parseType rest
  let rest1' = skipOneNewline (eatNewlines rest1)
  case rest1' of
    (TokIdent name' : _) | name' == name -> do
      -- Same name → body follows: name args = expr
      (body, rest2) <- parseFunBody rest1'
      Right (Definition name ty body, rest2)
    _ ->
      -- Type signature without matching body
      Left ("function '" ++ name ++ "' has a type signature but no definition body")
parseFunDef (TokIdent name : rest) = do
  -- Bare function definition, infer type
  (body, rest') <- parseFunBody (TokIdent name : rest)
  Right (Definition name (Type 0) body, rest')
parseFunDef ts =
  Left ("expected 'data' or function definition, got " ++ show (take 5 ts))

-- | Parse: name [arg arg ...] = expr
parseFunBody :: Parser Term
parseFunBody (TokIdent _fname : rest) = go [] rest
  where
    go :: [String] -> [Token] -> Either String (Term, [Token])
    go revArgs (TokEquals : rest') = do
      (body, rest'') <- parseExpr rest'
      let lam = foldr Lam body (reverse revArgs)
      Right (lam, rest'')
    go revArgs (TokIdent arg : rest') = go (arg : revArgs) rest'
    go _ ts = Left ("expected '=' after function name, got " ++ show (take 3 ts))
parseFunBody ts =
  Left ("expected function name, got " ++ show (take 3 ts))

-- ============================================================
-- Type parser
-- ============================================================

-- Types: A → B, (x : A) → B, Type0, (Type)
parseType :: Parser Term
parseType ts = do
  (left, rest) <- parsePiBinder ts
  case rest of
    (TokArrow : rest') -> do
      -- A → B: right-associative
      (right, rest'') <- parseType rest'
      case left of
        Pi x dom _ -> Right (Pi x dom right, rest'')
        _          -> Right (Pi "_" left right, rest'')
    _ -> Right (left, rest)

-- | Parse Pi binder or type atom
--   (x : A) → B  (dependent Pi)
--   (Type)       (parenthesized type)
--   Atom         (simple type)
parsePiBinder :: Parser Term
parsePiBinder (TokLParen : TokIdent name : TokColon : rest) = do
  -- (name : Dom) → Cod  — dependent Pi
  (dom, rest1) <- parseType rest
  case rest1 of
    (TokRParen : TokArrow : rest3) -> do
      (cod, rest4) <- parseType rest3
      Right (Pi name dom cod, rest4)
    (TokRParen : rest3) ->
      -- (name : Dom) without arrow — parseType above will handle →
      Right (Pi name dom (Type 0), rest3)
    _ -> Left ("expected ')' after Pi binder domain, got " ++ show (take 3 rest1))
parsePiBinder (TokLParen : rest) = do
  -- (Type) — parenthesized type
  (inner, rest1) <- parseType rest
  case rest1 of
    (TokRParen : rest2) -> Right (inner, rest2)
    _ -> Left ("expected ')' after type, got " ++ show (take 3 rest1))
parsePiBinder ts = parseAtomicType ts

-- | Parse an atomic type: Type0, Type1, name, number
parseAtomicType :: Parser Term
parseAtomicType (TokIdent "Type0" : rest) = Right (Type 0, rest)
parseAtomicType (TokIdent "Type1" : rest) = Right (Type 1, rest)
parseAtomicType (TokIdent s : rest)
  | Just n <- stripPrefix' "Type" s, all isDigit n =
      Right (Type (if null n then 0 else read n), rest)
parseAtomicType (TokIdent name : rest) = Right (Ref name, rest)
parseAtomicType (TokNum n : rest) = Right (Con (show n), rest)
parseAtomicType ts =
  Left ("expected type, got " ++ show (take 5 ts))

-- ============================================================
-- Expression parser
-- ============================================================

parseExpr :: Parser Term
parseExpr ts = parseLambda ts

-- | Lambda: \x. body  (also handles \x . body since lexer produces TokDot either way)
parseLambda :: Parser Term
parseLambda (TokLambda : TokIdent v : TokDot : rest) = do
  (body, rest') <- parseExpr rest
  Right (Lam v body, rest')
parseLambda ts = parseMatch ts

-- | Match: match expr | pat -> body | ...
parseMatch :: Parser Term
parseMatch (TokIdent "match" : rest) = do
  (scrut, rest1) <- parseApp rest
  let rest1' = eatNewlines rest1
  case rest1' of
    (TokPipe : _) -> do
      (branches, rest2) <- parseBranches rest1'
      Right (Match scrut branches, rest2)
    _ -> Left ("expected '|' after match expression, got " ++ show (take 3 rest1'))
parseMatch ts = parseApp ts

-- | Branches: | Con -> body | Con -> body
parseBranches :: Parser [Branch]
parseBranches (TokPipe : rest) = do
  (branch, rest') <- parseOneBranch rest
  (more, rest'') <- parseBranches rest'
  Right (branch : more, rest'')
parseBranches (TokNewline : rest) = parseBranches rest
parseBranches ts = Right ([], ts)

parseOneBranch :: Parser Branch
parseOneBranch (TokIdent con : rest) = do
  let (vars, rest1) = spanVars rest
  case rest1 of
    (TokArrow : rest2) -> do
      (body, rest3) <- parseExpr rest2
      Right (Branch con [v | TokIdent v <- vars] body, rest3)
    _ -> Left ("expected '->' after branch pattern for '" ++ con ++ "'")
  where
    spanVars :: [Token] -> ([Token], [Token])
    spanVars (TokIdent v : rest') =
      let (vs, r) = spanVars rest'
      in (TokIdent v : vs, r)
    spanVars ts = ([], ts)
parseOneBranch ts =
  Left ("expected constructor name after '|', got " ++ show (take 3 ts))

-- | Application: f a b c (left-associative)
parseApp :: Parser Term
parseApp ts = do
  (left, rest) <- parseAtom ts
  parseAppRest left rest

parseAppRest :: Term -> Parser Term
parseAppRest lhs []                 = Right (lhs, [])
parseAppRest lhs (TokArrow : rest)     = Right (lhs, TokArrow : rest)
parseAppRest lhs (TokPipe : rest)      = Right (lhs, TokPipe : rest)
parseAppRest lhs (TokEquals : rest)    = Right (lhs, TokEquals : rest)
parseAppRest lhs (TokColon : rest)     = Right (lhs, TokColon : rest)
parseAppRest lhs (TokRParen : rest)    = Right (lhs, TokRParen : rest)
parseAppRest lhs (TokLambda : rest)    = Right (lhs, TokLambda : rest)
parseAppRest lhs (TokEOF : _)          = Right (lhs, [])
parseAppRest lhs (TokNewline : rest) = Right (lhs, TokNewline : rest)  -- stop at newlines
parseAppRest lhs ts = do
  (rhs, rest) <- parseAtom ts
  parseAppRest (App lhs rhs) rest

-- | Atomic expression: name, number, (expr), constructor
parseAtom :: Parser Term
parseAtom (TokIdent "True" : rest)  = Right (Con "True", rest)
parseAtom (TokIdent "False" : rest) = Right (Con "False", rest)
parseAtom (TokIdent name : rest)    = Right (Ref name, rest)
parseAtom (TokNum n : rest)         = Right (Con (show n), rest)
parseAtom (TokLParen : rest) = do
  (expr, rest1) <- parseExpr rest
  case rest1 of
    (TokRParen : rest2) -> Right (expr, rest2)
    _ -> Left ("expected ')' after expression, got " ++ show (take 3 rest1))
parseAtom ts = Left ("expected expression, got " ++ show (take 5 ts))

-- ============================================================
-- Parser type alias and helpers
-- ============================================================

type Parser a = [Token] -> Either String (a, [Token])

stripPrefix' :: String -> String -> Maybe String
stripPrefix' [] s = Just s
stripPrefix' (p : ps) (c : cs) | p == c = stripPrefix' ps cs
stripPrefix' _ _ = Nothing
