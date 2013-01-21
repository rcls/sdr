module Main where

import Data.Bits
import System.Environment(getArgs)
import System.Process
import Text.Printf
import Text.Regex.TDFA

data FilterRange a w e = FilterRange {
   amplitude :: a, weight :: w, low :: e, high :: e } deriving Show

-- Merge two [FilterRange]s.
merge t u = compress $
     easy (split t (endpoints u)) (split u (endpoints t)) where
  -- split items of a [FilterRange] by a list of endpoints.
  split [] _ = []
  split a [] = a
  split (a:t) (b:u) =
    if b <= low a then
      split (a:t) u
    else if high a <= b then
      a : split t (b:u)
    else
      FilterRange (amplitude a) (weight a) (low a) b :
      FilterRange (amplitude a) (weight a) b (high a) : split t u
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

endpoints xs = do { x <- xs ; [low x, high x] }

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

remez count filter nyquist = printf "remez(%i,%s/%s,%s,%s)" (count-2)
   (show ep)
   (show nyq)
   (show $ filter >>= (replicate 2 . amplitude))
   (show $ map weight filter)
   where
     (nyq, ep) = reduce nyquist (endpoints filter)

cycles = 400
downsample = 20
pass = 62500
nyquist = 1562500
nyq_out :: Int
nyq_out = 78125
--stop = 2 * nyquist - pass
--scale = 1658997.0
scale = 2766466

fir = withAntiAlias nyq_out downsample 300 [FilterRange scale 1 0 pass]

bit_sample_strobe = 0x040000
bit_out_strobe    = 0x080000
bit_pc_reset      = 0x100000
bit_read_reset    = 0x200000
bit_mac_accum     = 0x400000

-- PC reset is latency around the command lookup loop via the pc_reset.
-- The other latencies are from the unpacked command to the accumulator output.
latency_out_strobe = 1
latency_mac_accum = 2
latency_pc_reset = 3 -- latency through PC & BRAM lookup.
-- There are two read paths through the DSP (due to the delay and difference) -
-- we mean the faster.
latency_read_reset = 7 -- 2 pointer, 2 BRAM lookup, 3 DSP.
latency_fir = 3 -- the fir coefficients.

orIf :: t -> Int -> (t -> Bool) -> Int -> Int
orIf i b p n = if p i then n .|. b else n

at :: Int -> Int -> Bool
at i j = (j + i) == latency_fir || (j + i) == (latency_fir + cycles)

controls :: Int -> Int -> Int
controls i = orIf i bit_out_strobe    (at latency_out_strobe)
           . orIf i bit_pc_reset      (== (cycles - latency_pc_reset))
           . orIf i bit_read_reset    (at latency_read_reset)
           . orIf i bit_mac_accum     (not . at latency_mac_accum)
           . orIf i bit_sample_strobe ((0 ==) . (flip mod 20))

numRegex = makeRegex "-?[0-9]+" :: Regex

makeProgram :: String -> [String]
makeProgram s = let
  coeffs = 0 : [ read (match numRegex x) :: Int | x <- lines s]
  with_controls = zipWith controls [0..] $ map (0x3ffff .&.) coeffs
  as_hex = map (printf "x\"%06x\",") with_controls
  padded = zipWith (++) (cycle ["    ", " ", " ", " ", " "])
     $ zipWith (++) as_hex (cycle [ "", "", "", "", "\n" ])
 in
  [ printf "    -- Min coeff is %i\n" (minimum coeffs),
    printf "    -- Max coeff is %i\n" (maximum coeffs),
    printf "    -- Sum of coeffs is %i\n" (sum coeffs),
    printf "    -- Number of coeffs is %i\n" (length coeffs) ]
  ++ padded ++
  [ "    others => x\"000000\")\n" ]

generate = do
  putStr $ "-- " ++ remez cycles fir nyquist ++ "\n"
  textlist <- readProcess "/usr/bin/octave" ["-q"] $
    "disp(round(" ++ remez cycles fir nyquist ++ "))"
  --if length textlist == cycles+2 then return () else fail "Bugger"
  putStr $ concat $ makeProgram textlist

header = putStr $ remez cycles fir nyquist ++ "\n"

main = do
  args <- getArgs
  case args of { [ "header" ] -> header ; _ -> generate }
