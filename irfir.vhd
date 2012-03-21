-- Intermediate rate FIR.
-- Take the 4 x 3.125MHz output from the phase detector, and filter
-- downto 4 x 312.5kHz [hmmmm... could go down to 250kHz.]
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity irfir is
  generic(acc_width : integer := 40;
          out_width : integer := 18);
  port(d : in unsigned18;
       q : out signed(out_width - 1 downto 0);
       q_strobe : out std_logic; -- Asserted on the first cycle with new data.
       clk : in std_logic);
end irfir;

architecture behavioural of irfir is
  -- Layout of the command word:
  -- 18 bits multiplier.
  -- 1 bit in sample strobe.
  -- 1 bit out strobe.
  -- 1 bit pc reset.
  -- 1 bit read reset.
  -- 1 bit mac accumulate/reset control.
  subtype command_t is std_logic_vector(23 downto 0);
  type program_t is array(0 to 255) of command_t;
  signal program : program_t := (
    x"440000", x"00000b", x"48000d", x"400014", x"40001c",
    x"400025", x"40002e", x"400037", x"40003e", x"400042",
    x"400042", x"40003c", x"40002f", x"400019", x"43fff9",
    x"43ffd0", x"43ff9d", x"43ff62", x"43ff20", x"43fedb",
    x"47fe97", x"43fe57", x"43fe21", x"43fdfa", x"43fde8",
    x"43fdf0", x"43fe15", x"43fe5a", x"43fec1", x"43ff47",
    x"43ffe9", x"4000a0", x"400166", x"40022d", x"4002eb",
    x"400392", x"400413", x"400461", x"400472", x"40043b",
    x"4403b7", x"4002e6", x"4001cc", x"400072", x"43fee7",
    x"43fd40", x"43fb96", x"43fa03", x"43f8a5", x"43f799",
    x"43f6fa", x"43f6df", x"43f757", x"43f86b", x"43fa18",
    x"43fc55", x"43ff08", x"400213", x"40054a", x"40087c",
    x"440b74", x"400df8", x"400fd5", x"4010d9", x"4010e0",
    x"400fcf", x"400d9e", x"400a56", x"400613", x"400106",
    x"43fb6e", x"43f59e", x"43eff1", x"43eac8", x"43e687",
    x"43e389", x"43e21f", x"43e285", x"43e4de", x"43e933",
    x"47ef69", x"43f746", x"40006e", x"400a67", x"40149f",
    x"401e74", x"402739", x"402e43", x"4032f3", x"4034c3",
    x"40334b", x"402e53", x"4025d1", x"4019f5", x"400b29",
    x"43fa0f", x"43e77e", x"43d47b", x"43c22c", x"43b1ce",
    x"47a4a3", x"439be3", x"4398a9", x"439be5", x"43a64d",
    x"43b84b", x"43d1fb", x"43f31f", x"401b1f", x"40490c",
    x"407ba7", x"40b16d", x"40e8a4", x"411f71", x"4153e8",
    x"418426", x"41ae63", x"41d10a", x"41eac9", x"41faa4",
    x"45ffff", x"41faa4", x"41eac9", x"41d10a", x"41ae63",
    x"418426", x"4153e8", x"411f71", x"40e8a4", x"40b16d",
    x"407ba7", x"40490c", x"401b1f", x"43f31f", x"43d1fb",
    x"43b84b", x"43a64d", x"439be5", x"4398a9", x"439be3",
    x"47a4a3", x"43b1ce", x"43c22c", x"43d47b", x"43e77e",
    x"43fa0f", x"400b29", x"4019f5", x"4025d1", x"402e53",
    x"40334b", x"4034c3", x"4032f3", x"402e43", x"402739",
    x"401e74", x"40149f", x"400a67", x"40006e", x"43f746",
    x"47ef69", x"43e933", x"43e4de", x"43e285", x"43e21f",
    x"43e389", x"43e687", x"43eac8", x"43eff1", x"43f59e",
    x"43fb6e", x"400106", x"400613", x"400a56", x"400d9e",
    x"400fcf", x"4010e0", x"4010d9", x"400fd5", x"400df8",
    x"440b74", x"40087c", x"40054a", x"400213", x"43ff08",
    x"43fc55", x"43fa18", x"43f86b", x"43f757", x"43f6df",
    x"43f6fa", x"43f799", x"43f8a5", x"43fa03", x"43fb96",
    x"43fd40", x"43fee7", x"400072", x"4001cc", x"4002e6",
    x"4403b7", x"40043b", x"400472", x"400461", x"400413",
    x"400392", x"4002eb", x"40022d", x"400166", x"4000a0",
    x"43ffe9", x"43ff47", x"43fec1", x"43fe5a", x"43fe15",
    x"43fdf0", x"43fde8", x"43fdfa", x"43fe21", x"43fe57",
    x"47fe97", x"43fedb", x"43ff20", x"43ff62", x"43ff9d",
    x"43ffd0", x"43fff9", x"400019", x"40002f", x"40003c",
    x"400042", x"400042", x"40003e", x"400037", x"40002e",
    x"400025", x"60001c", x"500014", x"40000d", x"40000b",
    others => x"000000");

  signal command : command_t := (others => '0');
  type buff_t is array(0 to 1023) of signed18;
  signal buff : buff_t := (others => "00" & x"0000");

  signal pc : unsigned8 := x"00";
  signal write_pointer : unsigned10 := "0000000000";
  signal read_pointer : unsigned10 := "0000000001";
  signal read_pointer_1 : unsigned10 := "0000000000";

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
    variable rp_addend : unsigned10;
    variable rp_increment : unsigned10;
  begin
    wait until rising_edge(clk);

    command <= program(to_integer(pc));
    if pc_reset = '1' then
      pc <= (others => '0');
    else
      pc <= pc + 1;
    end if;

    -- Unpack the command.
    coef_1        <= signed(command(17 downto 0));
    sample_strobe <= command(18);
    out_strobe    <= command(19);
    pc_reset      <= command(20);
    read_reset    <= command(21);
    mac_accum     <= command(22);

    -- Input processing...
    if sample_strobe = '1' then
      buff(to_integer(write_pointer)) <= signed(d);
      write_pointer <= write_pointer + 1;
    end if;

    -- DSP input buffering.
    data_1 <= buff(to_integer(read_pointer_1));
    data_2 <= data_1;
    data_3 <= data_2;
    coef_2 <= coef_1;
    mac_accum_1 <= mac_accum;

    -- DSP
    diff <= data_2 - data_3;

    product <= diff * coef_2;

    if mac_accum_1 = '0' then
      acc_addend := (others => '0');
    else
      acc_addend := accumulator;
    end if;
    accumulator <= acc_addend + product;

    if out_strobe = '1' then
      q <= accumulator(acc_width - 1 downto acc_width - out_width);
    end if;
    q_strobe <= out_strobe;

    -- buff pointer update.
    if read_reset = '1' then
      rp_addend := write_pointer(9 downto 2) & channel;
      channel <= channel + 1;
      rp_increment := "00" & x"40";
    else
      rp_addend := read_pointer;
      rp_increment := "00" & x"04";
    end if;
    read_pointer <= rp_addend + rp_increment;
    read_pointer_1 <= read_pointer;
  end process;
end behavioural;
