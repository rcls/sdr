library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;
use work.sincos.all;

entity downconvert is
    Port (data   : in  signed14;
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
  -- output is signed 2^28/pi^2, [just under] 25 bits plus sign.

  -- e.g., accumulating over 1024 samples needs 35 bits plus sign.
  -- second order accumulation needs 45 bits plus sign.  Use all 48 bits...
  constant width : integer := 48;
  subtype accumulator is signed(width - 1 downto 0);

  signal index_acc : unsigned24 := x"000000";

  signal cos_index, sin_index : unsigned(9 downto 0);
  signal sin_low : unsigned(1 downto 0);
  signal sin_low_2 : unsigned(1 downto 0);

  signal cos_minus, sin_minus : std_logic_vector(1 to 7);

  signal packed_cos, packed_sin : unsigned18;

  signal cos_main, sin_main : unsigned18;
  signal cos_main_4, cos_main_5 : signed18;
  signal cos_offset : unsigned18;
  signal cos_offset_4, cos_offset_5 : signed18;
  signal sin_offset_4, sin_offset_5 : signed18;
  signal sin_main_4, sin_main_5 : signed18;
  signal sin_offset : unsigned18;
  signal sin, cos : signed18;

  signal data_3 : signed14;
  signal data_4, data_5, data_6 : signed18;
  signal xx_prod, yy_prod : signed36;

  signal xx_buf, xx_buf_9 : accumulator;
  signal yy_buf, yy_buf_9 : accumulator;

  signal xx_acc, yy_acc : accumulator;

  signal sintable : sinrom_t := sinrom;

  attribute use_dsp48 : string;
  attribute use_dsp48 of xx_acc, yy_acc : signal is "no";

begin
  process
  begin
    wait until rising_edge(clk);

    index_acc <= index_acc + freq;

    -- Unpack the accumulator to the indexes and signs.
    -- Hmmmm, we could avoid separate indexes if we had separate tables for
    -- sines and cosines...
    if index_acc(22) = '1' then
      cos_index <= index_acc(21 downto 12);
      sin_index <= not index_acc(21 downto 12);
      sin_low <= not index_acc(11 downto 10);
    else
      cos_index <= not index_acc(21 downto 12);
      sin_index <= index_acc(21 downto 12);
      sin_low <= index_acc(11 downto 10);
    end if;
    cos_minus(1) <= index_acc(23) xor index_acc(22);
    -- We are down-converting not up converting, so we want to use -sin.
    sin_minus(1) <= not index_acc(23);
    cos_minus(2 to 7) <= cos_minus(1 to 6);
    sin_minus(2 to 7) <= sin_minus(1 to 6);

    -- Lookup the sin and cos tables.
    packed_cos <= sintable(to_integer(cos_index));
    packed_sin <= sintable(to_integer(sin_index));
    sin_low_2 <= sin_low;

    -- Prepare the sin and cos.
    cos_main <= packed_cos and "00" & x"3fff";
    sin_main <= packed_sin and "00" & x"3fff";
    cos_offset <= resize(sinoffset(packed_cos, not sin_low_2), 18);
    sin_offset <= resize(sinoffset(packed_sin, sin_low_2), 18);
    data_3 <= data;

    -- Apply gain(1,0) to sin & cos, & gain(2) to data.
    if gain(2) = '0' then
      data_4 <= resize(data_3, 18);
    else
      data_4 <= data_3 & "0000";
    end if;

    cos_main_4 <= signed(cos_main) sll to_integer(gain(1 downto 0));
    sin_main_4 <= signed(sin_main) sll to_integer(gain(1 downto 0));
    cos_offset_4 <= signed(cos_offset) sll to_integer(gain(1 downto 0));
    sin_offset_4 <= signed(sin_offset) sll to_integer(gain(1 downto 0));

    -- Buffer.
    cos_main_5 <= cos_main_4;
    sin_main_5 <= sin_main_4;
    cos_offset_5 <= cos_offset_4;
    sin_offset_5 <= sin_offset_4;
    data_5 <= data_4;

    -- Pre-add.
    cos <= cos_main_5 + cos_offset_5;
    sin <= sin_main_5 + sin_offset_5;
    data_6 <= data_5;

    -- Multiply
    xx_prod <= data_6 * cos;
    yy_prod <= data_6 * sin;

    -- Post add (8).
    if cos_minus(7) = '1' then
      xx_buf <= xx_buf - xx_prod;
    else
      xx_buf <= xx_buf + xx_prod;
    end if;
    if sin_minus(7) = '1' then
      yy_buf <= yy_buf - yy_prod;
    else
      yy_buf <= yy_buf + yy_prod;
    end if;

    -- Buffer.
    xx_buf_9 <= xx_buf;
    yy_buf_9 <= yy_buf;

    -- Second order accumulate, applying gain(3).
    if gain(3) = '0' then
      xx_acc <= xx_acc + xx_buf_9;
      yy_acc <= yy_acc + yy_buf_9;
    else
      xx_acc <= xx_acc + (xx_buf_9 sll 8);
      yy_acc <= yy_acc + (yy_buf_9 sll 8);
    end if;

    xx <= xx_acc(width - 1 downto width - 36);
    yy <= yy_acc(width - 1 downto width - 36);
  end process;
end downconvert;
