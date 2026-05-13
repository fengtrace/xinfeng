module Xinfeng.Eval where

import Xinfeng.Syntax

-- | Evaluate a term to weak head normal form
eval :: Context -> Term -> Term
eval ctx = whnf
  where
    whnf (Ref name) = case lookup name ctx of
      Just (_, Data _) -> Ref name  -- don't expand data types in eval
      Just (_, body) -> whnf body
      Nothing -> Ref name  -- unknown name, leave as-is
    whnf (App f a) = case whnf f of
      Lam x body -> whnf (subst x a body)
      f' -> App f' a
    whnf (Match scrut branches) = case whnf scrut of
      -- Constructor application: peel off the chain of App to find Con
      _ | Just (cname, args) <- collectConApp (whnf scrut) ->
        case lookupBranch cname branches of
          Just (vars, body) ->
            whnf (applySubst (zip vars args) body)
          Nothing -> Match (whnf scrut) branches
      scrut' -> Match scrut' branches
    whnf (Pi x a b) = Pi x (whnf a) (whnf b)
    whnf t = t

    lookupBranch _ [] = Nothing
    lookupBranch name (Branch c vars body : rest)
      | c == name = Just (vars, body)
      | otherwise = lookupBranch name rest

-- | Collect constructor applications.
-- App (App (Con "Cons") h) t  -->  Just ("Cons", [h, t])
collectConApp :: Term -> Maybe (Name, [Term])
collectConApp (Con n) = Just (n, [])
collectConApp (App f a) = case collectConApp f of
  Just (n, args) -> Just (n, args ++ [a])
  Nothing -> Nothing
collectConApp _ = Nothing

-- | Substitute variable x with term s in term t
subst :: Name -> Term -> Term -> Term
subst x s t = case t of
  Ref y | y == x -> s
  Ref y -> Ref y
  Lam y b | y == x -> Lam y b  -- shadowed
  Lam y b -> Lam y (subst x s b)
  Pi y a b | y == x -> Pi y (subst x s a) b  -- shadowed
  Pi y a b -> Pi y (subst x s a) (subst x s b)
  App f a -> App (subst x s f) (subst x s a)
  Match scrut branches ->
    Match (subst x s scrut) (map substBranch branches)
  Data d -> Data d
  Con n -> Con n
  Type n -> Type n
  where
    substBranch (Branch c vars body)
      | x `elem` vars = Branch c vars body  -- shadowed
      | otherwise = Branch c vars (subst x s body)

-- | Apply a list of substitutions simultaneously
applySubst :: [(Name, Term)] -> Term -> Term
applySubst [] t = t
applySubst ((x, s) : rest) t = applySubst rest (subst x s t)

-- | Normalize a term to full normal form
normalize :: Context -> Term -> Term
normalize ctx t = case eval ctx t of
  Lam x b -> Lam x (normalize ctx b)
  Pi x a b -> Pi x (normalize ctx a) (normalize ctx b)
  App f a -> App (normalize ctx f) (normalize ctx a)
  Match scrut branches ->
    Match (normalize ctx scrut)
         (map (\(Branch c vs b) -> Branch c vs (normalize ctx b)) branches)
  Ref n -> case lookup n ctx of
    Just (_, Data _) -> Ref n  -- don't expand data type definitions
    Just (_, body) -> normalize ctx body
    Nothing -> Ref n
  Data d -> Data d
  Con n -> Con n
  Type n -> Type n
