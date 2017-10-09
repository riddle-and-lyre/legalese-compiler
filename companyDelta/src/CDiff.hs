{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE RecordWildCards #-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GADTs #-}

-- emacs haskell-mode with intero
-- C-c ! n for next flycheck error
-- C-c ! p for prev flycheck error

module CDiff where

import Debug.Trace
import Company
import Control.Applicative
import Control.Monad
import Data.Tree
import Data.Maybe
import Data.Semigroup
import Data.List (foldl1', foldl1)
import qualified Data.Map as Map
import qualified Data.Map.Merge.Strict as Merge
import qualified Data.Set as Set
import Data.Aeson (ToJSON)
import qualified Data.Text as T (unpack)

data Relation = CH Company Holder
              | CS Company Security
              | HS Holder Security
  deriving (Show, Eq)

data Diff where
  Create  :: (          Show new) =>        new -> String -> Diff
  Replace :: (Show old, Show new) => old -> new -> String -> Diff
  Update  :: (Show old, Show new) => old -> new -> String -> Diff
  Delete  :: (Show old          ) => old ->        String -> Diff
  Noop    :: (                  ) =>               String -> Diff

instance Show Diff where
  show (Create      new comment) = unwords ["Create",  show new, show comment]
  show (Replace old new comment) = unwords ["Replace", show new, show comment]
  show (Update  old new comment) = unwords ["Update",  show new, show comment]
  show (Delete  old     comment) = unwords ["Delete",  show old, show comment]
  show (Noop            comment) = unwords ["Noop",              show comment]

pruneNoops :: Tree Diff -> Maybe (Tree Diff)
pruneNoops (Node (Noop _) forest) = Nothing
pruneNoops (Node y        forest) = Just $ Node y (catMaybes $ map pruneNoops forest)

-- Recursively Diffable types
class RDiff x where
  rdiff :: x -> x -> Tree Diff

mkDiff :: (RDiff a, Show a) => String -> a -> a -> [Tree Diff] -> Tree Diff
mkDiff elName x y forest =
  let pruned = catMaybes $ pruneNoops <$> forest
  in mytrace ("mkDiff " ++ elName)
     (if length pruned > 0
      then Node (Update x y ("changed " ++ elName))
      else Node (Noop ("no change to " ++ elName))
     ) pruned

instance RDiff CompanyState where
  rdiff
    s1@(CompanyState holders1 se1 co1 holdings1)
    s2@(CompanyState holders2 se2 co2 holdings2) =
    mkDiff "CompanyState" s1 s2 [rdiff holders1 holders2
                                ,rdiff se1 se2
                                ,rdiff co1 co2
                                ,rdiff holdings1 holdings2]

instance RDiff Company where
  rdiff
    s1@(Company n1 j1 idtype1 idnum1)
    s2@(Company n2 j2 idtype2 idnum2) =
    mkDiff "Company" s1 s2 [rdiff n1 n2
                           ,rdiff j1 j2
                           ,rdiff idtype1 idtype2
                           ,rdiff idnum1 idnum2 ]
  
instance RDiff [Holder] where
  rdiff s1s s2s =
    let mergedHolders = pairBy fullname (:[]) s1s s2s
    in mkDiff "Holders" s1s s2s [ rdiff (fmap head hBefore) (fmap head hAfter)
                                | (hName,(hBefore,hAfter)) <- Map.assocs mergedHolders ]


instance RDiff Holder where
  rdiff
    s1@(Holder fullname1 idtype1 idnum1 nature1 gender1)
    s2@(Holder fullname2 idtype2 idnum2 nature2 gender2) =
    mkDiff "Holder" s1 s2 [rdiff fullname1 fullname2
                          ,rdiff idtype1 idtype2
                          ,rdiff idnum1 idnum2
                          ,rdiff nature1 nature2
                          ,rdiff gender1 gender2]


instance RDiff [Security] where
  rdiff s1s s2s =
    let mergedSecurities = pairBy (name :: Security -> String) (:[]) s1s s2s
    in mkDiff "Securities" s1s s2s [ rdiff (fmap head sBefore) (fmap head sAfter)
                                   | (sName,(sBefore,sAfter)) <- Map.assocs mergedSecurities ]

instance RDiff Security where
  rdiff s1@(Security name1 measure1)
        s2@(Security name2 measure2) =
    mkDiff "Security" s1 s2 [rdiff name1 name2]
  

instance RDiff [Holding] where
  rdiff s1s s2s =
    mkDiff "Holdings" s1s s2s [ rdiff h1 h2
                              | (hname,(h1,h2)) <- Map.assocs $ pairBy holder holds s1s s2s ]

instance RDiff Holding where
  rdiff s1@(Holding holder1 holds1)
        s2@(Holding holder2 holds2) =
    let holdingsBySN = (pairBy securityName (:[]) holds1 holds2)
    -- :: Map holderName ( Map securityName ( [HeldSecurity/before] , [HeldSecurity/after] ) )

    in mkDiff "Holding" s1 s2 [ rdiff hsBefore hsAfter
                              | (hsName,(hsBefore,hsAfter)) <- Map.assocs holdingsBySN
                              ]

ignoreDescription :: Maybe HeldSecurity -> Maybe HeldSecurity
ignoreDescription (Just r) = -- mytrace ("ignoreDescription: flattening description="++(show $ description r))
                             Just (r { description = Nothing })
ignoreDescription x = x

myconcat :: Maybe [HeldSecurity] -> Maybe HeldSecurity
myconcat Nothing = Nothing
myconcat (Just []) = Nothing
myconcat (Just hslist) = Just (foldl1' (<>) hslist)

-- HeldSecurities have either Just units or Just money but not both; this semigroup sums either way
instance Semigroup HeldSecurity where
   hs1 <> hs2 = hs2 { units = maybeSum (units hs1) (units hs2),
                      money = maybeSum (money hs1) (money hs2) }

maybeSum :: (Num a) => Maybe a -> Maybe a -> Maybe a
maybeSum Nothing _ = Nothing
maybeSum _ Nothing = Nothing
maybeSum (Just a) (Just b) = Just (a+b)

instance RDiff [HeldSecurity] where
  rdiff hs1s hs2s =
    let hsBefore = ignoreDescription $ myconcat $ Just hs1s
        hsAfter  = ignoreDescription $ myconcat $ Just hs2s
    in
      mkDiff "HeldSecurities" hs1s hs2s [rdiff hsBefore hsAfter ]
  
instance RDiff HeldSecurity where
  rdiff s1@(HeldSecurity securityName1 units1 money1 description1)
        s2@(HeldSecurity securityName2 units2 money2 description2) =
    mkDiff "HeldSecurity" s1 s2 [rdiff units1 units2
                                ,rdiff money1 money2
                                ,rdiff description1 description2 ]


instance RDiff EntityNature where
  rdiff s1@Human     s2@Corporate   = Node (Replace s1 s2 "incorporated") []
  rdiff s1@Corporate s2@Human       = Node (Replace s1 s2 "disincorporated") []
  rdiff s1@Human     s2@AI          = Node (Replace s1 s2 "uploaded") []
  rdiff s1@Corporate s2@AI          = Node (Replace s1 s2 "blockchained") []
  rdiff s1@AI        s2@Human       = Node (Replace s1 s2 "embodied") []
  rdiff s1@AI        s2@Corporate   = Node (Replace s1 s2 "downgraded") []
  rdiff s1           s2 | s1 == s2  = Node (Noop "no change to EntityNature") []
                        | otherwise = Node (Replace s1 s2 "changed somehow") []
    
instance RDiff Gender where
  rdiff s1           s2 | s1 == s2     = Node (Noop "no change to Gender") []
  rdiff s1@Male    s2@Female           = Node (Replace s1 s2 "m2f") []
  rdiff s1@Female  s2@Male             = Node (Replace s1 s2 "f2m") []
  rdiff s1         s2@Neutral          = Node (Replace s1 s2 "unsexed") []
  rdiff s1         s2@Male             = Node (Replace s1 s2 "androgened") []
  rdiff s1         s2@Female           = Node (Replace s1 s2 "estrogened") []
  rdiff s1         s2@(OtherGender og) = Node (Replace s1 s2 ("became " ++ og)) []

-- if we have an Old thing and a New thing
-- where there is a key Old.key and New.key
-- and an array of values Old.array and New.array
-- it is possible to reorganize the things into a map of key:(Maybe oldArray, Maybe newArray)

-- first we get out the key, oldArray, and newArray
           
pairBy :: (Ord b) => (a -> b) -> (a -> [c]) -> [a] -> [a] -> Map.Map b (Maybe [c], Maybe [c])
pairBy getName getKids old new =
  merge2ways (pairup old) (pairup new)
  where pairup record = Map.fromListWith (++) $ fmap (\r -> (getName r, getKids r)) record

-- if we have two maps of key:oldArray and key:newArray
-- we merge the two maps into a map of key:(Maybe oldArray, Maybe newArray).
-- we handle situations where the old does not exist or the new does not exist by setting Nothing
merge2ways oldMap newMap =
        Merge.merge
        (Merge.mapMissing (\k x -> (Just x, Nothing)))
        (Merge.mapMissing (\k y -> (Nothing, Just y)))
        (Merge.zipWithMatched (\k x y -> (Just x, Just y)))
        oldMap
        newMap
      




-- we should be thinking about certain situations in terms of relations rather than
-- blindly recursing through the CompanyState tree.

-- there are of course three relations of interest
-- CH company/holder
-- CS company/security
-- HS holder /security

-- CH create <=> HS create



instance (Show a, RDiff a) => RDiff (Maybe a) where
  rdiff Nothing Nothing   = Node (Noop "given identical Nothing inputs") []
  rdiff Nothing (Just y)  = Node (Create y "from Nothing") []
  rdiff (Just x) Nothing  = Node (Delete x   "to Nothing") []
  rdiff (Just x) (Just y) = rdiff x y

-- syntactic sugar
ndr :: (Show term, Eq term) => term -> term -> String -> Tree Diff
ndr s1 s2 str | s1 == s2  = Node (Noop ("no change")) []
              | otherwise = Node (Replace s1 s2 str)  []

instance RDiff String where
  rdiff s1 s2 = ndr s1 s2 "change string"

instance RDiff Float where
  rdiff s1 s2 = ndr s1 s2 ("change float from " ++ show s1 ++ " to " ++ show s2)
  
instance RDiff Int where
  rdiff s1 s2 = ndr s1 s2 "change int"
  
  
{-
Prelude Data.Tree> :browse Data.Tree
type Forest a = [Tree a]
data Tree a = Node {rootLabel :: a, subForest :: Forest a}
drawForest :: Forest String -> String
drawTree :: Tree String -> String
flatten :: Tree a -> [a]
levels :: Tree a -> [[a]]
unfoldForest :: (b -> (a, [b])) -> [b] -> Forest a
unfoldForestM ::
  Monad m => (b -> m (a, [b])) -> [b] -> m (Forest a)
unfoldForestM_BF ::
  Monad m => (b -> m (a, [b])) -> [b] -> m (Forest a)
unfoldTree :: (b -> (a, [b])) -> b -> Tree a
unfoldTreeM :: Monad m => (b -> m (a, [b])) -> b -> m (Tree a)
unfoldTreeM_BF :: Monad m => (b -> m (a, [b])) -> b -> m (Tree a)
-}
  
-- diffs2actions :: [Diff] -> [Action]

debugging = False
mytrace x y = if debugging then trace x y else y


