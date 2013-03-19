library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

-- This does one half of the downconverter, either real or imaginary.
entity dc1 is
  generic(minus_sin : boolean);
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
    product <= prod;

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

  cos : entity work.dc1 generic map(minus_sin => false)
    port map(data, gain(3 downto 0), open, xx, phase(23 downto 10), clk,
             cos_index, cos_packed);
  sin : entity work.dc1 generic map(minus_sin => true)
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
          gain   : in  unsigned8;
          decay  : in  unsigned(3 downto 0);
          xx, yy : out signed36;
          freq_in : in  unsigned24;
          freq_in_strobe : in std_logic;
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
  -- beta is 1/2 ** (11 + decay),
  -- alpha is 2 ** (14 + decay).
  -- [so beta is in range 1/2048 to 1/262144, might want to allow lower
  -- bandwidth]

  -- and we want gamma around 1/27 * 1/2 ** (33 + 3*decay)

  -- gamma is given by shifting and the multiplier scaling.

  -- Around phase=0 [and gain=0], the normalisation of our "sin" function is
  -- d/dphase "sin"(phase) is 1/2 ** (phase_width - 13), i.e, a step at
  -- bit (phase_width - 14) produces a step of 2 LSB of the "sin".
  -- The overall mean multiplier of the trig multiply is halved and takes the
  -- gain signal into account giving a mean multiplier of
  -- 2 ** (gain + 12 - phase_width).
  -- gamma is then composed of that, the signal strength [in units of LSB],
  -- and a shift, i.e., we want
  -- 1/27 * 1/2 ** (33 + 3*decay) = strength * 2 ** (gain + 12 - phase_width) *
  -- shift

  -- 1 = 27 * strength * shift * 2 ** (gain + 45 + 3 * decay - phase_width)
  -- Design for gain to be set so that strength * 2**gain = 2**14.
  -- Approximate 27 by 32, this gives
  -- 1 = shift * 2 ** (64 + 3 * decay - phase_width)
  -- shift = 1/2 ** (64 - phase_width + 3 * decay),  or
  -- shift = 2 ** (phase_width - 64 - 3 * decay)
  -- [i.e., right shift unless phase_width is huge.]

  -- Clearly we are going to achieve some of this shift by dropping bits instead
  -- of making phase_width huge.  I.E., replace phase_width with
  -- (phase_width+bits_dropped).  If we take phase_width+bits_dropped = 85,
  -- then the shift will always be a left shift for decay in 0..7.

  -- The design above gives a shift by (21-3*decay) going into error.
  -- It makes more sense to apply this coming out of error, IE. left shift
  -- (21-3*decay) adding to freq, and left shift (35-2*decay) adding to phase.

  -- All our registers are considered as being embedded in a value this wide.
  constant full_width : integer := 85;

  -- Top 36 of 85 bits. (84 downto 49).
  constant phase_width : integer := 36;
  signal phase : signed(phase_width - 1 downto 0) := (others => '0');

  -- Top 56 of 85 bits. (84 downto 29).
  constant freq_width : integer := 56;
  signal freq : signed(freq_width - 1 downto 0);

  -- 56 bits, with the LSB at position (full_width - 64 - 3*decay) = 21-3*decay
  -- (alternatively LSB at 0 and remember to left shift before use).
  constant error_width : integer := 56;
  signal error : signed(error_width - 1 downto 0);
  signal error_1 : signed(error_width - 11 downto 0);

  -- The left shift by full_width-64-3*decay is achieved by padding by
  -- full_width-64 on the right, and then right shifting by 3*decay.
  constant error_f_w : integer := error_width + full_width - 64;
  signal error_f1 : signed(error_f_w - 1 downto 0);

  signal sin_index, cos_index : unsigned(9 downto 0);
  signal sin_packed, cos_packed : unsigned18;
  signal sintable : sinrom_t := sinrom;

  alias cgain : unsigned(3 downto 0) is gain(3 downto 0);
  alias sgain : unsigned(3 downto 0) is gain(7 downto 4);

  signal product : signed36;
  signal product_1, delta : signed(error_width - 1 downto 0);

  constant error_p_w : integer := error_width + 14;
  signal error_p1 : signed(error_p_w - 1 downto 0);

  signal phase_a : signed(phase_width - 1 downto 0);

  constant freq_in_pad : signed(freq_width - 25 downto 0) := (others => '0');

  -- For some bloody stupid reason, the sra operator doestn't work.
  function ssra(v : signed; a : unsigned; m : integer := 1) return signed is
    variable shift : integer;
    variable result : signed(v'left downto 0);
  begin
    shift := to_integer(a) * m;
    result := (others => v(v'left));
    result(v'left - 1 - shift downto 0) := result(v'left - 1 downto shift);
    return result;
  end ssra;

begin

  cos : entity work.dc1 generic map(minus_sin => false)
    port map(data, cgain, open, xx,
             unsigned(phase(phase_width - 1 downto phase_width - 14)),
             clk, cos_index, cos_packed);
  sin : entity work.dc1 generic map(minus_sin => true)
    port map(data, sgain, open, yy,
             unsigned(phase(phase_width - 1 downto phase_width - 14)),
             clk, sin_index, sin_packed);
  process
    variable error_f0, error_f2 : signed(error_f_w - 1 downto 0);
    variable error_p0 : signed(error_p_w - 1 downto 0);
  begin
    wait until rising_edge(clk);
    cos_packed <= sintable(to_integer(cos_index));
    sin_packed <= sintable(to_integer(sin_index));

    product_1 <= resize(product, error_width)
                 sll to_integer(sgain and "1000");
    error_1 <= ssra(error(error_width - 1 downto 10),
                    decay and "0110");
    delta <= ssra(error_1, decay and "0001") + product_1;
    error <= error - delta;

    error_f0 := (others => '0');
    error_f0(error_f_w - 1 downto error_f_w - error_width) := error;
    error_f1 <= ssra(error_f0, decay and "0110", 3);
    error_f2 := ssra(error_f1, decay and "0001", 3);
    freq <= freq + error_f2(error_f_w - 1 downto full_width - freq_width);

    -- We want to left shift by (14+decay) + (full_width-64-3*decay)
    -- = full_width-50-3*decay = 35-2*decay and then drop
    -- full_width-phase_width = 29 bits to align with phase.
    -- Equivalently we left shift by a lesser amount and drop fewer too.
    -- E.g., left shift by (14-2*decay) and drop
    -- (full_width-phase_width) - (full_width-64) = 64-phase_width = 8 bits.
    error_p0 := (others => '0');
    error_p0(error_width + 13 downto 14) := error;
    error_p1 <= ssra(error_p0, decay and "0110", 2);
    phase_a <= freq(freq_width downto freq_width - phase_width)
               + ssra(error_p1, decay and "0001", 2);
    phase <= phase + phase_a;

    if freq_in_strobe = '1' then
      freq <= (signed(freq_in) & freq_in_pad)
              + error_f2(error_f_w - 1 downto full_width - freq_width);
      error <= (others => '0');
      error_1 <= (others => '0');
      delta <= (others => '0');
      error_f1 <= (others => '0');
    end if;

  end process;
end downconvertpll;
