import Data.Array
import Data.List
import Debug.Trace
import Control.Monad (liftM)
    
data Occupant = Black    | White
              | BlackBig | WhiteBig
              | Empty
                deriving (Show, Eq)

showO Black    = "o" ; showO White    = "x"
showO BlackBig = "O" ; showO WhiteBig = "X"
showO _     = " "

type Cell = (Int,Int)
              
type Board = Array Cell Occupant

boardSize = 4
coordinates = ((1,1), (boardSize,boardSize))

mkBoard :: [ Occupant ] -> Board
mkBoard = array coordinates . zip (range coordinates)

board1 :: Board
board1 = mkBoard [ Empty, Black, Empty, White
                 , Black, Black, White, White
                 , Empty, White, Empty, White
                 , White, White, White, Black
                 ]

data Verbosity = Regular | Verbose deriving Eq

showBoard :: Board -> Verbosity -> String
showBoard board v = let eachf = if v == Verbose then verbose else eachelem
                    in allrows eachf
    where allrows ef   = unlines [ eachrow ef y | y <- [y_origin .. y_max] ]
          eachrow ef y = concat  [ ef       x y | x <- [x_origin .. x_max] ]
          verbose  x y = show (x,y) ++ "=" ++ (show $ board ! (x,y))
          eachelem x y = showO $ board ! (x,y)
          x_origin = (snd.fst $ bounds board)
          x_max    = (snd.snd $ bounds board)
          y_origin = (fst.fst $ bounds board)
          y_max    = (fst.snd $ bounds board)

printBoard :: Board -> IO ()
printBoard board = putStrLn $ showBoard board Regular
           
adjacent1d :: Int -> [Int]
adjacent1d a
  | a < 1          = error "We presume index starts at 1"
  | a > boardSize  = error "Exceeds boardsize"
  | a == 1         = [a+1]
  | a == boardSize = [a-1]
  | otherwise      = [a+1,a-1]
  
adjacent2d :: Cell -> [Cell]
adjacent2d (a,b) = [(x,b) | x <- adjacent1d a] ++ [(a,y) | y <- adjacent1d b]

adjacentSameOccupant :: Board -> Cell -> [Cell]
adjacentSameOccupant b i = filter (\ii -> b ! ii == b ! i) $ adjacent2d i

-- set subtraction: y minus x
takeNew :: (Eq a) => [a] -> [a] -> [a]
takeNew x y = [ z | z<-y, not $ elem z x]

buildUnit :: Board -> [Cell] -> [Cell]
buildUnit a [] = trace "buildUnit base case, returning empty list" []
buildUnit a xs = trace ("buildUnit: called with " ++ (show $ length xs) ++ " xs: " ++ show xs ++ "; broken hasNew = " ++ (show (break (hasNew a xs) xs)))
                 (if null secondPart
                  then trace ("buildUnit: no new adjacent cells have been found. returning " ++ show xs) xs
                  else trace ("buildUnit: investigating the new cells " ++ show secondPart) (buildUnit a (firstPart ++ secondPart ++ takeNew xs newOnes))
                 )
  where firstPart  = fst (break (hasNew a xs) xs)
        secondPart = snd (break (hasNew a xs) xs)
        newOnes = trace ("  newOnes = " ++ (show $ adjacentSameOccupant a (head secondPart))) (adjacentSameOccupant a (head secondPart))

hasNew :: Board -> [Cell] -> Cell -> Bool
hasNew a b c = (if not (null (takeNew b (adjacentSameOccupant a c)))
                    then trace ("    hasNew: returning True because " ++ show c ++ " has an adjacent cell that isn't already known in " ++ show b)  True
                    else False
                   -- else trace ("    hasNew: called with " ++ show b ++ " / " ++ show c ++ "; returning False") False
                   )

-- new code by Meng below
type Group = [Cell]
               
data CountedBoard = CountedBoard { board :: Board
                                 ,  orig :: Board
                                 , white :: [ Group ]
                                 , black :: [ Group ] }
                    deriving (Show);
                  
