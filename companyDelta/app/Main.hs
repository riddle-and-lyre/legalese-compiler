
{-# LANGUAGE DeriveGeneric, DeriveAnyClass, OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Main where

-- mengwong: i am making progress with my haskell differ.
-- what is the haskell differ? it reads JSON snapshots of
-- before & after company state, including cap table of
-- holders and holdings, and it calculates the diffs between
-- those snapshots, much as
-- https://github.com/thsutton/aeson-diff does. then it uses
-- a simple set of logic rules implemented in native Haskell
-- to calculate the state transitions needed to go from one
-- state to the other. the output: an ordered list of
-- resolutions and agreements.

-- for aeson
import GHC.Generics
import Data.Aeson
import Data.ByteString.Lazy as BSL
import Data.ByteString.Lazy.Char8 as Char8

-- for option parsing
import Options.Applicative
import Data.Semigroup ((<>))
import Control.Monad

-- for the company data model
import Company

-- in the future, get aeson-schema to automatically produce even this parser

{-                       OPTION MANAGEMENT                    -}
{-                       OPTION MANAGEMENT                    -}
{-                       OPTION MANAGEMENT                    -}
-- https://hackage.haskell.org/package/optparse-applicative#alternative
data Options = Options { quiet :: Bool
                       , verbose :: Bool
                       , beforefilename :: String
                       , afterfilename  :: String}

optparse :: Parser Options
optparse = Options -- in order defined above
  <$> switch ( long "quiet"   <> short 'q' <> help "quiet mode" )
  <*> switch ( long "verbose" <> short 'v' <> help "verbose mode" )
  <*> argument str (metavar "before.json")
  <*> argument str (metavar "after.json.")

main :: IO ()
main = main1 =<< execParser opts
       where opts = info (optparse <**> helper) ( fullDesc
                                                  <> progDesc "compare two company states"
                                                  <> header "companyDelta" )
         
{-                               MAIN                           -}
{-                               MAIN                           -}
{-                               MAIN                           -}

main1 :: Options -> IO ()
main1 (Options quiet v beforefilename afterfilename) = do
  vprint v $ "Main runs! quiet = " ++ show quiet ++ "; verbose = " ++ show v
  vprint v $ "Main runs! infile = " ++ beforefilename ++ "; outfile = " ++ afterfilename
  vprint v $ "potato = " ++ potato -- exported from the Company library

  beforefile <- BSL.readFile beforefilename
  vprint v $ "beforefile: read " ++ show (BSL.length beforefile) ++ " bytes of input"
  afterfile <- BSL.readFile afterfilename
  vprint v $ "afterfile: read " ++ show (BSL.length afterfile) ++ " bytes of input"

  let beforeJSON = eitherDecode beforefile :: Either String CompanyState
  vprint True $ case beforeJSON of
    (Left  parseError)  -> "beforeJSON error: "  ++ parseError
    (Right parseOutput) -> "beforeJSON output: " ++ show(parseOutput)

  let afterJSON = eitherDecode afterfile :: Either String CompanyState
  vprint True $ case afterJSON of
    (Left  parseError)  -> "afterJSON error: "  ++ parseError
    (Right parseOutput) -> "afterJSON output: " ++ show(parseOutput)


{-                               input json parsing                           -}

{-                               utilities                           -}

-- verbose debug trace
vprint :: Bool -> String -> IO ()
vprint v s = when v $ Prelude.putStrLn s
