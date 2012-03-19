module Main where

import System.Process
import Text.Regex.TDFA
--import Numeric
import Text.Printf
import Data.Bits

numRegex = makeRegex "-?[0-9]+" :: Regex

cycles = 240

bit_sample_strobe = 0x040000
bit_out_strobe    = 0x080000
bit_pc_reset      = 0x100000
bit_read_reset    = 0x200000
bit_mac_accum     = 0x400000

-- PC reset is latency around the command lookup loop via the pc_reset.
-- The other latencys are from the unpacked command to the accumulator output.
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

frequency_divide = 12
pass = 100000.0
nyquist = 1562500.0
stop = 2 * nyquist / fromInteger frequency_divide - pass
scale = 1658997.0

edges = [0, pass/nyquist, stop/nyquist, 1]
factors = [scale,scale,0,0]
weights = [1,300]
remez = printf "remez(%i,%s,%s,%s)" (cycles-2)
   (show edges) (show factors) (show weights)

main = do
  putStr $ "-- " ++ remez ++ "\n"
  textlist <- readProcess "/usr/bin/octave" ["-q"] $
    "disp(round(" ++ remez ++ "))"
  --if length textlist == cycles+2 then return () else fail "Bugger"
  putStr $ concat $ makeProgram textlist
