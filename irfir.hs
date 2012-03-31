module Main where

import Data.Bits
import System(getArgs)
import System.Process
import Text.Printf
import Text.Regex.TDFA

data FilterRange a b c = FilterRange {
   low :: a, high :: a, amplitude :: b, weight :: c }
   deriving Show

merge t u = easy (split t (endpoints u)) (split u (endpoints t)) where
  split [] _ = []
  split a [] = a
  split (a:t) (b:u) =
    if b <= low a then
      split (a:t) u
    else if high a <= b then
      a : split t (b:u)
    else
      FilterRange (low a) b  (amplitude a) (weight a) :
      FilterRange b (high a) (amplitude a) (weight a) : split t (b:u)
  easy a [] = a
  easy [] b = b
  easy (a:t) (b:u) =
    if high a <= low b then
      a : merge t (b:u)
    else if high b <= low a then
      b : merge (a:t) u
    else if low a == low b && high a == high b
            && amplitude a == amplitude b then
      FilterRange (low a) (high a) (amplitude a) (max (weight a) (weight b))
        : easy t u
    else
      error ("Inconsistent " ++ show a ++ " " ++ show b)
endpoints [] = []
endpoints (a:t) = low a : high a : endpoints t

compress [] = []
compress [a] = []
compress (a:b:t) =
  if high a == low b && amplitude a == amplitude b && weight a == weight b
  then compress (FilterRange (low a) (high a) (amplitude a) (weight a) : t)
  else a : compress (b:t)

remez c l = printf "remez(%i,%s,%s,%s)" (c-2)
   (show $ endpoints l) (show $ l >>= (replicate 2 . amplitude)) (show $ map weight l)

cycles = 400
frequency_divide = 20
pass = 62500
nyquist = 1562500.0
--stop = 2 * nyquist - pass
--scale = 1658997.0
scale = 2766466

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
-- There are two read paths through the DSP - we mean the faster.
latency_read_reset = 7 -- 2 pointer, 2 BRAM lookup, 3 DSP.
latency_fir = 3 -- the fir coefficients.

orIf i b p n = if p i then n .|. b else n
at :: Int -> Int -> Bool
at i j = (j + i) == latency_fir || (j + i) == (latency_fir + cycles)
controls i = orIf i bit_out_strobe    (at latency_out_strobe)
           . orIf i bit_pc_reset      (== (cycles - latency_pc_reset))
           . orIf i bit_read_reset    (at latency_read_reset)
           . orIf i bit_mac_accum     (not . at latency_mac_accum)
           . orIf i bit_sample_strobe ((0 ==) . (flip mod 20))

numRegex = makeRegex "-?[0-9]+" :: Regex

makeProgram s = let
  coeffs = 0 : [ read (match numRegex x) :: Int | x <- lines s]
  with_controls = zipWith controls [0..] $ map (0x3ffff .&.) coeffs
  as_hex = map (printf "x\"%06x\",") with_controls
  padded = zipWith (++) (cycle ["    ", " ", " ", " ", " "])
     $ zipWith (++) as_hex (cycle [ "", "", "", "", "\n" ])
 in
  [ printf "    -- Min coeff is %i\n" (minimum coeffs),
    printf "    -- Max coeff is %i\n" (maximum coeffs),
    printf "    -- Number of coeffs is %i\n" (length coeffs) ]
  ++ padded ++
  [ "    others => x\"000000\")\n" ]

fir =
  [FilterRange 0 delta scale 1]
  ++ [FilterRange (n * central - delta) (n * central + delta) 0 300
      | n <- map fromIntegral [2,4 .. frequency_divide - 2]]
  ++ [FilterRange (1 - delta) 1 0 300] where
  delta = pass / nyquist
  central = 1 / fromIntegral frequency_divide

generate = do
  putStr $ "-- " ++ remez cycles fir ++ "\n"
  textlist <- readProcess "/usr/bin/octave" ["-q"] $
    "disp(round(" ++ remez cycles fir ++ "))"
  --if length textlist == cycles+2 then return () else fail "Bugger"
  putStr $ concat $ makeProgram textlist

header = putStr $ remez cycles fir ++ "\n"

main = do
  args <- getArgs
  case args of { [ "header" ] -> header ; _ -> generate }
