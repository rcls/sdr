module Main where

import Data.Bits
import Data.List
import System.Environment(getArgs)
import System.Process
import Text.Printf
import Text.Regex.TDFA

data FilterRange a w e = FilterRange {
   amplitude :: a, weight :: w, low :: e, high :: e } deriving Show

data FilterDesc f a = FilterDesc {
     cycles :: Int,
     dead_cycles :: Int,
     nyquist :: f,

     latency :: Int, -- Latency of the main processing.

     strobes :: [(String, Int->Bool)],

     fir :: [FilterRange a Int f]
     }

endpoints xs = do { x <- xs ; [low x, high x] }

-- Merge two [FilterRange]s.
merge t u = compress $
     easy (split t (endpoints u)) (split u (endpoints t)) where
  -- split items of a [FilterRange] by a list of endpoints.
  split [] _ = []
  split a [] = a
  split (a:t) (b:u) | b <= low a  = split (a:t) u
  split (a:t) (b:u) | high a <= b  = a : split t (b:u)
  split (FilterRange a w l h : t) (b:u) =
      FilterRange a w l b : FilterRange a w b h : split t u
  -- The easy case of 'merge' : items do not have partial overlaps.
  easy a [] = a
  easy [] b = b
  easy (a:t) (b:u) =
    if high a <= low b then
      a : merge t (b:u)
    else if high b <= low a then
      b : merge (a:t) u
    else if low a == low b && high a == high b
            && amplitude a == amplitude b then
      FilterRange (amplitude a) (max (weight a) (weight b)) (low a) (high a)
        : easy t u
    else
      error ("Inconsistent " ++ show a ++ " " ++ show b)

-- Combine successive entries of a [FilterRange] where possible.
compress [] = []
compress [a] = [a]
compress (a:b:t) =
  if high a == low b && amplitude a == amplitude b && weight a == weight b
  then compress (FilterRange (amplitude a) (weight a) (low a) (high b) : t)
  else a : compress (b:t)

-- Filter to remove aliases.  Band is the output Nyquist, count is the
-- oversample amount, weight is the filter weight, low..high is the range
-- which we don't want aliases of.
antiAlias band count weight low high = merge
   [ FilterRange 0 weight (i * band - high) (i * band - low)
      | i <- map fromIntegral [2, 4 .. count] ]
   [ FilterRange 0 weight (i * band + low) (i * band + high)
      | i <- map fromIntegral [2, 4 .. count-1] ]

-- Modify a filter to remove aliases of its ranges.
withAntiAlias band count weight f = foldl merge f
  [ antiAlias band count weight (low x) (high x) | x <- f ]

class Reduce a where
   reduce :: a -> [a] -> (a, [a])
instance Reduce Int where
   reduce n l = (div n g, map (flip div g) l) where
     g = foldl gcd n l
instance Reduce Double where
   reduce n l = (n, l)

remez c = printf "remez(%i,%s/%s,%s,%s)" (cycles c - dead_cycles c - 1)
   (show ep)
   (show nyq)
   (show $ fir c >>= (replicate 2 . amplitude))
   (show $ map weight $ fir c)
   where
     (nyq, ep) = reduce (nyquist c) (endpoints $ fir c)

at :: FilterDesc f a -> Int -> Int -> Bool
at c i j = (j + i) == (latency c) || (j + i) == (latency c + cycles c)

controls :: FilterDesc f a -> Int -> Int -> Int
controls c i x = foldl (.|.) x $ map (shiftL 0x040000) $
    findIndices (\(s,p) -> p i) $ strobes c

numRegex = makeRegex "-?[0-9]+" :: Regex

irfir :: FilterDesc Int Int
irfir = FilterDesc {
   cycles = 400,
   dead_cycles = 1,
   nyquist = nyquist,

   latency = 3,

   strobes = [
     ("sample_strobe", ((0 ==) . flip mod 20)),
     ("out_strobe", at irfir 1),
     ("pc_reset", (== (400 - 3))),
     ("read_reset", at irfir 7),
     ("mac_accum", (not . at irfir 2))
   ],

   fir = withAntiAlias (div nyquist downsample) downsample 300
     [FilterRange scale 1 0 pass]
   } where
      downsample = 20
      pass = 62500
      scale = 2766466
      nyquist = 1562500

--makeProgram :: String -> [String]
makeProgram c s = let
  coeffs = replicate (dead_cycles c) 0
     ++ [ read (match numRegex x) :: Int | x <- lines s]
  with_controls = zipWith (controls c) [0..] $ map (0x3ffff .&.) coeffs
  as_hex = map (printf "x\"%06x\",") with_controls
  padded = zipWith (++) (cycle ["    ", " ", " ", " ", " "])
     $ zipWith (++) as_hex (cycle [ "", "", "", "", "\n" ])
 in
  zipWith (\(s,_)-> \n -> printf "  constant index_%s : integer := %i;\n" s n)
     (strobes c) [(18::Int)..]
  ++ [
    printf "  constant program_size : integer := %i;\n" (cycles c),
    printf "  -- Min coeff is %i\n" (minimum coeffs),
    printf "  -- Max coeff is %i\n" (maximum coeffs),
    printf "  -- Sum of coeffs is %i\n" (sum coeffs),
    printf "  -- Number of coeffs is %i\n" (length coeffs),
    "  signal program : program_t(0 to program_size - 1) := (\n" ]
  ++ padded ++
  [ "    others => x\"000000\")\n" ]

generate c = do
     putStr $ "-- " ++ remezc ++ "\n"
     textlist <- readProcess "/usr/bin/octave" ["-q"] $
       "disp(round(" ++ remezc ++ "))"
     --if length textlist == cycles+2 then return () else fail "Bugger"
     putStr $ concat $ makeProgram c textlist
   where
     remezc = remez c

header c = putStr $ remez c ++ "\n"

main = do
  args <- getArgs
  case args of
    [ "header" ] -> header irfir
    _ -> generate irfir
