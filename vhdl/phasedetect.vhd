library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity phasedetect is
  port(qq_in : in signed36; -- overkill, could have reduced to 18 bits by now.
       ii_in : in signed36;
       phase : out unsigned18;
       clk : in std_logic);
end phasedetect;

-- The main phase detect uses a pipeline, 16 iterations, main usage is
-- (iterations 1 to 15):
-- stage1: ii_div = ii right-shifted (by 2n).
-- stage2: trial qq' = qq + ii_div, ii' = ii - qq
-- stage3: commit, if ii' has not underflown, update angle.

-- We want to reuse the first time through the pipeline:
-- shift=0.  If no underflow, then swap qq and ii.
-- We load every 20 (?) cycles,
-- and ship out 60 cycles later.

architecture behavioural of phasedetect is
  signal qq1 : unsigned36; -- Real component.
  signal ii1 : unsigned37; -- Imaginary component.

  signal angle1 : unsigned18; -- Accumulated angle.
  signal positive1 : boolean; -- Positive adjustments to angle.

  signal qq2 : unsigned36;
  signal ii2 : unsigned37;
  signal ii2_shifted : unsigned37;
  signal angle2 : unsigned18;
  signal positive2 : boolean;
  signal load2 : boolean;

  signal qq3 : unsigned36;
  signal ii3 : unsigned37;
  signal qq3_trial : unsigned36;
  signal ii3_trial : unsigned37;
  signal angle3 : unsigned18;
  signal angle3_update : unsigned16;
  signal positive3 : boolean;
  signal start3 : boolean;

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
      qq2 <= qq1;
      ii2 <= ii1;
      angle2 <= angle1;
      positive2 <= positive1;

      qq3 <= qq2;
      -- Include left shift.  If this loses a bit, then the trial will succeed
      -- anyway, and get us back.
      ii3 <= ii2 sll 1;
      angle3 <= angle2;
      positive3 <= positive2;

      qq1 <= qq3;
      ii1 <= ii3;
      angle1 <= angle3;
      positive1 <= positive3;

      -- First pipeline stage is the right shift.  Note that for the start
      -- iteration, the high bit of ii is still zero, so the high bit of
      -- ii_shifted will always be zero.
      ii2_shifted <= ii1 srl (2 * (count mod 16));
      load2 <= (count = 19);

      -- Second pipeline stage is the trial operation.  It also handles the
      -- loading of data into the pipeline.
      qq3_trial <= qq2 + ii2_shifted(35 downto 0);
      -- Note that ii is at most twice the 36 bit qq, so if the arithmetic does
      -- not overflow, then the result of the subtract will fit in 36 bits.
      -- Except for round-0 (where we normalise to the first octant).  In that
      -- case everything is 36 bits.
      ii3_trial <= ii2 - ('0' & qq2);
      angle3_update <= angle_update(iteration2(count));

      if load2 then
        ii3_trial(36) <= '1'; -- Make sure we don't adjust on next cycle.
        -- 'not' is cheaper than proper true negation.  And given our
        -- round-towards-negative behaviour, more accurate.
        if qq_in(35) = '0' then
          qq3 <= unsigned(qq_in);
        else
          qq3 <= not unsigned(qq_in);
        end if;
        if ii_in(35) = '0' then
          ii3 <= '0' & unsigned(ii_in);
        else
          ii3 <= '0' & not unsigned(ii_in);
        end if;
        positive3 <= (qq_in(35) xor ii_in(35)) = '1';
        -- Our convention is that angle zero covers the first sliver of the
        -- first quadrant etc., so bias the start angle just into the
        -- appropriate quadrant.  Yes the 0=>1 looks like a step too far,
        -- but after exhaustive testing, it gives better results, presumably
        -- because of the granularity of the result.
        angle3 <= (17 => ii_in(35), 0 => '1',
                   others => qq_in(35) xor ii_in(35));
        phase <= angle2; -- ship out previous result.
      end if;

      -- Third pipeline stage is commitment.
      if ii3_trial(36) = '0' then
        if not start3 then
          qq1 <= qq3_trial;
          -- ii got left shifted at the previous stage, but ii_trial did not.
          -- so take that into account.
          ii1 <= ii3_trial sll 1;
        else
          -- No overflow, ii is bigger than qq, so swap things over.  Remember
          -- that ii got left shifted, so take that into account in the swap.
          qq1 <= ii3(36 downto 1);
          ii1 <= qq3 & '0';
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
