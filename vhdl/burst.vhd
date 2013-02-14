library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity burst is
  port(adc_data : in signed14;
       trigger : in std_logic;
       data : out signed15;
       strobe : out std_logic;
       clk : in std_logic);
end burst;

architecture burst of burst is
  constant bits : integer := 11;
  constant ram_size : integer := 2048;
  signal in_count : unsigned(bits downto 0) := (others => '0');
  signal out_count : unsigned(bits + 8 downto 0) := (others => '0');
  constant zero : unsigned(bits + 8 downto 0) := (others => '0');
  type ram_t is array(0 to ram_size) of signed14;
  signal ram : ram_t;

  signal data_1, data_2 : signed14;
  signal zero_1, zero_2 : std_logic;
  signal strobe_1, strobe_2 : std_logic;

  signal trigger_last : std_logic := '0';
begin

  process
  begin
    wait until rising_edge(clk);
    trigger_last <= trigger;
    if trigger_last /= trigger then
      in_count <= (bits => '1', others => '0');
    elsif in_count(bits) = '1' then
      in_count <= in_count + 1;
    end if;
    if in_count(bits) = '1' then
      ram(to_integer(in_count(bits - 1 downto 0))) <= adc_data;
    end if;
  end process;

  process
  begin
    wait until rising_edge(clk);
    out_count <= out_count + 1;
    zero_1 <= b2s(out_count(bits + 8 downto 9) = zero(bits + 8 downto 9));
    data_1 <= ram(to_integer(out_count(bits + 8 downto 9)));
    strobe_1 <= out_count(9);
    zero_2 <= zero_1;
    data_2 <= data_1;
    strobe_2 <= strobe_1;
    data <= zero_2 & data_2;
    strobe <= strobe_2;
  end process;
end burst;
