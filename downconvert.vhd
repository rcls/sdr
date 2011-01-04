library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.sincos.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity downconvert is
    Port (data : in  signed (13 downto 0);
          qq   : out unsigned18;
          ii   : out unsigned18;
          clk  : in  STD_LOGIC;
          freq : in  unsigned (23 downto 0));
end downconvert;

architecture Behavioral of downconvert is

  -- For the cosine/sine lookup, we take a 14 bit quantity.  The first two bits
  -- determine the quadrant, the middle ten the table index, and the bottom
  -- two determine the adjustment.  For cosine, the quadrant processing is:

  -- quadrant 00 : invert bottom 12 bits (rom index & fine adjust index).
  -- quadrant 01 : cosine is negative.
  -- quadrant 10 : invert bottom 12 bits, cosine is negative.
  -- quadrant 11 : as looked up.

  -- Sine is identical, except that the quadrant is processed differently:
  -- quadrant 00 : as looked up.
  -- quadrant 01 : invert bottom 12 bits.
  -- quadrant 10 : sin is negative.
  -- quadrant 11 : invert bottom 12 bits, sin is negative.

  -- The sines are scaled to range from 0 to 2^14/pi (and sign bit).
  -- The average abs(sin) is 2/pi, after scaling 2^15/pi^2
  -- Data sample is 13 bits plus sign, so worst case average multiplier
  -- output is signed 2^28/pi^2, [just under] 25 bits plus sign.
  -- e.g., accumulating over 1024 samples 35 bits plus sign.

  signal index_acc : unsigned(23 downto 0);

  signal cos_index : unsigned(9 downto 0);
  signal sin_index : unsigned(9 downto 0);
  signal sin_low : unsigned(1 downto 0);
  signal sin_low_2 : unsigned(1 downto 0);

  signal cos_minus : std_logic;
  signal sin_minus : std_logic;
  signal cos_minus_2 : std_logic;
  signal sin_minus_2 : std_logic;
  signal cos_minus_3 : std_logic;
  signal sin_minus_3 : std_logic;
  signal cos_minus_4 : std_logic;
  signal sin_minus_4 : std_logic;
  signal cos_minus_5 : std_logic;
  signal sin_minus_5 : std_logic;
  signal cos_minus_6 : std_logic;
  signal sin_minus_6 : std_logic;

  signal packed_cos : unsigned18;
  signal packed_sin : unsigned18;

  subtype signed18 is signed(17 downto 0);

  signal cos_main : unsigned18;
  signal sin_main : unsigned18;
  signal cos_offset : unsigned18;
  signal sin_offset : unsigned18;
  signal cos_main_1 : unsigned18;
  signal sin_main_1 : unsigned18;
  signal cos_offset_1 : unsigned18;
  signal sin_offset_1 : unsigned18;
  signal sin : signed18;
  signal cos : signed18;

  signal data_1 : signed(13 downto 0);
  signal data_2 : signed(13 downto 0);
  signal qq_prod : signed(31 downto 0);
  signal ii_prod : signed(31 downto 0);

  signal qq_buf : signed(47 downto 0);
  signal ii_buf : signed(47 downto 0);

  signal sintable : sinrom_t := sinrom;

begin
  process (Clk)
  begin
    if Clk'event and Clk = '1' then
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
      cos_minus <= index_acc(23) xor index_acc(22);
      sin_minus <= index_acc(23);

      -- Lookup the sin and cos tables.
      packed_cos <= sintable(to_integer(cos_index));
      packed_sin <= sintable(to_integer(sin_index));
      cos_minus_2 <= cos_minus;
      sin_minus_2 <= sin_minus;
      sin_low_2 <= sin_low;

      -- Prepare the sin and cos.
      cos_main <= packed_cos and "00" & x"3fff";
      sin_main <= packed_sin and "00" & x"3fff";
      cos_offset <= resize(sinoffset(packed_cos, not sin_low_2), 18);
      sin_offset <= resize(sinoffset(packed_sin, sin_low_2), 18);
      cos_minus_3 <= cos_minus_2;
      sin_minus_3 <= sin_minus_2;
      data_1 <= data;

      -- Buffer.
      cos_main_1 <= cos_main;
      sin_main_1 <= sin_main;
      cos_offset_1 <= cos_offset;
      sin_offset_1 <= sin_offset;
      cos_minus_4 <= cos_minus_3;
      sin_minus_4 <= sin_minus_3;

      -- Pre-add.
      cos <= signed(cos_main_1 + cos_offset_1);
      sin <= signed(sin_main_1 + sin_offset_1);
      data_2 <= data_1;
      cos_minus_5 <= cos_minus_4;
      sin_minus_5 <= sin_minus_4;

      -- Multiply
      qq_prod <= data_2 * cos;
      ii_prod <= data_2 * sin;
      cos_minus_6 <= cos_minus_5;
      sin_minus_6 <= sin_minus_5;

      -- Post add.
      if cos_minus_6 = '1' then
        qq_buf <= qq_buf - qq_prod;
      else
        qq_buf <= qq_buf + qq_prod;
      end if;
      if sin_minus_6 = '1' then
        ii_buf <= ii_buf - ii_prod;
      else
        ii_buf <= ii_buf + ii_prod;
      end if;

      -- Output
      qq <= unsigned(qq_buf(35 downto 18));
      ii <= unsigned(ii_buf(35 downto 18));

    end if;
  end process;
end Behavioral;
