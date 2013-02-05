library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity blinkoflow is
  generic (data_bits : integer := 14;
           mon_bits : integer := 4;
           count_bits : integer := 25);
  port (d : in signed(data_bits - 1 downto 0);
        good : out std_logic;
        bad : out std_logic;
        clk : in std_logic);
end blinkoflow;

architecture blinkoflow of blinkoflow is
  signal counter : unsigned (count_bits - 1 downto 0);
  signal oflow : boolean;
  constant twiddle : signed(data_bits - 1 downto 0) := (
    data_bits - 1 => '1', others => '0');
begin
  process
    variable ud : signed(data_bits - 1 downto 0);
  begin
    wait until rising_edge(clk);
    good <= counter(count_bits - 1);
    bad <= not counter(count_bits - 1);

    ud := d xor twiddle;
    oflow <= ud(data_bits - 1 downto data_bits - mon_bits + 1)
             = ud(data_bits - 2 downto data_bits - mon_bits);
    if oflow then
      counter <= (others => '0');
    elsif counter(count_bits - 1) = '0' then
      counter <= counter + 1;
    end if;
  end process;
end blinkoflow;
