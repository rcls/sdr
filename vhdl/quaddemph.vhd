library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity quaddemph is
  generic(in_width : integer := 32;
          acc_width : integer := 38;
          out_width : integer := 32;
          out_drop : integer := 1);
  port (d : in signed(in_width - 1 downto 0);
        d_strobe : in std_logic;
        q : out signed(out_width - 1 downto 0);
        clk : in std_logic);
end quaddemph;

architecture quaddemph of quaddemph is
  subtype acc_t is signed(acc_width - 1 downto 0);
  signal acc_a, acc_b, acc_c, acc_d : acc_t;
  constant out_top : integer := acc_width - out_drop;
begin
  process
    variable drop_extend : signed(out_drop - 1 downto 0);
  begin
    wait until rising_edge(clk);
    if d_strobe = '1' then
      acc_a <= acc_d - acc_d(acc_width - 1 downto 3);
      acc_b <= acc_a + acc_a(acc_width - 1 downto 7);
      acc_c <= acc_b - acc_b(acc_width - 1 downto 9);
      acc_d <= acc_c + d;

      drop_extend := (others => acc_d(acc_width - 1));
      if acc_d(acc_width - 1 downto out_top - 1) = drop_extend then
        q <= acc_d(out_top - 1 downto out_top - out_width);
      else
        q <= (out_width - 1 => acc_d(acc_width - 1),
              others => not acc_d(acc_width - 1));
      end if;
    end if;
  end process;
end quaddemph;
