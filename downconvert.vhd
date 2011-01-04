library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

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
    Port (data : in  STD_LOGIC_VECTOR (13 downto 0);
          qq   : out STD_LOGIC_VECTOR (17 downto 0);
          ii   : out STD_LOGIC_VECTOR (17 downto 0);
          clk  : in  STD_LOGIC;
          freq : in  STD_LOGIC_VECTOR (23 downto 0));
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

  signal index_acc : std_logic_vector(23 downto 0);

  signal cos_index : std_logic_vector(9 downto 0);
  signal sin_index : std_logic_vector(9 downto 0);
  signal sin_low : std_logic_vector(1 downto 0);
  signal sin_low_2 : std_logic_vector(1 downto 0);

  signal cos_minus : std_logic;
  signal sin_minus : std_logic;
  signal cos_minus_2 : std_logic;
  signal sin_minus_2 : std_logic;
  signal cos_minus_3 : std_logic;
  signal sin_minus_3 : std_logic;
  signal cos_minus_4 : std_logic;
  signal sin_minus_4 : std_logic;
  signal cos_opmode : std_logic_vector(7 downto 0) := "00011001";
  signal sin_opmode : std_logic_vector(7 downto 0) := "00011001";

  signal packed_cos : word18;
  signal packed_sin : word18;

  signal cos_main : word18 := "00" & x"0000";
  signal sin_main : word18 := "00" & x"0000";
  signal cos_offset : word18 := "00" & x"0000";
  signal sin_offset : word18 := "00" & x"0000";

  signal data18 : word18;
  signal qq_buf : std_logic_vector(47 downto 0);
  signal ii_buf : std_logic_vector(47 downto 0);

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
      packed_cos <= sintable(conv_integer(cos_index));
      packed_sin <= sintable(conv_integer(sin_index));
      cos_minus_2 <= cos_minus;
      sin_minus_2 <= sin_minus;
      sin_low_2 <= sin_low;

      -- Prepare the sin and cos.
      cos_main(13 downto 0) <= packed_cos(13 downto 0);
      sin_main(13 downto 0) <= packed_sin(13 downto 0);
      cos_offset(2 downto 0) <= sinoffset(packed_cos, not sin_low_2);
      sin_offset(2 downto 0) <= sinoffset(packed_sin, sin_low_2);
      cos_minus_3 <= cos_minus_2;
      sin_minus_3 <= sin_minus_2;

      -- The opmode bit to control the final plus/minus only has 1 cycle of
      -- buffering in the DSP block, while through the adder & multiplier has
      -- 3 cycles.  So 2 more cycles here...
      cos_minus_4 <= cos_minus_3;
      sin_minus_4 <= sin_minus_3;
      cos_opmode(7) <= cos_minus_4;
      sin_opmode(7) <= sin_minus_4;

      -- Output
      qq <= qq_buf(35 downto 18);
      ii <= ii_buf(35 downto 18);

    end if;
  end process;

  data18(17) <= data(13);
  data18(16) <= data(13);
  data18(15) <= data(13);
  data18(14) <= data(13);
  data18(13 downto 0) <= data;

  qq_dsp : DSP48A1
    generic map (
      A0REG => 1,
      A1REG => 1,
      B0REG => 1,
      B1REG => 1,
      CARRYINREG => 1,
      CARRYINSEL => "OPMODE5",
      CREG => 1,
      DREG => 1,
      MREG => 1,
      OPMODEREG => 1,
      PREG => 1, -- Register output.
      RSTTYPE => "SYNC") -- Don't use it anyway.
    port map (
      BCOUT=> open,
      M=> open,
      PCOUT=> open,
      P=> qq_buf,
      CARRYOUT=> open,
      CARRYOUTF=> open,

      A=> data18,
      B=> cos_offset,
      C=> x"000000000000",
      D=> cos_main,
      OPMODE=> cos_opmode, -- ?/add / carry0 / pre-add / P / mult.
      PCIN=> x"000000000000",
      CARRYIN=> '0',
      CEA=> '1',
      CEB=> '1',
      CEC=> '1',
      CECARRYIN=>'0', -- Carry in reg not used.
      CED=> '1',
      CEM=> '1',
      CEOPMODE=> '1',
      CEP=> '1',
      CLK=> Clk,
      RSTA=> '0',
      RSTB=> '0',
      RSTC=> '0',
      RSTCARRYIN=> '0',
      RSTD=> '0',
      RSTM=> '0',
      RSTOPMODE=> '0',
      RSTP=> '0');

  ii_dsp : DSP48A1
    generic map (
      A0REG => 1,
      A1REG => 1,
      B0REG => 1,
      B1REG => 1,
      CARRYINREG => 1,
      CARRYINSEL => "OPMODE5",
      CREG => 1,
      DREG => 1,
      MREG => 1,
      OPMODEREG => 1,
      PREG => 1, -- Register output.
      RSTTYPE => "SYNC") -- Don't use it anyway.
    port map (
      BCOUT=> open,
      M=>open,
      PCOUT=> open,
      P=> ii_buf,
      CARRYOUT=> open,
      CARRYOUTF=> open,

      A=> data18,
      B=> sin_offset,
      C=> x"000000000000",
      D=> sin_main,
      OPMODE=> sin_opmode, -- ?/add / carry0 / pre-add / P / mult.
      PCIN=> x"000000000000",

      CARRYIN=> '0',
      CEA=> '1',
      CEB=> '1',
      CEC=> '1',
      CECARRYIN=>'0', -- Carry in reg not used.
      CED=> '1',
      CEM=> '1',
      CEOPMODE=> '1',
      CEP=> '1',
      CLK=> Clk,
      RSTA=> '0',
      RSTB=> '0',
      RSTC=> '0',
      RSTCARRYIN=> '0',
      RSTD=> '0',
      RSTM=> '0',
      RSTOPMODE=> '0',
      RSTP=> '0');

end Behavioral;
