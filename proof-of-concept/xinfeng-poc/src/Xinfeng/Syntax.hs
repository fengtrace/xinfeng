module Xinfeng.Syntax where

-- | Universe levels
type Level = Int

-- | Names are plain strings in the core
type Name = String

-- | Constructor definition: name and parameter types
data Constructor = Constructor
  { conName :: Name
  , conParams :: [Term]
  } deriving (Show, Eq)

-- | Inductive data type definition
data DataDef = DataDef
  { dataName :: Name
  , dataCons :: [Constructor]
  } deriving (Show, Eq)

-- | Match branch: constructor pattern with bound variables and body
data Branch = Branch
  { branchCon :: Name
  , branchVars :: [Name]
  , branchBody :: Term
  } deriving (Show, Eq)

-- | Core term type — everything is a term
data Term
  = Type Level           -- ^ Universe: Type₀, Type₁, ...
  | Pi Name Term Term    -- ^ Dependent function: (x : A) → B
  | Lam Name Term        -- ^ Lambda: λx. t
  | App Term Term        -- ^ Application: f a
  | Data DataDef         -- ^ Inductive data type definition
  | Match Term [Branch]  -- ^ Pattern matching: match scrutinee { branches }
  | Con Name             -- ^ Constructor reference: True, False, Nil, Cons...
  | Ref Name             -- ^ Definition reference: append, Bool, Vec...
  deriving (Show, Eq)

-- | A definition: a name, its claimed type, and its body
data Definition = Definition
  { defName :: Name
  , defType :: Term
  , defBody :: Term
  } deriving (Show, Eq)

-- | The kernel context: maps names to their (type, body)
type Context = [(Name, (Term, Term))]
