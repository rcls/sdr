library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

-- This does one half of the downconverter, either real or imaginary.
entity dc1 is
  generic(minus_sin : boolean; gen_product : boolean := false);
  port (data : in signed14;
        gain : in unsigned(3 downto 0);
        product : out signed36;
        q : out signed36;
        phase : in unsigned(13 downto 0);
        clk : in std_logic;
        index : out unsigned(9 downto 0);
        packed : in unsigned18);
end dc1;

architecture dc1 of dc1 is
  constant width : integer := 48;
  subtype accumulator is signed(width - 1 downto 0);

  --signal index : unsigned(9 downto 0);
  signal low, low_2 : unsigned(1 downto 0);

  signal minus : std_logic_vector(1 to 5);

  signal main, offset : unsigned18;

  signal data_3 : signed14;

  signal main_4, main_5, offset_4, offset_5, trig : signed18;
  signal data_4, data_5, data_6 : signed18;

  signal prod : signed36;

  signal buf, buf_9, acc : accumulator;

  attribute use_dsp48 : string;
  attribute use_dsp48 of acc : signal is "no";
begin
  process
  begin
    wait until rising_edge(clk);

    -- Unpack the accumulator to the indexes and signs.
    -- Maybe we should have separate tables for
    -- sines and cosines...
    if minus_sin then
      if phase(12) = '1' then
        index <= not phase(11 downto 2);
        low <= not phase(1 downto 0);
      else
        index <= phase(11 downto 2);
        low <= phase(1 downto 0);
      end if;
      -- We are down-converting not up converting, so we want to use -sin.
      minus(1) <= not phase(13);
    else
      if phase(12) = '1' then
        index <= phase(11 downto 2);
        low <= phase(1 downto 0);
      else
        index <= not phase(11 downto 2);
        low <= not phase(1 downto 0);
      end if;
      minus(1) <= phase(13) xor phase(12);
    end if;
    minus(2 to 5) <= minus(1 to 4);

    -- Lookup the sin and cos tables. - done a level up.
    --packed <= sintable(to_integer(index));
    low_2 <= low;

    -- Prepare the sin and cos.
    main <= packed and "00" & x"3fff";
    offset <= resize(sinoffset(packed, low_2), 18);
    data_3 <= data;

    -- Apply gain(1,0) to sin & cos, & gain(2) to data.
    if gain(2) = '0' then
      data_4 <= resize(data_3, 18);
    else
      data_4 <= data_3 & "0000";
    end if;

    main_4 <= signed(main) sll to_integer(gain(1 downto 0));
    if minus(4) = '1' then
      offset_4 <= -signed(offset) sll to_integer(gain(1 downto 0));
    else
      offset_4 <= signed(offset) sll to_integer(gain(1 downto 0));
    end if;

    -- Buffer.
    main_5 <= main_4;
    offset_5 <= offset_4;
    data_5 <= data_4;

    -- Pre-add.
    if minus(5) = '1' then
      trig <= offset_5 + main_5;
    else
      trig <= offset_5 - main_5;
    end if;
    data_6 <= data_5;

    -- Multiply
    prod <= data_6 * trig;

    -- Post add (8).
    buf <= buf + prod;
    if gen_product then
      product <= prod;
    end if;

    -- Buffer.
    buf_9 <= buf;

    -- Second order accumulate, applying gain(3).
    if gain(3) = '0' then
      acc <= acc + buf_9;
    else
      acc <= acc + (buf_9 sll 8);
    end if;

    q <= acc(width - 1 downto width - 36);
  end process;
end dc1;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

entity downconvert is
  port (data   : in  signed14;
        gain   : in  unsigned8;
        xx, yy : out signed36;
        freq   : in  unsigned24;
        clk    : in  std_logic);
end downconvert;

