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
  constant order : integer := 400;
  type program_t is array(0 to order-1) of command_t;
  signal program : program_t := (
    x"440000", x"000043", x"48001f", x"400030", x"400036",
    x"400043", x"40004d", x"40005a", x"400066", x"400072",
    x"40007e", x"400089", x"400093", x"40009c", x"4000a3",
    x"4000a7", x"4000aa", x"4000a7", x"4000a5", x"400095",
    x"440093", x"40001d", x"40003f", x"400008", x"43ffe3",
    x"43ffaa", x"43ff74", x"43ff33", x"43fef1", x"43fea9",
    x"43fe60", x"43fe15", x"43fdc9", x"43fd7e", x"43fd34",
    x"43fcf0", x"43fcae", x"43fc79", x"43fc42", x"43fc30",
    x"47fbf8", x"43fc8e", x"43fc33", x"43fc72", x"43fc97",
    x"43fce9", x"43fd3c", x"43fdab", x"43fe24", x"43feb1",
    x"43ff48", x"43ffec", x"40009a", x"40014d", x"400206",
    x"4002ba", x"400372", x"400416", x"4004c3", x"40052b",
    x"4405e4", x"40055c", x"40062e", x"400617", x"400620",
    x"4005dd", x"40058e", x"400509", x"40046b", x"4003a3",
    x"4002bd", x"4001b7", x"400096", x"43ff62", x"43fe18",
    x"43fccc", x"43fb6e", x"43fa2a", x"43f8cc", x"43f7e0",
    x"47f65f", x"43f6a8", x"43f526", x"43f4e7", x"43f484",
    x"43f497", x"43f4c6", x"43f550", x"43f60d", x"43f719",
    x"43f860", x"43f9e7", x"43fba8", x"43fd97", x"43ffb9",
    x"4001ed", x"40044d", x"400693", x"40090f", x"400ae5",
    x"440dad", x"400e17", x"4010b8", x"4011ba", x"4012dd",
    x"401357", x"401399", x"40134c", x"4012a2", x"401176",
    x"400fdc", x"400dce", x"400b52", x"400878", x"40053b",
    x"4001c6", x"43fdf8", x"43fa33", x"43f60b", x"43f2ba",
    x"47edff", x"43ec31", x"43e7cb", x"43e55a", x"43e2d3",
    x"43e12e", x"43dfee", x"43df7e", x"43dfad", x"43e0ab",
    x"43e265", x"43e4e7", x"43e82c", x"43ec20", x"43f0cf",
    x"43f5fd", x"43fbd6", x"4001d6", x"400889", x"400e4b",
    x"441611", x"401a79", x"4021cb", x"4026e9", x"402c0e",
    x"403012", x"403374", x"4035ac", x"4036e3", x"4036d6",
    x"40358d", x"4032f2", x"402efe", x"4029c3", x"40232c",
    x"401b81", x"401287", x"4008e4", x"43fdef", x"43f3b5",
    x"47e698", x"43dced", x"43cff6", x"43c52f", x"43ba5b",
    x"43b0d4", x"43a834", x"43a130", x"439bc1", x"439856",
    x"43970b", x"439820", x"439bc3", x"43a201", x"43ab1a",
    x"43b6dc", x"43c5aa", x"43d6e2", x"43eb62", x"4000db",
    x"441b9a", x"4034a2", x"4052f0", x"4070ff", x"409100",
    x"40b180", x"40d2cc", x"40f40d", x"411521", x"41356f",
    x"4154a6", x"417254", x"418e0b", x"41a784", x"41be3b",
    x"41d225", x"41e290", x"41efea", x"41f8f8", x"41ffff",
    x"45fff5", x"41ffff", x"41f8f8", x"41efea", x"41e290",
    x"41d225", x"41be3b", x"41a784", x"418e0b", x"417254",
    x"4154a6", x"41356f", x"411521", x"40f40d", x"40d2cc",
    x"40b180", x"409100", x"4070ff", x"4052f0", x"4034a2",
    x"441b9a", x"4000db", x"43eb62", x"43d6e2", x"43c5aa",
    x"43b6dc", x"43ab1a", x"43a201", x"439bc3", x"439820",
    x"43970b", x"439856", x"439bc1", x"43a130", x"43a834",
    x"43b0d4", x"43ba5b", x"43c52f", x"43cff6", x"43dced",
    x"47e698", x"43f3b5", x"43fdef", x"4008e4", x"401287",
    x"401b81", x"40232c", x"4029c3", x"402efe", x"4032f2",
    x"40358d", x"4036d6", x"4036e3", x"4035ac", x"403374",
    x"403012", x"402c0e", x"4026e9", x"4021cb", x"401a79",
    x"441611", x"400e4b", x"400889", x"4001d6", x"43fbd6",
    x"43f5fd", x"43f0cf", x"43ec20", x"43e82c", x"43e4e7",
    x"43e265", x"43e0ab", x"43dfad", x"43df7e", x"43dfee",
    x"43e12e", x"43e2d3", x"43e55a", x"43e7cb", x"43ec31",
    x"47edff", x"43f2ba", x"43f60b", x"43fa33", x"43fdf8",
    x"4001c6", x"40053b", x"400878", x"400b52", x"400dce",
    x"400fdc", x"401176", x"4012a2", x"40134c", x"401399",
    x"401357", x"4012dd", x"4011ba", x"4010b8", x"400e17",
    x"440dad", x"400ae5", x"40090f", x"400693", x"40044d",
    x"4001ed", x"43ffb9", x"43fd97", x"43fba8", x"43f9e7",
    x"43f860", x"43f719", x"43f60d", x"43f550", x"43f4c6",
    x"43f497", x"43f484", x"43f4e7", x"43f526", x"43f6a8",
    x"47f65f", x"43f7e0", x"43f8cc", x"43fa2a", x"43fb6e",
    x"43fccc", x"43fe18", x"43ff62", x"400096", x"4001b7",
    x"4002bd", x"4003a3", x"40046b", x"400509", x"40058e",
    x"4005dd", x"400620", x"400617", x"40062e", x"40055c",
    x"4405e4", x"40052b", x"4004c3", x"400416", x"400372",
    x"4002ba", x"400206", x"40014d", x"40009a", x"43ffec",
    x"43ff48", x"43feb1", x"43fe24", x"43fdab", x"43fd3c",
    x"43fce9", x"43fc97", x"43fc72", x"43fc33", x"43fc8e",
    x"47fbf8", x"43fc30", x"43fc42", x"43fc79", x"43fcae",
    x"43fcf0", x"43fd34", x"43fd7e", x"43fdc9", x"43fe15",
    x"43fe60", x"43fea9", x"43fef1", x"43ff33", x"43ff74",
    x"43ffaa", x"43ffe3", x"400008", x"40003f", x"40001d",
    x"440093", x"400095", x"4000a5", x"4000a7", x"4000aa",
    x"4000a7", x"4000a3", x"40009c", x"400093", x"400089",
    x"40007e", x"400072", x"400066", x"40005a", x"40004d",
    x"400043", x"600036", x"500030", x"40001f", x"400043");

  signal command : command_t := (others => '0');
  --type buff_t is array(0 to 1023) of signed18;
  type buff_t is array(0 to 2047) of signed18;
  signal buff : buff_t := (others => "00" & x"0000");

  signal pc : integer range 0 to order-1;

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
    --variable rp_increment : pointer_t;
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
