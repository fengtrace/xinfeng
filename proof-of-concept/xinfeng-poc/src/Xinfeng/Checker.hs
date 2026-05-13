module Xinfeng.Checker where

import Xinfeng.Syntax
import Xinfeng.Eval
import qualified Data.List as List

-- | Type checking error
data TypeError
  = TypeMismatch Term Term Term Term
  | UniverseMismatch Level Level
  | NotAFunctionType Term
  | UnknownName Name
  | InvalidDataType Name
  | MatchBranchMismatch Name Term Term
  | Other String
  deriving (Show, Eq)

-- | Type check a term against a claimed type
check :: Context -> Term -> Term -> Either TypeError ()
check ctx term ty = do
  let ty' = normaliseType ctx ty
  case (term, ty') of
    -- Typeₙ : Typeₙ₊₁
    (Type n, Type m)
      | m == n + 1 -> Right ()
      | otherwise -> Left (UniverseMismatch (n+1) m)

    -- (x : A) → B : Typeₘ
    (Pi x a b, Type m) -> do
      aTy <- inferType ctx a
      case normaliseType ctx aTy of
        Type _ -> do
          let ctx' = extendCtx ctx x a
          bTy <- inferType ctx' b
          case normaliseType ctx' bTy of
            Type _ -> Right ()
            _ -> Left (Other "codomain of Pi must be a Type")
        _ -> Left (Other "domain of Pi must be a Type")

    -- λx. b : (x : A) → B
    (Lam x body, Pi x' a b) -> do
      let ctx' = extendCtx ctx x a
      check ctx' body b

    -- (data D = C1 ... Cn) : Type₀
    (Data d, Type 0) -> do
      mapM_ (checkConstructor ctx d) (dataCons d)
      Right ()

    -- Match: check scrutinee is a data type, then check branches
    (Match scrut branches, resultTy) -> do
      scrutTy <- inferType ctx scrut
      case normaliseType ctx scrutTy of
        Ref dname -> do
          case List.lookup dname ctx of
            Just (_, Data (DataDef _ cons)) -> do
              mapM_ (checkBranch ctx resultTy cons) branches
              checkCoverage cons branches
              Right ()
            Just _ -> Left (Other (dname ++ " is not a data type"))
            Nothing -> Left (UnknownName dname)
        _ -> Left (Other "match scrutinee must be of a data type")

    -- Anything else: infer the type and compare
    _ -> do
      actualTy <- inferType ctx term
      let actualNorm = normaliseType ctx actualTy
          claimedNorm = normaliseType ctx ty
      if alphaEq actualNorm claimedNorm
        then Right ()
        else Left (TypeMismatch claimedNorm actualNorm term ty)

-- | Infer the type of a term
inferType :: Context -> Term -> Either TypeError Term
inferType ctx term = case term of
  Type n -> Right (Type (n + 1))

  Ref name -> case List.lookup name ctx of
    Just (ty, _) -> Right ty
    Nothing -> case findConstructor ctx name of
      Right (dname, _) -> Right (Ref dname)
      Left _ -> Left (UnknownName name)

  Con name -> do
    (dataName, _) <- findConstructor ctx name
    Right (Ref dataName)

  App f a -> do
    fTy <- inferType ctx f
    case normaliseType ctx fTy of
      Pi x aTy bTy -> do
        check ctx a aTy
        Right (subst x a bTy)
      other -> Left (NotAFunctionType other)

  Lam x body ->
    Left (Other "cannot infer type of lambda without domain annotation")

  Pi x a b -> do
    aTy <- inferType ctx a
    case normaliseType ctx aTy of
      Type _ -> do
        let ctx' = extendCtx ctx x a
        bTy <- inferType ctx' b
        case normaliseType ctx' bTy of
          Type _ -> Right (Type 0)
          _ -> Left (Other "codomain of Pi must be a Type")
      _ -> Left (Other "domain of Pi must be a Type")

  Data d -> Right (Type 0)

  Match scrut branches -> do
    scrutTy <- inferType ctx scrut
    case normaliseType ctx scrutTy of
      Ref dname -> case List.lookup dname ctx of
        Just (_, Data (DataDef _ cons)) -> do
          case branches of
            (Branch c vars body : _) -> do
              (_, Constructor _ paramTys) <- findConstructor ctx c
              let ctx' = foldr (\(v, t) -> extendCtx' v t) ctx
                    (zip vars paramTys)
              inferType ctx' body
            [] -> Left (Other "match with no branches")
        Just _ -> Left (Other (dname ++ " is not a data type"))
        Nothing -> Left (UnknownName dname)
      _ -> Left (Other "match scrutinee must be of a data type")

  _ -> Left (Other "cannot infer type")

-- | Check that a constructor is well-formed
checkConstructor :: Context -> DataDef -> Constructor -> Either TypeError ()
checkConstructor ctx _ (Constructor _ params) =
  mapM_ (\p -> inferType ctx p >> Right ()) params

-- | Check a match branch
checkBranch :: Context -> Term -> [Constructor] -> Branch -> Either TypeError ()
checkBranch ctx resultTy cons (Branch c vars body) = do
  (_, Constructor _ paramTys) <- findConstructor ctx c
  let ctx' = foldr (\(v, t) -> extendCtx' v t) ctx
        (zip vars paramTys)
  check ctx' body resultTy

