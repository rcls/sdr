library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

entity phasedetect is
  port(qq_in : in signed36; -- overkill, should have reduced to 18 bits by now.
       ii_in : in signed36;
       phase : out signed18;
       clk : in std_logic);
end phasedetect;

-- The main phase detect uses 16 iterations, main usage is
-- (iterations 1 to 15).  The calculation is:
--   ii_div = ii right-shifted (by 2n).
--   trial qq' = qq + ii_div, ii' = ii - qq
--   commit, if ii' has not underflown, update angle.

-- We want to reuse the first time through the pipeline:
-- shift=0.  If no underflow, then swap qq and ii.
-- The 25th iteration is used for loading in/out.

architecture Behavioral of phasedetect is
  signal qq : unsigned36; -- Real component.
  signal ii : unsigned37; -- Imaginary component.
  signal angle : signed18; -- Accumulated angle.
  signal positiv : boolean; -- Positive adjustments to angle.

  constant last_count : integer := 24;
  signal count : integer range 0 to last_count;

  -- Angle updates.  Exhaustive testing indicates that the odd first value is
  -- best.
  type angles_t is array(0 to last_count) of unsigned16;
  constant angle_update : angles_t :=
    (x"fffe", x"4b90", x"27ed", x"1444",
     x"0a2c", x"0517", x"028c", x"0146",
     x"00a3", x"0051", x"0029", x"0014",
     x"000a", x"0005", x"0003", x"0001",
     x"0000", x"0000", x"0000", x"0000",
     x"0000", x"0000", x"0000", x"0000",
     x"0000");

begin
  process (clk)
    variable ii_shifted : unsigned37;
    variable qq_trial : unsigned36;
    variable ii_trial : unsigned37;

    variable load : boolean; -- Load cycle, previous to start cycle.
    variable start : boolean; -- Start cycle, count=0, slightly different.

  begin
    if clk'event and clk = '1' then
      load := count = last_count;
      start := count = 0;

      if load then
        count <= 0;
      else
        count <= count + 1;
      end if;

      -- Right shift.  Note that for the start iteration, the high bit of ii is
      -- still zero.
      ii_shifted := ii srl (2 * (count mod 16));

      -- Trial operation.
      qq_trial := qq + ii_shifted(35 downto 0);
      -- ii is at most twice the 36 bit qq, so if the arithmetic does not
      -- overflow, then the result of the subtract will fit in 36 bits.
      ii_trial := ii - ('0' & qq);

      if load then
        -- 'not' is cheaper than proper true negation.  And given our
        -- round-towards-negative behaviour, more accurate.
        if qq_in(35) = '0' then
          qq <= unsigned(qq_in);
        else
          qq <= not unsigned(qq_in);
        end if;
        if ii_in(35) = '0' then
          ii <= '0' & unsigned(ii_in);
        else
          ii <= '0' & not unsigned(ii_in);
        end if;
        positiv <= (qq_in >= 0) xor (ii_in < 0);
        -- Our convention is that angle zero covers the first sliver of the
        -- first quadrant= etc., so bias the start angle just into the
        -- appropriate quadrant.  Yes the 0=>1 looks like a step too far,
        -- but after exhaustive testing, it gives better results, presumably
        -- because of the granularity of the result.
        angle <= (17 => ii(35), 0 => '1', others => qq(35) xor ii(35));
        phase <= angle; -- ship out previous result.

      elsif ii_trial(36) = '0' then
        -- Trial subtract is OK, save the results.
        if not start then
          qq <= qq_trial;
          ii <= ii_trial sll 1;
        else
          -- No overflow, ii is bigger than qq, so swap things over.  Remember
          -- that we want ii left shifted.
          qq <= ii(36 downto 1);
          ii <= qq & '0';
          positiv <= not positiv;
        end if;

        if positiv then
          angle <= angle + ("00" & signed(angle_update(count)));
        else
          angle <= angle - ("00" & signed(angle_update(count)));
        end if;
      else
        ii <= ii sll 1;
      end if;

    end if;
  end process;

end Behavioral;
