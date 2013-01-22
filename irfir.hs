module Main where

import Data.Bits
import System.Environment(getArgs)
import System.Process
import Text.Printf
import Text.Regex.TDFA

data FilterRange a w e = FilterRange {
   amplitude :: a, weight :: w, low :: e, high :: e } deriving Show

data Constants f a = Constants {
     cycles :: Int,
     nyquist :: f,

     bit_sample_strobe :: Int,
     bit_out_strobe    :: Int,
     bit_pc_reset      :: Int,
     bit_read_reset    :: Int,
     bit_mac_accum     :: Int,

     -- PC reset is latency around the command lookup loop via the pc_reset.
     -- The other latencies are from the unpacked command to the accumulator
     -- output.
     latency_out_strobe :: Int,
     latency_mac_accum :: Int,
     latency_pc_reset :: Int, -- latency through PC & BRAM lookup.
     -- There are two read paths through the DSP (due to the delay and
     -- difference) - we mean the faster.
     latency_read_reset :: Int, -- 2 pointer, 2 BRAM lookup, 3 DSP.
     latency_fir :: Int, -- the fir coefficients.

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

remez c = printf "remez(%i,%s/%s,%s,%s)" (cycles c - 2)
   (show ep)
   (show nyq)
   (show $ fir c >>= (replicate 2 . amplitude))
   (show $ map weight $ fir c)
   where
     (nyq, ep) = reduce (nyquist c) (endpoints $ fir c)

irfir :: Constants Int Int
irfir = Constants {
   cycles = 400,
   nyquist = nyquist,

   bit_sample_strobe = 0x040000,
   bit_out_strobe    = 0x080000,
   bit_pc_reset      = 0x100000,
   bit_read_reset    = 0x200000,
   bit_mac_accum     = 0x400000,

   latency_out_strobe = 1,
   latency_mac_accum = 2,
   latency_pc_reset = 3,
   latency_read_reset = 7,
   latency_fir = 3,

   fir = withAntiAlias (div nyquist downsample) downsample 300
     [FilterRange scale 1 0 pass]
   } where
      downsample = 20
      pass = 62500
      scale = 2766466
      nyquist = 1562500

orIf :: t -> Int -> (t -> Bool) -> Int -> Int
orIf i b p n = if p i then n .|. b else n

at :: Constants f a -> Int -> Int -> Bool
at c i j = (j + i) == (latency_fir c) || (j + i) == (latency_fir c + cycles c)

controls :: Constants f a -> Int -> Int -> Int
controls c i = orIf i (bit_out_strobe c)   (at c $ latency_out_strobe c)
             . orIf i (bit_pc_reset c)     (== (cycles c - latency_pc_reset c))
             . orIf i (bit_read_reset c)   (at c $ latency_read_reset c)
             . orIf i (bit_mac_accum c)    (not . at c (latency_mac_accum c))
             . orIf i (bit_sample_strobe c)((0 ==) . flip mod 20)

numRegex = makeRegex "-?[0-9]+" :: Regex

--makeProgram :: String -> [String]
makeProgram c s = let
  coeffs = 0 : [ read (match numRegex x) :: Int | x <- lines s]
  with_controls = zipWith (controls c) [0..] $ map (0x3ffff .&.) coeffs
  as_hex = map (printf "x\"%06x\",") with_controls
  padded = zipWith (++) (cycle ["    ", " ", " ", " ", " "])
     $ zipWith (++) as_hex (cycle [ "", "", "", "", "\n" ])
 in
  [ printf "    -- Min coeff is %i\n" (minimum coeffs),
    printf "    -- Max coeff is %i\n" (maximum coeffs),
    printf "    -- Sum of coeffs is %i\n" (sum coeffs),
    printf "    -- Number of coeffs is %i\n" (length coeffs),
    "  signal program : program_t := (\n" ]
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