printCB :: CountedBoard -> IO ()
printCB cb = do
  putStrLn "-------------- RESULTS -----------"
  putStrLn $ unlines $ concat $ do
    (color, cstring) <- [(white, "white"), (black, "black")]
    let groups = color cb
    return $ do
      g <- groups
      return $ "- there is a "++ (show $ length g) ++ "-element " ++ cstring ++ " group at " ++ show g
  printBoard $ board cb
                  
-- count all the groups in a board
countBoard :: Board -> CountedBoard
countBoard b = revBoard CountedBoard { board = b
                                     ,  orig = b
                                     , white = []
                                     , black = [] }

-- repeatedly revise the board until no small blacks or whites remain; all whites and blacks should be big.
revBoard :: CountedBoard -> CountedBoard
revBoard cb = let foundSmalls = findSmalls (board cb)
              in 
                if null foundSmalls
                then cb
                else let (xy,e) = head foundSmalls
                     in
                       trace ("revBoard found a " ++ show e ++ " at " ++ show xy ++ "; finding all connected cells.")
                             (let foundGroup = findGroup (board cb,[]) [xy]
                              in
                                trace (showBoard (bigBoard (orig cb) foundGroup) Regular)
                                revBoard $ addGroup cb foundGroup)

-- we mark found groups by uppercasing the representing character, o->O, x->X
biglify :: Board -> Cell -> (Cell, Occupant)
biglify b xy = (xy, embiggen (b ! xy))
                                             
embiggen :: Occupant -> Occupant
embiggen White = WhiteBig
embiggen Black = BlackBig
embiggen x = x

unbiggen :: Occupant -> Occupant
unbiggen WhiteBig = White
unbiggen BlackBig = Black
unbiggen x = x

-- so any lowercase o or x must mean the group hasn't been dealt with yet
findSmalls :: Board -> [(Cell,Occupant)]
findSmalls b = filter (\(_,o) -> o == Black || o == White) (assocs b)

-- basically same as adjacentSameOccupant -- which of c's neighbours are connected?
adjacentMatch :: Board -> Cell -> [Cell]
adjacentMatch b c = let small = unbiggen (b ! c)
                    in filter (\ii -> b ! ii == small) (adjacent2d c)
               
-- a group is a set of connected cells.
-- given a board, a group in progress, a list of leads, investigate each lead until no leads remain.
-- mark off the completed cells on the board by uppercasing them.
-- return the indices of the group.
findGroup :: (Board,Group) -> [Cell] -> Group
findGroup (b,g) [] = reverse $ nub g
findGroup (b,g) leads =
    let newBoard = bigBoard b leads
        newleads = concatMap (adjacentMatch newBoard) leads
    in findGroup (newBoard, leads ++ g) newleads

-- given an existing board and a new group, revise the board accordingly.
addGroup :: CountedBoard -> Group -> CountedBoard
addGroup cb g =
    let newBoard = bigBoard (board cb) g
    in
      if (board cb ! head g) == White
      then cb { board = newBoard, white = g : white cb }
      else cb { board = newBoard, black = g : black cb }

-- uppercase the cells in the given group
bigBoard :: Board -> Group -> Board           
bigBoard b group = b // map (biglify b) group

main = do
  printCB $! countBoard board1
         
{-
*Main> printCB $! countBoard board1
revBoard found a Black at (1,2); finding all connected cells.
revBoard uncovered 3 connected cells:
 O x
OOxx
 x x
xxxo

revBoard found a White at (1,4); finding all connected cells.
revBoard uncovered 4 connected cells:
 O x
OOxx
 X x
XXXo

revBoard found a White at (3,2); finding all connected cells.
revBoard uncovered 4 connected cells:
 O X
OOXX
 X X
XXXo

revBoard found a Black at (4,4); finding all connected cells.
revBoard uncovered 1 connected cells:
 O X
OOXX
 X X
XXXO

-------------- RESULTS -----------
- there is a white group at [(4,3),(4,1),(4,2),(3,2)]
- there is a white group at [(3,4),(2,3),(2,4),(1,4)]
- there is a black group at [(4,4)]
- there is a black group at [(2,1),(2,2),(1,2)]
 O X
OOXX
 X X                    
XXXO

-}
