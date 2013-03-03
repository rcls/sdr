library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity phasedetect is
  port(xx_in : in signed36; -- overkill, could have reduced to 18 bits by now.
       yy_in : in signed36;
       in_last : in std_logic;
       phase : out unsigned18;
       out_strobe : out std_logic;
       out_last : out std_logic;
       clk : in std_logic);
end phasedetect;

-- The main phase detect uses a pipeline, 16 iterations, main usage is
-- (iterations 1 to 15):
-- stage1: yy_div = yy right-shifted (by 2n).
-- stage2: trial xx' = xx + yy_div, yy' = yy - xx
-- stage3: commit, if yy' has not underflown, update angle.

-- We want to reuse the first time through the pipeline:
-- shift=0.  If no underflow, then swap xx and yy.
-- We load every 20 (?) cycles,
-- and ship out 60 cycles later.

architecture behavioural of phasedetect is
  signal xx1 : unsigned36; -- Real component.
  signal yy1 : unsigned37; -- Imaginary component.
  signal last1 : std_logic;

  signal angle1 : unsigned18; -- Accumulated angle.
  signal positive1 : boolean; -- Positive adjustments to angle.

  signal xx2 : unsigned36;
  signal yy2 : unsigned37;
  signal yy2_shifted : unsigned37;
  signal angle2 : unsigned18;
  signal positive2 : boolean;
  signal load2 : boolean;
  signal last2 : std_logic;

  signal xx3 : unsigned36;
  signal yy3 : unsigned37;
  signal xx3_trial : unsigned36;
  signal yy3_trial : unsigned37;
  signal angle3 : unsigned18;
  signal angle3_update : unsigned16;
  signal positive3 : boolean;
  signal start3 : boolean;
  signal last3 : std_logic;

  signal count : integer range 0 to 19;
  type stage_t is array(0 to 19) of integer range 0 to 19;
  -- For pipeline stage 1, map the cycle counter to the iteration of the
  -- calculation.
  constant iteration1 : stage_t :=
    (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19);
  -- Iteration number for pipeline stage 2.
  constant iteration2 : stage_t :=
    (13, 14, 15, 16, 17, 18, 19, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
  -- Iteration number for pipeline stage 3.
  constant iteration3 : stage_t :=
    (6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 0, 1, 2, 3, 4, 5);

  -- Angle updates.  Exhaustive testing indicates that the odd first value is
  -- best.
  type angles_t is array(0 to 19) of unsigned16;
  constant angle_update : angles_t :=
    (x"fffe", x"4b90", x"27ed", x"1444",
     x"0a2c", x"0517", x"028c", x"0146",
     x"00a3", x"0051", x"0029", x"0014",
     x"000a", x"0005", x"0003", x"0001",
     x"0000", x"0000", x"0000", x"0000");

begin
  process (clk)
  begin
    if clk'event and clk = '1' then
      if count >= 13 then
        count <= count - 13;
      else
        count <= count + 7;
      end if;
      start3 <= (count = 7);

      -- The default flow is just to cycle things around; override later if
      -- need be.
      xx2 <= xx1;
      yy2 <= yy1;
      angle2 <= angle1;
      positive2 <= positive1;
      last2 <= last1;

      xx3 <= xx2;
      -- Include left shift.  If this loses a bit, then the trial will succeed
      -- anyway, and get us back.
      yy3 <= yy2 sll 1;
      angle3 <= angle2;
      positive3 <= positive2;
      last3 <= last2;

      xx1 <= xx3;
      yy1 <= yy3;
      angle1 <= angle3;
      positive1 <= positive3;
      last1 <= last3;

      -- First pipeline stage is the right shift.  Note that for the start
      -- iteration, the high bit of yy is still zero, so the high bit of
      -- yy_shifted will always be zero.
      yy2_shifted <= yy1 srl (2 * (count mod 16));
      load2 <= (count = 19);

      -- Second pipeline stage is the trial operation.  It also handles the
      -- loading of data into the pipeline.
      xx3_trial <= xx2 + yy2_shifted(35 downto 0);
      -- Note that yy is at most twice the 36 bit xx, so if the arithmetic does
      -- not overflow, then the result of the subtract will fit in 36 bits.
      -- Except for round-0 (where we normalise to the first octant).  In that
      -- case everything is 36 bits.
      yy3_trial <= yy2 - ('0' & xx2);
      angle3_update <= angle_update(iteration2(count));

      if load2 then
        last3 <= in_last;
        yy3_trial(36) <= '1'; -- Make sure we don't adjust on next cycle.
        -- 'not' is cheaper than proper true negation.  And given our
        -- round-towards-negative behaviour, more accurate.
        if xx_in(35) = '0' then
          xx3 <= unsigned(xx_in);
        else
          xx3 <= not unsigned(xx_in);
        end if;
        if yy_in(35) = '0' then
          yy3 <= '0' & unsigned(yy_in);
        else
          yy3 <= '0' & not unsigned(yy_in);
        end if;
        positive3 <= (xx_in(35) xor yy_in(35)) = '1';
        -- Our convention is that angle zero covers the first sliver of the
        -- first quadrant etc., so bias the start angle just into the
        -- appropriate quadrant.  Yes the 0=>1 looks like a step too far,
        -- but after exhaustive testing, it gives better results, presumably
        -- because of the granularity of the result.
        angle3 <= (17 => yy_in(35), 0 => '1',
                   others => xx_in(35) xor yy_in(35));
        phase <= angle2; -- ship out previous result.
        out_last <= last2;
      end if;
      out_strobe <= b2s(load2);

      -- Third pipeline stage is commitment.
      if yy3_trial(36) = '0' then
        if not start3 then
          xx1 <= xx3_trial;
          -- yy got left shifted at the previous stage, but yy_trial did not.
          -- so take that into account.
          yy1 <= yy3_trial sll 1;
        else
          -- No overflow, yy is bigger than xx, so swap things over.  Remember
          -- that yy got left shifted, so take that into account in the swap.
          xx1 <= yy3(36 downto 1);
          yy1 <= xx3 & '0';
          positive1 <= not positive3;
        end if;

        if positive3 then
          angle1 <= angle3 + ("00" & angle3_update);
        else
          angle1 <= angle3 - ("00" & angle3_update);
        end if;
      end if;

    end if;
  end process;

end behavioural;
