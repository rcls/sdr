-- Output FIR.
-- 4 channels, with input strobe.  [might become 8...]
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity lowfir is
  generic(acc_width : integer := 37;
          out_width : integer := 18);
  port(d : in signed18;
       --d_strobe : in std_logic;
       q : out signed(out_width - 1 downto 0);
       q_strobe : out std_logic; -- Asserted on the first cycle with new data.
       clk : in std_logic);
end lowfir;

architecture lowfir of lowfir is
  constant index_sample_strobe : integer := 18;
  constant index_out_strobe : integer := 19;
  constant index_pc_reset : integer := 20;
  constant index_read_reset : integer := 21;
  constant index_mac_accum : integer := 22;
  constant program_size : integer := 400;
  -- Min coeff is -28805
  -- Max coeff is 131071
  -- Sum of coeffs is 594566
  -- Number of coeffs is 400
  constant program : program_t(0 to program_size - 1) := (
    x"07fff8", x"4bfff3", x"43ffef", x"43fff3", x"400005",
    x"400026", x"400053", x"400084", x"4000aa", x"4000b9",
    x"4000a7", x"400075", x"40002f", x"43ffe9", x"43ffb8",
    x"43ffad", x"43ffc8", x"43fffd", x"400034", x"400054",
    x"40004e", x"400024", x"43ffe7", x"43ffb4", x"43ffa2",
    x"43ffbd", x"43fffa", x"40003d", x"400067", x"400062",
    x"40002d", x"43ffde", x"43ff9a", x"43ff83", x"43ffa7",
    x"43fff9", x"400055", x"40008d", x"400085", x"40003b",
    x"43ffcf", x"43ff73", x"43ff56", x"43ff8a", x"43fffb",
    x"400077", x"4000c2", x"4000b2", x"40004a", x"43ffb7",
    x"43ff3d", x"43ff1b", x"43ff66", x"400003", x"4000a8",
    x"400106", x"4000ea", x"400058", x"43ff92", x"43fef5",
    x"43fed1", x"43ff40", x"400014", x"4000eb", x"40015d",
    x"40012a", x"400061", x"43ff5d", x"43fe98", x"43fe79",
    x"43ff18", x"400033", x"400145", x"4001c8", x"400172",
    x"400061", x"43ff10", x"43fe22", x"43fe11", x"43fef3",
    x"400066", x"4001bc", x"40024a", x"4001c0", x"400051",
    x"43fea6", x"43fd8e", x"43fd9b", x"43fed6", x"4000b5",
    x"400254", x"4002e4", x"40020f", x"40002b", x"43fe18",
    x"43fcd9", x"43fd17", x"43fec7", x"400127", x"400316",
    x"400399", x"40025d", x"43ffe7", x"43fd5d", x"43fbfe",
    x"43fc87", x"43fecd", x"4001c7", x"400408", x"400469",
    x"4002a2", x"43ff79", x"43fc69", x"43faf8", x"43fbef",
    x"43fef3", x"4002a2", x"400534", x"400555", x"4002d7",
    x"43fed3", x"43fb31", x"43f9c0", x"43fb52", x"43ff47",
    x"4003c9", x"4006a6", x"400660", x"4002f1", x"43fde3",
    x"43f99f", x"43f84b", x"43fab4", x"43ffd9", x"400553",
    x"400873", x"40078f", x"4002e4", x"43fc8e", x"43f799",
    x"43f68a", x"43fa1a", x"4000c3", x"400766", x"400ab8",
    x"4008eb", x"40029b", x"43faab", x"43f4f0", x"43f45f",
    x"43f989", x"400231", x"400a3f", x"400dae", x"400a87",
    x"4001f8", x"43f7ee", x"43f14c", x"43f192", x"43f907",
    x"40046b", x"400e56", x"4011c1", x"400c8e", x"4000c1",
    x"43f3c4", x"43ebfb", x"43eda4", x"43f899", x"400814",
    x"4014b3", x"4017f1", x"400f6e", x"43fe74", x"43ecca",
    x"43e33b", x"43e74f", x"43f842", x"400ed1", x"402034",
    x"40231a", x"40146f", x"43f98f", x"43de96", x"43d132",
    x"43da16", x"43f805", x"401f0a", x"403cb1", x"403ffb",
    x"4021ce", x"43ea2d", x"43af81", x"438f7b", x"43a3f5",
    x"43f7e7", x"408100", x"4120d3", x"41ada7", x"41ffff",
    x"41ffff", x"41ada7", x"4120d3", x"408100", x"43f7e7",
    x"43a3f5", x"438f7b", x"43af81", x"43ea2d", x"4021ce",
    x"403ffb", x"403cb1", x"401f0a", x"43f805", x"43da16",
    x"43d132", x"43de96", x"43f98f", x"40146f", x"40231a",
    x"402034", x"400ed1", x"43f842", x"43e74f", x"43e33b",
    x"43ecca", x"43fe74", x"400f6e", x"4017f1", x"4014b3",
    x"400814", x"43f899", x"43eda4", x"43ebfb", x"43f3c4",
    x"4000c1", x"400c8e", x"4011c1", x"400e56", x"40046b",
    x"43f907", x"43f192", x"43f14c", x"43f7ee", x"4001f8",
    x"400a87", x"400dae", x"400a3f", x"400231", x"43f989",
    x"43f45f", x"43f4f0", x"43faab", x"40029b", x"4008eb",
    x"400ab8", x"400766", x"4000c3", x"43fa1a", x"43f68a",
    x"43f799", x"43fc8e", x"4002e4", x"40078f", x"400873",
    x"400553", x"43ffd9", x"43fab4", x"43f84b", x"43f99f",
    x"43fde3", x"4002f1", x"400660", x"4006a6", x"4003c9",
    x"43ff47", x"43fb52", x"43f9c0", x"43fb31", x"43fed3",
    x"4002d7", x"400555", x"400534", x"4002a2", x"43fef3",
    x"43fbef", x"43faf8", x"43fc69", x"43ff79", x"4002a2",
    x"400469", x"400408", x"4001c7", x"43fecd", x"43fc87",
    x"43fbfe", x"43fd5d", x"43ffe7", x"40025d", x"400399",
    x"400316", x"400127", x"43fec7", x"43fd17", x"43fcd9",
    x"43fe18", x"40002b", x"40020f", x"4002e4", x"400254",
    x"4000b5", x"43fed6", x"43fd9b", x"43fd8e", x"43fea6",
    x"400051", x"4001c0", x"40024a", x"4001bc", x"400066",
    x"43fef3", x"43fe11", x"43fe22", x"43ff10", x"400061",
    x"400172", x"4001c8", x"400145", x"400033", x"43ff18",
    x"43fe79", x"43fe98", x"43ff5d", x"400061", x"40012a",
    x"40015d", x"4000eb", x"400014", x"43ff40", x"43fed1",
    x"43fef5", x"43ff92", x"400058", x"4000ea", x"400106",
    x"4000a8", x"400003", x"43ff66", x"43ff1b", x"43ff3d",
    x"43ffb7", x"40004a", x"4000b2", x"4000c2", x"400077",
    x"43fffb", x"43ff8a", x"43ff56", x"43ff73", x"43ffcf",
    x"40003b", x"400085", x"40008d", x"400055", x"43fff9",
    x"43ffa7", x"43ff83", x"43ff9a", x"43ffde", x"40002d",
    x"400062", x"400067", x"40003d", x"43fffa", x"43ffbd",
    x"43ffa2", x"43ffb4", x"43ffe7", x"400024", x"40004e",
    x"400054", x"400034", x"43fffd", x"43ffc8", x"43ffad",
    x"43ffb8", x"43ffe9", x"40002f", x"400075", x"4000a7",
    x"4000b9", x"4000aa", x"400084", x"400053", x"400026",
    x"400005", x"43fff3", x"73ffef", x"43fff3", x"43fff8",
    others => x"000000");

begin

  fir : entity work.quadfir
    generic map (acc_width, out_width, false,
                 index_sample_strobe,
                 index_out_strobe,
                 index_pc_reset,
                 index_read_reset,
                 index_mac_accum,
                 program_size,
                 program)
    port map (d, q, q_strobe, clk);

end lowfir;
