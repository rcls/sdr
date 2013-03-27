library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

-- Sample rate is 250MHz / 6400 = 39062.5Hz.
-- sample rate * 256 is 250MHz / 25 = 10M.
-- sample rate * 128 is 5M.

-- Let's extend samples to 32 bits.
-- Bck = 250MHz / 100 = lrck * 64, sck = 250Mhz / 50 = lrck * 128

-- The incoming sample rate is one every 400 cycles, each channel has one
-- every 1600 cycles.

entity audio is
  -- So lrck is bit/(2*lcrk_divider).
  generic (bits_per_sample : integer);
  port (left, right : in signed(bits_per_sample-1 downto 0);
        channel : in unsigned2;
        last : in std_logic;
        scki, lrck, data, bck : out std_logic;
        clk : in std_logic);
end audio;

architecture audio of audio is
  signal divider : unsigned (12 downto 0);
  signal sample_hold : signed(63 downto 0);
  signal shift_reg : signed(63 downto 0);
  signal sample_shift, sample_load, shift_load : boolean;
  signal prev_last : std_logic;
  constant repeat_end : integer := 2 * bits_per_sample - 32;
begin
  data <= shift_reg(63);
  process
  begin
    wait until rising_edge(clk);

    prev_last <= last;
    -- In the bottom 5 bits, do /25 instead of /31.  We maintain phase with
    -- last by slipping a cycle if shift/load is asserted incorrectly.
    if sample_shift and shift_load and not (prev_last='1' and last='0') then
    else
      if divider(4 downto 3) = "11" then
        divider <= divider + 8;
      else
        divider <= divider + 1;
      end if;
    end if;

    lrck <= divider(12);
    bck <= divider(6);
    scki <= divider(4);
    sample_shift <= divider(6 downto 3) = "1111";
    shift_load <= divider(12 downto 7) = "111111";
    sample_load <= divider(12 downto 7) = "11" & (channel - "01") & "11";
    if sample_shift then
      if shift_load then
        --shift_reg <= left & left(bits_per_sample - 1 downto repeat_end)
        --             & right & right(bits_per_sample - 1 downto repeat_end);
        shift_reg <= sample_hold;
      else
        shift_reg <= shift_reg sll 1;
      end if;
      if sample_load then
        sample_hold <= left & right;
      end if;
    end if;
  end process;
end audio;
