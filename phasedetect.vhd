library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

entity phasedetect is
  port(qq : in signed36; -- overkill, should have reduced to 18 bits by now.
       ii : in signed36;
       phase : out unsigned18;
       clk : in std_logic);
end go;

-- The main phase detect uses a pipeline, 16 iterations, main usage is
-- (iterations 1 to 15):
-- stage1: ii_div = ii right-shifted (by 2n).
-- stage2: trial qq' = qq + ii_div, ii' = ii - qq
-- stage3: commit, if ii' has not underflown, update angle.

-- We want to reuse the first time through the pipeline:
-- shift=0.  If no underflow, then swap qq and ii.
-- We load every 17 or 20 (?) cycles,
-- and ship out 48 cycles latter (with post-processing).

architecture Behavioral of phasedetect is
  signal qq1 : unsigned36; -- Real component.
  signal ii1 : unsigned36; -- Imaginary component.
  signal angle1 : signed18; -- Accumulated angle.
  signal overflow_expect1 : std_logic; -- Desirable overflow bit.
  signal clockwise1 : boolean; -- Rotate clockwise in complex plane.
  signal positive1 : boolean; -- Positive adjustments to angle.
  signal start1 : boolean;

  signal qq2 : unsigned36;
  signal ii2 : unsigned36;
  signal ii2_shifted : unsigned36;
  signal angle2 : signed18;
  signal overflow_expect2 : std_logic;
  signal clockwise2 : boolean;
  signal positive2 : boolean;
  signal start2 : boolean;
  signal load2 : boolean;

  signal qq3 : unsigned36;
  signal ii3 : unsigned36;
  signal qq3_trial : unsigned36;
  signal ii3_trial : unsigned36;
  signal ii3_trial_overflow : std_logic;
  signal angle3 : signed28;
  signal overflow_expect3 : std_logic;
  signal clockwise3 : boolean;
  signal positive3 : boolean;
  signal start3 : boolean;

  signal count : integer range 0..19;
  type stage_t is array(0 to 19) of integer range 0..19;
  -- For pipeline stage 1, map the cycle counter to the iteration of the
  -- calculation.
  constant iteration1 : stage_t :=
    (0, 7, 14, 1, 8, 15, 2, 9, 16, 3, 10, 17, 4, 11, 18, 5, 12, 19, 6, 13);
  -- Iteration number for pipeline stage 2.
  constant iteration2 : stage_t :=
    (13, 0, 7, 14, 1, 8, 15, 2, 9, 16, 3, 10, 17, 4, 11, 18, 5, 12, 19, 6);
  -- Iteration number for pipeline stage 3.
  constant iteration3 : stage_t :=
    (6, 13, 0, 7, 14, 1, 8, 15, 2, 9, 16, 3, 10, 17, 4, 11, 18, 5, 12, 19);

begin
  process (clk)
  begin
    if clk'event and clk = '1' then
      if count = 19 then
        count <= 0;
        start1 <= true;
      else
        count <= count + 1;
        start1 <= false;
      end if;
    end if;

    -- The default flow is just to cycle things around; override later if
    -- need be.
    qq2 <= qq1;
    ii2 <= ii1;
    angle2 <= angle1;
    overflow_expect2 <= overflow_expect1;
    clockwise2 <= clockwise1;
    positive2 <= postive1;
    start2 <= start1;

    qq3 <= qq2;
    ii3 <= ii2[34 downto 1] & '0'; -- left shift by 1.(FIXME - round to zero?)
    angle3 <= angle2;
    overflow_expect3 <= overflow_expect2;
    clockwise3 <= clockwise2;
    positive3 <= postive2;
    start3 <= start2;

    qq1 <= qq3;
    ii1 <= ii3;
    angle1 <= angle3;
    overflow_expect1 <= overflow_expect3;
    clockwise1 <= clockwise3;
    postive3 <= positive2;

    -- First pipeline stage is the right shift.
    ii2_shifted <= right_shift(ii1, 2*iteration1(count));
    load2 <= (iteration1(count) = 19);

    -- Second pipeline stage is the trial operation.  It also handles the
    -- loading of data into the pipeline.
    if clockwise2 then
      qq3_trial <= qq2 + ii2_shifted;
      ii3_trial_overflow & ii3_trial <= (overflow_expect2 & ii2) - ('1' & qq2);
    else
      qq3_trial <= qq2 - ii2_shifted;
      ii3_trial_overflow & ii3_trial <= (overflow_expect2 & ii2) + ('0' & qq2);
    end if;

    if load2 then
      ii3_trial_overflow = '1'; -- Make sure we don't adjust on next cycle.
      qq3 <= qq;
      ii3_sign & ii3 <= ii & '0';
      positive3 <= (qq < 0) xor (ii < 0);
      clockwise3 <= (qq < 0) xor (ii < 0);
      overflow_expect3 <= not qq[35] xor ii[35];
      angle3 <= (17 => ii[35], others => qq[35] xor ii[35]);
    end if;

    -- Third pipeline stage is commitment.
    if ii3_trial_overflow == '0' then
      if !start3 then
        qq1 <= qq3_trial;
        ii3_trial_overflow3 <= ii3_trial;
      else
        -- No overflow, ii is bigger than qq, swap things over.
        qq1 <= ii3;
        ii1 <= qq3;
        positive1 <= not positive3;
      end if;

      if positive3 then
        angle1 <= angle3 + angle_update;
      else
        angle1 <= angle3 - angle_update;
      end if;
    end if;

  end process;

end Behavioral;
