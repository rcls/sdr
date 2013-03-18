library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

-- This does one half of the downconverter, either real or imaginary.
entity dc1 is
  generic(minus_sin : boolean);
  port (data : in signed14;
        gain : in unsigned(3 downto 0);
        q : out signed36;
        phase : in unsigned(13 downto 0);
        clk : in std_logic;
        index : out unsigned(9 downto 0);
        packed : in unsigned18);
end dc1;

architecture dc1 of dc1 is
  constant width : integer := 48;
  subtype accumulator is signed(width - 1 downto 0);

  --signal index : unsigned(9 downto 0);
  signal low, low_2 : unsigned(1 downto 0);

  signal minus : std_logic_vector(1 to 5);

  signal main, offset : unsigned18;

  signal data_3 : signed14;

  signal main_4, main_5, offset_4, offset_5, trig : signed18;
  signal data_4, data_5, data_6 : signed18;

  signal prod : signed36;

  signal buf, buf_9, acc : accumulator;

  attribute use_dsp48 : string;
  attribute use_dsp48 of acc : signal is "no";
begin
  process
  begin
    wait until rising_edge(clk);

    -- Unpack the accumulator to the indexes and signs.
    -- Maybe we should have separate tables for
    -- sines and cosines...
    if minus_sin then
      if phase(12) = '1' then
        index <= not phase(11 downto 2);
        low <= not phase(1 downto 0);
      else
        index <= phase(11 downto 2);
        low <= phase(1 downto 0);
      end if;
      -- We are down-converting not up converting, so we want to use -sin.
      minus(1) <= not phase(13);
    else
      if phase(12) = '1' then
        index <= phase(11 downto 2);
        low <= phase(1 downto 0);
      else
        index <= not phase(11 downto 2);
        low <= not phase(1 downto 0);
      end if;
      minus(1) <= phase(13) xor phase(12);
    end if;
    minus(2 to 5) <= minus(1 to 4);

    -- Lookup the sin and cos tables. - done a level up.
    --packed <= sintable(to_integer(index));
    low_2 <= low;

    -- Prepare the sin and cos.
    main <= packed and "00" & x"3fff";
    offset <= resize(sinoffset(packed, low_2), 18);
    data_3 <= data;

    -- Apply gain(1,0) to sin & cos, & gain(2) to data.
    if gain(2) = '0' then
      data_4 <= resize(data_3, 18);
    else
      data_4 <= data_3 & "0000";
    end if;

    main_4 <= signed(main) sll to_integer(gain(1 downto 0));
    if minus(4) = '1' then
      offset_4 <= -signed(offset) sll to_integer(gain(1 downto 0));
    else
      offset_4 <= signed(offset) sll to_integer(gain(1 downto 0));
    end if;

    -- Buffer.
    main_5 <= main_4;
    offset_5 <= offset_4;
    data_5 <= data_4;

    -- Pre-add.
    if minus(5) = '1' then
      trig <= offset_5 + main_5;
    else
      trig <= offset_5 - main_5;
    end if;
    data_6 <= data_5;

    -- Multiply
    prod <= data_6 * trig;

    -- Post add (8).
    buf <= buf + prod;

    -- Buffer.
    buf_9 <= buf;

    -- Second order accumulate, applying gain(3).
    if gain(3) = '0' then
      acc <= acc + buf_9;
    else
      acc <= acc + (buf_9 sll 8);
    end if;

    q <= acc(width - 1 downto width - 36);
  end process;
end dc1;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

entity downconvert is
    port (data   : in  signed14;
          gain   : in  unsigned8;
          xx, yy : out signed36;
          freq   : in  unsigned24;
          clk    : in  std_logic);
end downconvert;

architecture downconvert of downconvert is

  -- For the cosine/sine lookup, we take a 14 bit quantity.  The first two bits
  -- determine the quadrant, the middle ten the table index, and the bottom
  -- two determine the fine adjustment.  For cosine, the quadrant processing is:

  -- quadrant 00 : invert bottom 12 bits (rom index & fine adjust index).
  -- quadrant 01 : cosine is negative.
  -- quadrant 10 : invert bottom 12 bits, cosine is negative.
  -- quadrant 11 : as looked up.

  -- Sine is identical, except that the quadrant is processed differently:
  -- quadrant 00 : as looked up.
  -- quadrant 01 : invert bottom 12 bits.
  -- quadrant 10 : sin is negative.
  -- quadrant 11 : invert bottom 12 bits, sin is negative.

  -- The (co)sines are scaled to range from 0 to 2^14/pi (and sign bit).
  -- The average abs(sin) is 2/pi, after scaling 2^15/pi^2
  -- Data sample is 13 bits plus sign, so worst case average multiplier
  -- output is signed 2^28/pi^2, [just under] 25 bits plus sign.  (Before taking
  -- the shift due to 'gain' into account.)

  -- e.g., accumulating over 1024 samples needs 35 bits plus sign.
  -- second order accumulation needs 45 bits plus sign.  Use all 48 bits...
  signal phase : unsigned24 := x"000000";
  signal sin_index, cos_index : unsigned(9 downto 0);
  signal sin_packed, cos_packed : unsigned18;
  signal sintable : sinrom_t := sinrom;
begin

  cos : entity work.dc1 generic map(minus_sin => false)
    port map(data, gain(3 downto 0), xx, phase(23 downto 10), clk,
             cos_index, cos_packed);
  sin : entity work.dc1 generic map(minus_sin => true)
    port map(data, gain(3 downto 0), yy, phase(23 downto 10), clk,
             sin_index, sin_packed);
  process
  begin
    wait until rising_edge(clk);
    phase <= phase + freq;
    cos_packed <= sintable(to_integer(cos_index));
    sin_packed <= sintable(to_integer(sin_index));
  end process;
end downconvert;