architecture downconvert of downconvert is

  -- For the cosine/sine lookup, we take a 14 bit quantity.  The first two bits
  -- determine the quadrant, the middle ten the table index, and the bottom
  -- two determine the fine adjustment.  For cosine, the quadrant processing is:

  -- quadrant 00 : invert bottom 12 bits (rom index & fine adjust index).
  -- quadrant 01 : cosine is negative.
  -- quadrant 10 : invert bottom 12 bits, cosine is negative.
  -- quadrant 11 : as looked up.

  -- Sine is identical, except that the quadrant is processed differently:
  -- quadrant 00 : as looked up.
  -- quadrant 01 : invert bottom 12 bits.
  -- quadrant 10 : sin is negative.
  -- quadrant 11 : invert bottom 12 bits, sin is negative.

  -- The (co)sines are scaled to range from 0 to 2^14/pi (and sign bit).
  -- The average abs(sin) is 2/pi, after scaling 2^15/pi^2
  -- Data sample is 13 bits plus sign, so worst case average multiplier
  -- output is signed 2^28/pi^2, [just under] 25 bits plus sign.  (Before taking
  -- the shift due to 'gain' into account.)

  -- e.g., accumulating over 1024 samples needs 35 bits plus sign.
  -- second order accumulation needs 45 bits plus sign.  Use all 48 bits...
  signal phase : unsigned24 := x"000000";
  signal sin_index, cos_index : unsigned(9 downto 0);
  signal sin_packed, cos_packed : unsigned18;
  signal sintable : sinrom_t := sinrom;
begin

  cos : entity work.dc1 generic map(false)
    port map(data, gain(3 downto 0), open, xx, phase(23 downto 10), clk,
             cos_index, cos_packed);
  sin : entity work.dc1 generic map(true)
    port map(data, gain(3 downto 0), open, yy, phase(23 downto 10), clk,
             sin_index, sin_packed);
  process
  begin
    wait until rising_edge(clk);
    phase <= phase + freq;
    cos_packed <= sintable(to_integer(cos_index));
    sin_packed <= sintable(to_integer(sin_index));
  end process;
end downconvert;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

entity downconvertpll is
  port (data   : in  signed14;
        freq_in : in  unsigned24;
        gain   : in  unsigned8;
        decay  : in  unsigned(3 downto 0);
        freq_in_strobe : in std_logic;
        xx, yy : out signed36;
        phasor : out unsigned18;
        freq_out : out unsigned(31 downto 0);
        error_out : out unsigned(31 downto 0);
        level_out : out unsigned(31 downto 0);
        out_strobe : in std_logic;
        clk    : in  std_logic);
end downconvertpll;

