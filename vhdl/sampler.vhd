library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

entity sampler is
    port (data : in signed14;
          decay : in unsigned(15 downto 0);
          rate : in unsigned8;
          q : out signed15;
          strobe : out std_logic;
          clk : in std_logic);
end sampler;
architecture sampler of sampler is
  signal low1, fb1, low2, decay2 : signed18;
  signal prod3, acc : signed36;
  signal data1, data2, data3, data4 : signed14;
  signal decay_off : boolean;
  signal divide : unsigned9;
begin
  decay_off <= (decay = x"0000");

  process
    variable q_acc_addend : signed15;
  begin
    wait until rising_edge(clk);

    if not decay_off then
      low1 <= data(13) & data(13) & data & "00";
      fb1 <= acc(33 downto 16);
      low2 <= low1 - fb1;
      decay2 <= '0' & signed(decay) & '0';
      prod3 <= low2 * decay2;
      acc <= acc + prod3;
    end if;

    data1 <= data;
    data2 <= data1;
    data3 <= data2;
    data4 <= data3;

    strobe <= divide(8);
    if divide(8) = '1' then
      divide <= ('0' & rate) - 1;

      if decay_off then
        q_acc_addend := (others => '0');
      else
        q_acc_addend := acc(32 downto 18);
      end if;
      q <= data4 + q_acc_addend;

    else
      divide <= divide - 1;
    end if;
  end process;
end sampler;
