-- Intermediate rate FIR.
-- Take the 4 x 3.125MHz output from the phase detector, and filter
-- downto 4 x 312.5kHz [hmmmm... could go down to 250kHz.]
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity quadfir is
  generic(acc_width : integer;
          out_width : integer;
          differentiate : boolean;
          index_sample_strobe : integer;
          index_out_strobe : integer;
          index_pc_reset : integer;
          index_read_reset : integer;
          index_mac_accum : integer;
          program_size : integer;
          program : program_t);
  port(d : in signed18;
       d_strobe0 : in std_logic := '0';
       q : out signed(out_width - 1 downto 0);
       q_strobe : out std_logic; -- Asserted on the first cycle with new data.
       q_strobe0 : out std_logic; -- Asserted when output is channel 0.
       clk : in std_logic);
end quadfir;

architecture behavioural of quadfir is
  -- Layout of the command word:
  -- 18 bits multiplier.
  -- 1 bit in sample strobe.
  -- 1 bit out strobe.
  -- 1 bit pc reset.
  -- 1 bit read reset.
  -- 1 bit mac accumulate/reset control.

  subtype program_counter_t is integer range 0 to program_size - 1;

  signal command : command_t := (others => '0');
  --type buff_t is array(0 to 1023) of signed18;
  type buff_t is array(0 to 2047) of signed18;
  signal buff : buff_t := (others => "00" & x"0000");

  signal pc : program_counter_t;

  constant pointer_size : integer := 11;
  subtype pointer_t is unsigned(pointer_size-1 downto 0);
  signal write_pointer  : pointer_t := (others => '0');
  signal read_pointer   : pointer_t := (0 => '1', others=> '0');
  signal read_pointer_1 : pointer_t := (others => '0');

  signal channel : unsigned2 := "00";

  -- Unpacked command.
  signal coef_1 : signed18;
  signal sample_strobe : std_logic;
  signal out_strobe : std_logic;
  signal pc_reset : std_logic := '0';
  signal read_reset : std_logic;

  signal mac_accum : std_logic;
  signal mac_accum_1 : std_logic;
  signal mac_accum_2 : std_logic;

  signal accumulator : signed(acc_width-1 downto 0);

  signal data_1 : signed18;
  signal data_2 : signed18;
  signal data_3 : signed18;
  signal coef_2 : signed18;
  signal diff   : signed18;
  signal product : signed36;

begin

  process
    variable acc_addend : signed(acc_width - 1 downto 0);
    variable rp_addend : pointer_t;
    variable rp_increment : integer;

    variable write_pointer_corrected : pointer_t;
    variable diff_out : signed18;
  begin
    wait until rising_edge(clk);

    command <= program(pc);
    if pc_reset = '1' then
      pc <= 0;
    else
      pc <= pc + 1;
    end if;

    -- Unpack the command.
    coef_1        <= signed(command(17 downto 0));
    sample_strobe <= command(index_sample_strobe);
    out_strobe    <= command(index_out_strobe);
    pc_reset      <= command(index_pc_reset);
    read_reset    <= command(index_read_reset);
    mac_accum     <= command(index_mac_accum);

    -- Input processing...
    if sample_strobe = '1' then
      buff(to_integer(write_pointer)) <= d;
      write_pointer_corrected := write_pointer;
      if d_strobe0 = '1' then
        write_pointer_corrected(1 downto 0) := "00";
      end if;
      write_pointer <= write_pointer_corrected + 1;
    end if;

    -- DSP input buffering.
    data_1 <= buff(to_integer(read_pointer_1));
    data_2 <= data_1;
    data_3 <= data_2;
    coef_2 <= coef_1;
    mac_accum_1 <= mac_accum;

    if differentiate then
      diff <= data_2 - data_3;
      diff_out := diff;
    else
      diff_out := data_2;
    end if;

    -- dsp
    product <= diff_out * coef_2;

    if mac_accum_1 = '0' then
      acc_addend := (others => '0');
    else
      acc_addend := accumulator;
    end if;
    accumulator <= acc_addend + product;

    if out_strobe = '1' then
      q <= accumulator(acc_width - 1 downto acc_width - out_width);
      -- Channel will have already advanced on output.
      q_strobe0 <= b2s(channel = "01");
    end if;
    q_strobe <= out_strobe;

    -- buff pointer update.
    if read_reset = '1' then
      rp_addend := write_pointer(pointer_size-1 downto 2) & channel;
      channel <= channel + 1;
      rp_increment := 64;
    else
      rp_addend := read_pointer;
      rp_increment := 4;
    end if;
    read_pointer <= rp_addend + rp_increment;
    read_pointer_1 <= read_pointer;
  end process;
end behavioural;
