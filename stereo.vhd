library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;
use work.sincos.all;

-- This takes 8 multiplexed streams with a total of one sample every
-- 25 cycles of a 62.5MHz clock (2.5MHz), i.e., each stream has one sample every
-- 200 cycles (312.5kHz).  Outputs stereo decode.

-- 19k / 312.5k * 2048 = 124.5 + a bit.
-- We let frequency range over 124/2048 * 312.5k to 125/2048 * 312.5k.
-- ie., 992 to 1000 times 312500/16384, (18920 to 19073).
-- (Could do 120..128, i.e 18310 to 19531Hz, would probably need loosened pll?)

entity stereo is
  port(sum_in : signed18;
       clk : std_logic;
       left : signed18;
       right : signed18;
       lock : std_logic);
end stereo;

-- We use a DSP block to do multiplies:
-- 19kHz cos for PLL feedback.
-- 38kHz sin for stereo recovery.
-- 57kHz sin for RDS???
-- 19kHz sin for pilot amplitude recovery (?)
-- 19kHz sin for pilot negation?
architecture behavioral of stereo is

  constant last_count : integer := 24;
  signal count : integer range 0 to last_count;

  signal channel : integer range 0 to 7;

  signal sintable : sinrom_t := sinrom;

  signal sin_neg : std_logic;
  signal sin_fine : unsigned2;

  type u36array_t is array(0 to 7) of unsigned36;

  -- FIXME - single 32x36 array?
  signal offsets : u36array_t;
  signal amplitudes : u36array_t;
  signal freqs : u36array_t;
  signal phases : u36array_t;

begin
  process (clk)
    variable sin_phase : unsigned14;
    variable sin_base : unsigned14;
    variable sin_offset : unsigned3;
  begin
    if clk'event and clk = '1' then
      if count = last_count then
        count <= 0;
        -- Could do without this if we kept coherent with phaseconvert...
        sum <= sum_in; -- Buffer input.
        channel <= (channel + 1) mod 8;
      else
        count <= count + 1;
      end if;
    end if;

    -- 0,1 : unpack, 2..11 : index, 12:up/down 13:invert.
    sin_phase := "xx" & x"xxx";

    if sin_phase(12) = '0' then
      sin_index := sin_phase(11 downto 2);
    else
      sin_index := not sin_phase(11 downto 2);
    end if;

    -- Lookup the sin table and buffer the adjustment bits.
    sin_neg <= sin_phase(13);
    sin_fine <= sin_phase(1 downto 0);
    packed_sin <= sintable(to_integer(sin_index));

    sin_base := packed_sin(13 downto 0);
    sin_offset := sinoffset(packed_sin, sin_fine);

    -- Do the multiplication...
    if sin_neg = '0' then
      product <= addend + data * (sin_base + sin_offset);
    else
      product <= addend - data * (sin_base + sin_offset);
    end if;

    -- PLL.
    -- For the offset, we are multiplying the signal (17bits+sign) by
    -- 2^14/pi . cos(...), giving a worst case of +/- 2^31/pi.
    -- For a in-phase squarewave signal, avg is 2^31/pi.(pi/2) = 2^30
    -- giving us 5 bits of margin plus sign.

    -- Smoothing over 1024 cycles means we have to drop 5 bits to fit worst
    -- case into 35bits+sign.

    -- The typical 19kHz pilot amplitude is about 2^16/10, giving the product
    -- 2^14/pi . cos(2pi phase/2^36). 2^16/10 . sin(19kHz.2pi.t)
    --
    -- Removing hi freq & averaging, we get
    -- 2^14.pi . 2^16/10 . 1/2 . sin(19kHz.2pi.t - 2pi phase/2^36).
    -- Assuming a small value inside sin, and keeping just the phase term:
    -- 2^14.pi . 2^16/10 . 1/2 . 2pi . phase / 2^36
    -- = 2^-6 / 10 . phase = phase/640.
    --
    -- We're shifting left by 5, so that gives phase/20480.
    --
    -- eigenvalues {{-1/1024,0,-1/(32*640)},{5/(27*262144),0,0},{5/(3*256),1,0}}
    -- defective, all -1/3072.
    --
    -- taking nearest powers of 2...
    -- 5/(27*262144) near 1/1048576, 5/(3*256) near 1/128.
    --
    -- Hmmm... it's tempting to multiply cos*signal by 3/4 (pi/4?) giving
    -- {{-1/1024, 0, -3/81920},{5/(81*65536),0,0},{5/(9*64),1,0}}
    -- with 5/(81*65536) near 1/1048576 and 5/(9*64) near 1/128 only being off
    -- by 1% and 10% or so...

    case count is
      when phase_pll+0 =>
        read_index := i_delta;
      when phase_pll+1 =>
        CC := ramout; -- delta.
        ZZ := CC;
        XX := sample * (sin_base + sin_offset);
        if sin_neg = '0' then
          PP <= ZZ + XX; -- delta+cos19*sample
        else
          PP <= ZZ - XX; -- delta+cos19*sample, negative case.
        end if;
        read_index := i_delta;
      when phase_pll+2 =>
        XX := PP;
        CC := ramout shl 10; -- delta.
        ZZ := CC;
        PP <= ZZ - XX; -- (delta<<10) - (delta+cos19*sample)
        read_index := i_freq;
      when phase_pll+3 =>
        ram(i_delta) <= PP(45 downto 10);
        XX := 0;
        CC := ramout shl 10; -- freq.
        ZZ := CC;
        PP <= ZZ + XX; -- freq
        read_index := i_delta;
      when phase_pll+4 =>
        XX := PP;
        CC := ramout shl/shr xxx; -- delta.
        ZZ := CC;
        PP <= ZZ + XX; -- freq+(delta/...)
        read_index := i_phase;
      when phase_pll+5 =>
        ram(i_freq) <= PP(45 downto 10);
        CC := ramout shl 10; -- phase.
        ZZ := CC;
        PP <= ZZ + XX; -- phase+new_freq.
        read_index := i_delta;
      when phase_pll+6 =>
        CC := ramout shl/shr xxx; -- new_delta.
        ZZ := CC;
        XX := PP;
        PP <= ZZ + XX; -- phase + new_freq + new_delta/...
      when phase_pll+7 =>
        ram(i_phase) <= PP(45 downto 10);
      when others =>
        ;
    end case;


    if count = blah then
      offsets(channel) <= offsets(channel) + in_times_cos19
                          - offsets(channel)(35 downto 10);
      amplitudes(channel) <= amplitudes(channel) + in_times_cos19;
      -- FIXME - clamp this one in range...
      -- FIXME - offset should be signed...
      freqs(channel) <= freqs(channel) + offsets(channel)(35 downto 14);
      phase(channel) <= phase(channel) + freqs(channel) + offsets(channel)
    end if;

  end process;
end behavioral;