architecture downconvertpll of downconvertpll is

  -- Our control loop looks like:
  --
  -- d/dt phase = freq + alpha error,
  -- d/dt freq = error
  -- d/dt error = -beta error - gamma phase
  --
  -- (counting t in clk cycles).
  -- Eigenpolynomial is
  -- lambda**3 + beta lambda**2 + alpha gamma lambda + gamma.
  -- We are aiming for (lambda + beta/3)**3,
  -- i.e., alpha gamma = beta**2 / 3, gamma = beta**3 / 27,
  -- alpha = 9 / beta.
  -- For convenience, take alpha = 8/beta so we can use bit shifts.
  -- beta is 1/2 ** (beta_base + decay),
  -- alpha is 2 ** (alpha_base + decay).
  -- alpha_base = 14 = 3 + beta_base, beta_base = 11.
  -- [so beta is in range 1/2048 to 1/262144, might want to allow lower
  -- bandwidth]

  -- and we want gamma around 1/27 * 1/2 ** (3*beta_base + 3*decay)

  -- gamma is given by shifting and the multiplier scaling.

  -- We phase to number of cycles, and t to be discrete number of clock cycles,
  -- so that phase, freq and error can all be taken (mod 1).

  -- Around phase=0 [and gain=0], the normalisation of our "sin" function is
  -- d/dphase "sin"(phase) is 1/2 ** (-13), i.e, a step at
  -- bit (-14) produces a step of 2 LSB of the "sin".
  -- The overall mean multiplier of the trig multiply is halved and takes the
  -- gain signal into account giving a mean multiplier of
  -- 2 ** (gain + 12).
  -- gamma is then composed of that, the signal strength [in units of LSB],
  -- and a shift, i.e., we want
  -- 1/27 * 1/2 ** (3*beta_base + 3*decay) = strength * 2 ** (gain + 12) * shift
  -- 1 = 27 * strength * shift * 2 ** (gain + 12 + 3*beta_base + 3 * decay)
  -- Design for gain to be set so that strength * 2**gain = 2**10
  -- = 2**target_width.
  -- Approximate 27 by 32, this gives
  -- 1 = shift * 2 ** (3*beta_base + 3 * decay + target_width + 17)
  -- shift = 1/2 ** (17 + 3*beta_base + target_width + 3 * decay),  or

  -- The design above gives a shift going into error.
  -- It makes more sense to apply this coming out of error, than going in.

  -- Fixed point, range [0,1).  MSB has weight 0.5.
  constant phase_width : integer := 32;
  signal phase : signed(phase_width - 1 downto 0) := (others => '0');

  constant beta_base : integer := 8;
  constant alpha_base : integer := beta_base + 3;

  -- Fixed point, MSB has weight 0.5.
  constant freq_width : integer := 56;
  signal freq : signed(freq_width - 1 downto 0);

  -- Target signal strength.  The signal level should be about target_width
  -- bits, after left shifting by the gain.
  constant target_width : integer := 10;

  -- Error (and level) are fix point with the LSB at position
  -- (- 60 - 3*decay + error_drop).
  constant error_width : integer := 32;
  constant level_width : integer := 40;
  constant error_drop : integer := 12;
  constant level_drop : integer := 12;

  signal error : signed(error_width - 1 downto 0);
  signal level : signed(level_width - 1 downto 0);
  -- These include an extra low bit for use in rounding.
  signal error_1 : signed(error_width - beta_base downto 0);
  signal level_1 : signed(level_width - beta_base downto 0);

  -- For the error scaling we need to right shift by
  -- 17 + 3*beta_base + target_width + 3*decay - error_drop.
  -- For the alignment with freq, left shift by freq_width.
  -- We actually left shift by 33 by padding, right shift by 3*decay,
  -- and right shift by 50+3*beta_base+target_width-freq_width
  -- -error_drop by selecting.
  constant error_f_w : integer := error_width + 33;
  constant error_f_base : integer := 50 + 3 * beta_base + target_width
                                     - freq_width - error_drop;
  signal error_f1 : signed(error_f_w - 1 downto 0);

  signal sin_index, cos_index : unsigned(9 downto 0);
  signal sin_packed, cos_packed : unsigned18;
  signal sintable : sinrom_t := sinrom;

  alias cgain : unsigned(3 downto 0) is gain(3 downto 0);
  alias sgain : unsigned(3 downto 0) is gain(7 downto 4);

  signal sproduct, cproduct : signed36;
  signal sproduct_1, sdelta : signed(error_width - 1 downto 0);
  signal cproduct_1, cdelta : signed(level_width - 1 downto 0);
  signal sproduct_r, cproduct_r, sproduct_r2, cproduct_r2 : std_logic;

  -- For the error scaling we need to right shift by
  -- 17 + 3*beta_base + target_width + 3*decay - error_drop.
  -- For beta we need to left shift by alpha_base + decay.
  -- For the alignment with phase, left shift by phase_width.
  -- We actually pad by 22, and then right shift by 2*decay, and then
  -- right shift (by selection) by
  -- 39 + 3*beta_base + target_width - error_drop - alpha_base - phase_width.
  constant error_p_w : integer := error_width + 22;
  constant error_p_base : integer := 39 + 3*beta_base + target_width
                                     - error_drop - alpha_base - phase_width;
  constant error_p_max : integer := minimum(error_p_w,
                                            error_p_base + phase_width);
  signal error_p1 : signed(error_p_w - 1 downto 0);

  signal phase_a : signed(phase_width - 1 downto 0);

  constant freq_in_pad : signed(freq_width - 25 downto 0) := (others => '0');

  signal base_phase : unsigned24;

  -- For some bloody stupid reason, the sra operator doesn't work.
  function ssra(val : signed; a : unsigned; m : integer := 1) return signed is
    variable v : signed(val'length + 11 * m - 1 downto 0);
    variable result : signed(val'length - 1 downto 0);
    variable aa : unsigned(3 downto 0);
  begin
    aa := a;
    if aa(3) = '1' then
      aa(2) := '0';                     -- Limit range to 0..11
    end if;
    v := (others => val(val'left));
    v(val'length - 1 downto 0) := val;
    result := v(val'length - 1 downto 0);
    for i in 1 to 11 loop
      if to_integer(aa) = i then
        result := v(val'length - 1 + i * m downto i * m);
      end if;
    end loop;
    return result;
  end ssra;

  function top(val : signed; n : integer) return signed is
    variable result : signed(n - 1 downto 0);
  begin
    result := val(val'left downto val'left + 1 - n);
    return result;
  end top;
  function topd(val : signed; n : integer) return std_logic is
  begin
    return val(val'left - n);
  end topd;

begin

  cos : entity work.dc1 generic map(false, true)
    port map(data, cgain, cproduct, xx,
             unsigned(phase(phase_width - 1 downto phase_width - 14)),
             clk, cos_index, cos_packed);
  sin : entity work.dc1 generic map(true, true)
    port map(data, sgain, sproduct, yy,
             unsigned(phase(phase_width - 1 downto phase_width - 14)),
             clk, sin_index, sin_packed);
  process
    variable error_1b : signed(error_width - beta_base downto 0);
    variable level_1b : signed(level_width - beta_base downto 0);
    variable error_f0, error_f2 : signed(error_f_w - 1 downto 0);
    variable error_p0, error_p2 : signed(error_p_w - 1 downto 0);
  begin
    wait until rising_edge(clk);

    cos_packed <= sintable(to_integer(cos_index));
    sin_packed <= sintable(to_integer(sin_index));

    sproduct_1 <= top(resize(sproduct, error_width + error_drop)
                      sll to_integer(sgain and "1000"),
                      error_width);
    sproduct_r <= topd(resize(sproduct, error_width + error_drop)
                       sll to_integer(sgain and "1000"),
                       error_width);
    cproduct_1 <= top(resize(cproduct, level_width + level_drop)
                      sll to_integer(cgain and "1000"),
                      level_width);
    cproduct_r <= topd(resize(cproduct, level_width + level_drop)
                       sll to_integer(cgain and "1000"),
                       level_width);
    error_1 <= ssra(error(error_width - 1 downto beta_base - 1),
                    decay and "0011");
    level_1 <= ssra(level(level_width - 1 downto beta_base - 1),
                    decay and "0011");
    error_1b := ssra(error_1, decay and "1100");
    level_1b := ssra(level_1, decay and "1100");
    sdelta <= sproduct_1 - error_1b(error_width - beta_base downto 1)
              - ("0" & error_1b(0));
    cdelta <= cproduct_1 - level_1b(level_width - beta_base downto 1)
              - ("0" & level_1b(0));
    sproduct_r2 <= sproduct_r;
    cproduct_r2 <= cproduct_r;
    error <= error + sdelta + ("0" & sproduct_r2);
    level <= level + cdelta + ("0" & cproduct_r2);

    error_f0 := (others => '0');
    error_f0(error_f_w - 1 downto error_f_w - error_width) := error;
    error_f1 <= ssra(error_f0, decay and "0011", 3);
    error_f2 := ssra(error_f1, decay and "1100", 3);
    freq <= freq + error_f2(error_f_w - 1 downto error_f_base)
            + ("0" & error_f2(error_f_base - 1));

    error_p0 := (others => '0');
    error_p0(error_p_w - 1 downto error_p_w - error_width) := error;
    error_p1 <= ssra(error_p0, decay and "0011", 2);
    error_p2 := ssra(error_p1, decay and "1100", 2);
    phase_a <= freq(freq_width - 1 downto freq_width - phase_width)
               + error_p2(error_p_max - 1 downto error_p_base)
               + ("0" & error_p2(error_p_base - 1));
    phase <= phase + phase_a;

    if freq_in_strobe = '1' then
      freq <= (signed(freq_in) & freq_in_pad)
              + error_f2(error_f_w - 1 downto error_f_base)
              + ("0" & error_f2(error_f_base - 1));
      error <= (others => '0');
      level <= (others => '0');
      error_1 <= (others => '0');
      level_1 <= (others => '0');
      sdelta <= (others => '0');
      cdelta <= (others => '0');
      error_f1 <= (others => '0');
    end if;

    if out_strobe = '1' then
      freq_out <= unsigned(freq(freq'left downto freq'left - 31));
      error_out <= unsigned(error(error'left downto error'left - 31));
      level_out <= unsigned(level(level'left downto level'left - 31));
    end if;

    base_phase <= base_phase + freq_in;
    phasor <= unsigned(phase(phase_width - 1 downto phase_width - 18))
              - base_phase(23 downto 6);
  end process;
end downconvertpll;