-- | Check that all constructors are covered
checkCoverage :: [Constructor] -> [Branch] -> Either TypeError ()
checkCoverage cons branches = do
  let conNames = map conName cons
      branchNames = map branchCon branches
      missing = filter (`notElem` branchNames) conNames
  if null missing
    then Right ()
    else Left (Other ("missing branches: " ++ unwords missing))

-- | Find a constructor in the context
findConstructor :: Context -> Name -> Either TypeError (Name, Constructor)
findConstructor ctx name = case go ctx of
  Just r -> Right r
  Nothing -> Left (UnknownName name)
  where
    go [] = Nothing
    go ((_, (_, Data (DataDef dname cons))) : rest) =
      case filter (\c -> conName c == name) cons of
        (c:_) -> Just (dname, c)
        [] -> go rest
    go (_ : rest) = go rest

-- | Normalize a type
normaliseType :: Context -> Term -> Term
normaliseType ctx t = normalize ctx t

-- | Alpha equivalence (structural equality)
alphaEq :: Term -> Term -> Bool
alphaEq (Type n) (Type m) = n == m
alphaEq (Pi x a b) (Pi y a' b') = alphaEq a a' && alphaEq b b'
alphaEq (Lam x b) (Lam y b') = alphaEq b b'
alphaEq (App f a) (App f' a') = alphaEq f f' && alphaEq a a'
alphaEq (Ref n) (Ref m) = n == m
alphaEq (Con n) (Con m) = n == m
alphaEq (Data d1) (Data d2) = dataName d1 == dataName d2
  && length (dataCons d1) == length (dataCons d2)
  && and (zipWith conEq (dataCons d1) (dataCons d2))
alphaEq (Match s1 b1) (Match s2 b2) = alphaEq s1 s2
  && and (zipWith branchEq b1 b2)
alphaEq _ _ = False

conEq :: Constructor -> Constructor -> Bool
conEq (Constructor n1 p1) (Constructor n2 p2) =
  n1 == n2 && and (zipWith alphaEq p1 p2)

branchEq :: Branch -> Branch -> Bool
branchEq (Branch c1 _ b1) (Branch c2 _ b2) =
  c1 == c2 && alphaEq b1 b2

-- | Extend context with a new binding
extendCtx :: Context -> Name -> Term -> Context
extendCtx ctx x ty = (x, (ty, ty)) : ctx

extendCtx' :: Name -> Term -> Context -> Context
extendCtx' x ty ctx = (x, (ty, ty)) : ctx
