-- 信风 POC Test Runner
-- Usage: cabal test
-- Each test case: (filepath, [expected-to-pass], [expected-to-fail])
-- Empty pass list + empty fail list = just check that it parses

module Main where

import Xinfeng.Syntax
import Xinfeng.Parser
import Xinfeng.Checker
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr)
import System.Environment (getArgs)
import Data.List (isInfixOf)

-- | A single test case
data TestCase = TestCase
  { testFile  :: FilePath
  , passNames :: [String]  -- definitions expected to type-check
  , failNames :: [String]  -- definitions expected to fail
  }

-- | Test suite definition
tests :: [TestCase]
tests =
  [ TestCase "../test-min.xf"    ["Bool"]      []
  , TestCase "../test-id.xf"     ["Bool","id"] []
  , TestCase "../test-basic.xf"  ["Bool","not"] []
  , TestCase "../test-match.xf"  ["Bool","id"] []
  , TestCase "../test-errors.xf" ["Bool","id","const_true"]
                                 ["broken","partial"]
  ]

-- | Run all tests
main :: IO ()
main = do
  args <- getArgs
  let filterName = if null args then "" else head args
  let selected = if null filterName
                 then tests
                 else filter (\(TestCase f _ _) -> filterName `isInfixOf` f) tests
  results <- mapM (runTest filterName) selected
  let passed = length (filter id results)
      failed = length (filter not results)
      total  = length results
  putStrLn $ "\n📊 " ++ show total ++ " test files, "
         ++ show passed ++ " passed, "
         ++ show failed ++ " failed"
  if failed > 0 then exitFailure else exitSuccess

-- | Run a single test file
runTest :: String -> TestCase -> IO Bool
runTest filterName tc = do
  let file = testFile tc
  content <- readFile file
  let results = parseCheck content
  case results of
    Left err -> do
      putStrLn $ "❌ " ++ file ++ " — parse error: " ++ err
      return False
    Right defResults -> do
      let expectedPass = passNames tc
          expectedFail = failNames tc
          actualPass   = [n | (n, Right _) <- defResults]
          actualFail   = [n | (n, Left _)  <- defResults]
          unexpectedFail = [n | n <- actualFail, n `notElem` expectedFail]
          missingPass    = [n | n <- expectedPass, n `notElem` actualPass]
          unexpectedPass = [n | n <- actualPass, n `notElem` expectedPass]
          missingFail    = [n | n <- expectedFail, n `notElem` actualFail]
      if null unexpectedFail && null missingPass
         && null unexpectedPass && null missingFail
        then do
          putStrLn $ "✅ " ++ file
          mapM_ (\n -> putStrLn $ "  ✓ " ++ n) actualPass
          return True
        else do
          putStrLn $ "❌ " ++ file
          mapM_ (\n -> putStrLn $ "  ✗ expected to pass but failed: " ++ n) missingPass
          mapM_ (\n -> putStrLn $ "  ✗ expected to fail but passed: " ++ n) unexpectedPass
          mapM_ (\n -> putStrLn $ "  ✗ failed but not expected: " ++ n) unexpectedFail
          mapM_ (\n -> putStrLn $ "  ✗ expected to fail but passed: " ++ n) missingFail
          return False

parseCheck :: String -> Either String [(String, Either TypeError ())]
parseCheck input = do
  defs <- parseDefinitions input
  return $ checkWithContext [] defs

checkWithContext :: Context -> [Definition] -> [(String, Either TypeError ())]
checkWithContext _ [] = []
checkWithContext ctx (d : rest) =
  let result = check ctx (defBody d) (defType d)
      ctx' = (defName d, (defType d, defBody d)) : ctx
  in (defName d, result) : checkWithContext ctx' rest
