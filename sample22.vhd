-- Filter given by a fifth order polynomial:
-- plot 10 * log ((sin(x*pi*39/48) * sin(x*pi*45/48) * sin(x*pi*53/48) * sin(x*pi*60/48) * sin(x*pi*64/48) * 48 * 48 * 48 * 48 * 48 / 39 / 45 / 53 / 60 / 64 / pi / pi / pi / pi / pi / x / x / x / x / x)**2) /log(10)

--  39,45,53,50,54

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.defs.all;

entity sample22 is
  port(adc_p : in unsigned7;
       adc_n : in unsigned7;
       adc_clk_p : out std_logic;
       adc_clk_n : out std_logic;
       adc_reclk_p : in std_logic;
       adc_reclk_n : in std_logic;

       adc_sen : out std_logic := '0';
       adc_sdata : out std_logic := '0';
       adc_sclk : out std_logic := '0';
       adc_reset : out std_logic := '1';

       usb_d : inout unsigned8;
       usb_c : inout unsigned8 := "ZZZZ11ZZ";

       led : out unsigned8;
       clkin125 : in std_logic;
       clkin125_en : out STD_LOGIC);
end sample22;

architecture Behavioral of sample22 is

  alias usb_nRXF : std_logic is usb_c(0);
  alias usb_nTXE : std_logic is usb_c(1);
  alias usb_nRD  : std_logic is usb_c(2);
  alias usb_nWR  : std_logic is usb_c(3);
  alias usb_SIWA : std_logic is usb_c(4);

  signal led_on : unsigned8 := x"00";

  signal adc_ddr : unsigned7;
  signal adc_data : unsigned14;

  signal clkin125_buf : std_logic;

  -- Generated clock for delivery to ADC.
  signal adc_clk : std_logic;
  signal adc_clk_neg : std_logic;
  signal adc_clk_u : std_logic;
  signal adc_clk_neg_u : std_logic;
  signal adc_clk_fb : std_logic;
  alias adc_clk_locked : std_logic is led_on(1);

  -- Received clk from ADC.
  signal adc_reclk_b_n : std_logic;
  signal adc_reclk : std_logic;

  -- Regenerated reclk.
  signal clk_main : std_logic;
  signal clk_main_neg : std_logic;
  signal clku_main : std_logic;
  signal clku_main_neg : std_logic;
  signal clk_main_fb : std_logic;
  alias clk_main_locked : std_logic is led_on(0);

  constant state_max : integer := 59;
  signal state : integer range 0 to state_max;

  signal phase_r : unsigned7 := "0000000";
  signal freq : unsigned7 := "0000000";
  signal offset : signed18 := "00" & x"2000";
  signal shift : unsigned(4 downto 0) := "00000";

  signal usb_d_out : unsigned8;
  signal usb_oe : boolean := false;
  signal usb_rd : boolean := false;
  signal usb_rd_process : boolean := false;

  attribute S : string;
  attribute S of led : signal is "yes";
  attribute S of usb_c : signal is "yes";

  signal div25 : unsigned(24 downto 0);

  -- Poly is 0x100802041
  signal lfsr : std_logic_vector(31 downto 0) := x"00000001";

  -- Select part of trig. rom.
  signal table_select : unsigned(2 downto 0);

  -- Arithmetic width minus one...
  constant width : integer := 47;

  -- Type that used for arithmetic in the filter chain.
  subtype word is signed(width downto 0);
  type word_array is array (natural range <>) of word;
  constant zero : word := (others => '0');

  signal cos : signed18;
  signal sin : signed18;
  signal cos_1 : signed18;
  signal sin_1 : signed18;

  signal adc_r0 : unsigned14;
  signal adc_i0 : unsigned14;
  signal adc_r1 : signed18;
  signal adc_i1 : signed18;

  signal prod_r : signed36;
  signal prod_i : signed36;

  signal acc1_r : word;
  signal acc1_i : word;
  signal acc2_r : word;
  signal acc2_i : word;
  signal acc3_r : word;
  signal acc3_i : word;
  signal acc4_r : word;
  signal acc4_i : word;
  signal acc5_r : word;
  signal acc5_i : word;

  signal flt_r : word_array(0 to 5);
  signal flt_i : word_array(0 to 5);

  signal out1_r : signed(17 downto 0);
  signal out1_i : signed(17 downto 0);
  signal out2_r : signed(11 downto 0);
  signal out2_i : signed(11 downto 0);

  signal out0 : signed(7 downto 0);
  signal out1 : signed(7 downto 0);
  signal out2 : signed(7 downto 0);

  subtype opcode_t is std_logic_vector(1 downto 0);
  constant op_pass : opcode_t := "00";
  constant op_add : opcode_t := "10";
  constant op_shift : opcode_t := "11";
  type opcodes_t is array (natural range <>) of opcode_t;
  signal op : opcodes_t(0 to 5);

  function shift_or_add(acc : word; prev : word; adc : word;
                        op : opcode_t; i : integer) return word is
    variable addend1 : word;
    variable addend2 : word;
    variable sum : word;
  begin
    if op(0) = '1' then
      addend1 := prev;
      addend2 := zero;
    else
      addend1 := acc;
      addend2 := adc;
    end if;
    if i mod 2 = 0 then
      sum := addend1 - addend2;
    else
      sum := addend1 + addend2;
    end if;
    return sum;
  end shift_or_add;

  type signed18_array is array (natural range <>) of signed18;
  signal cos_table : signed18_array(0 to 1023) := (
    -- Scale = 11585.2.
    "00" & x"2d41", "00" & x"2d31", "00" & x"2d02", "00" & x"2cb3",
    "00" & x"2c44", "00" & x"2bb6", "00" & x"2b0a", "00" & x"2a40",
    "00" & x"2958", "00" & x"2853", "00" & x"2731", "00" & x"25f4",
    "00" & x"249d", "00" & x"232b", "00" & x"21a2", "00" & x"0000",
    "00" & x"2000", "00" & x"1e48", "00" & x"1c7b", "00" & x"1a9a",
    "00" & x"18a6", "00" & x"16a1", "00" & x"148c", "00" & x"1268",
    "00" & x"1038", "00" & x"0dfc", "00" & x"0bb6", "00" & x"0969",
    "00" & x"0714", "00" & x"04bb", "00" & x"025e", "00" & x"0000",
    "00" & x"0000", "11" & x"fda2", "11" & x"fb45", "11" & x"f8ec",
    "11" & x"f697", "11" & x"f44a", "11" & x"f204", "11" & x"efc8",
    "11" & x"ed98", "11" & x"eb74", "11" & x"e95f", "11" & x"e75a",
    "11" & x"e566", "11" & x"e385", "11" & x"e1b8", "00" & x"0000",
    "11" & x"e000", "11" & x"de5e", "11" & x"dcd5", "11" & x"db63",
    "11" & x"da0c", "11" & x"d8cf", "11" & x"d7ad", "11" & x"d6a8",
    "11" & x"d5c0", "11" & x"d4f6", "11" & x"d44a", "11" & x"d3bc",
    "11" & x"d34d", "11" & x"d2fe", "11" & x"d2cf", "00" & x"0000",
    "11" & x"d2bf", "11" & x"d2cf", "11" & x"d2fe", "11" & x"d34d",
    "11" & x"d3bc", "11" & x"d44a", "11" & x"d4f6", "11" & x"d5c0",
    "11" & x"d6a8", "11" & x"d7ad", "11" & x"d8cf", "11" & x"da0c",
    "11" & x"db63", "11" & x"dcd5", "11" & x"de5e", "00" & x"0000",
    "11" & x"e000", "11" & x"e1b8", "11" & x"e385", "11" & x"e566",
    "11" & x"e75a", "11" & x"e95f", "11" & x"eb74", "11" & x"ed98",
    "11" & x"efc8", "11" & x"f204", "11" & x"f44a", "11" & x"f697",
    "11" & x"f8ec", "11" & x"fb45", "11" & x"fda2", "00" & x"0000",
    "00" & x"0000", "00" & x"025e", "00" & x"04bb", "00" & x"0714",
    "00" & x"0969", "00" & x"0bb6", "00" & x"0dfc", "00" & x"1038",
    "00" & x"1268", "00" & x"148c", "00" & x"16a1", "00" & x"18a6",
    "00" & x"1a9a", "00" & x"1c7b", "00" & x"1e48", "00" & x"0000",
    "00" & x"2000", "00" & x"21a2", "00" & x"232b", "00" & x"249d",
    "00" & x"25f4", "00" & x"2731", "00" & x"2853", "00" & x"2958",
    "00" & x"2a40", "00" & x"2b0a", "00" & x"2bb6", "00" & x"2c44",
    "00" & x"2cb3", "00" & x"2d02", "00" & x"2d31", "00" & x"0000",
    -- Scale = 16384.
    "00" & x"4000", "00" & x"3fea", "00" & x"3fa6", "00" & x"3f36",
    "00" & x"3e9a", "00" & x"3dd2", "00" & x"3cde", "00" & x"3bc0",
    "00" & x"3a78", "00" & x"3906", "00" & x"376d", "00" & x"35ad",
    "00" & x"33c7", "00" & x"31bd", "00" & x"2f90", "00" & x"0000",
    "00" & x"2d41", "00" & x"2ad3", "00" & x"2847", "00" & x"259e",
    "00" & x"22db", "00" & x"2000", "00" & x"1d0e", "00" & x"1a08",
    "00" & x"16f0", "00" & x"13c7", "00" & x"1090", "00" & x"0d4e",
    "00" & x"0a03", "00" & x"06b1", "00" & x"0359", "00" & x"0000",
    "00" & x"0000", "11" & x"fca7", "11" & x"f94f", "11" & x"f5fd",
    "11" & x"f2b2", "11" & x"ef70", "11" & x"ec39", "11" & x"e910",
    "11" & x"e5f8", "11" & x"e2f2", "11" & x"e000", "11" & x"dd25",
    "11" & x"da62", "11" & x"d7b9", "11" & x"d52d", "00" & x"0000",
    "11" & x"d2bf", "11" & x"d070", "11" & x"ce43", "11" & x"cc39",
    "11" & x"ca53", "11" & x"c893", "11" & x"c6fa", "11" & x"c588",
    "11" & x"c440", "11" & x"c322", "11" & x"c22e", "11" & x"c166",
    "11" & x"c0ca", "11" & x"c05a", "11" & x"c016", "00" & x"0000",
    "11" & x"c000", "11" & x"c016", "11" & x"c05a", "11" & x"c0ca",
    "11" & x"c166", "11" & x"c22e", "11" & x"c322", "11" & x"c440",
    "11" & x"c588", "11" & x"c6fa", "11" & x"c893", "11" & x"ca53",
    "11" & x"cc39", "11" & x"ce43", "11" & x"d070", "00" & x"0000",
    "11" & x"d2bf", "11" & x"d52d", "11" & x"d7b9", "11" & x"da62",
    "11" & x"dd25", "11" & x"e000", "11" & x"e2f2", "11" & x"e5f8",
    "11" & x"e910", "11" & x"ec39", "11" & x"ef70", "11" & x"f2b2",
    "11" & x"f5fd", "11" & x"f94f", "11" & x"fca7", "00" & x"0000",
    "00" & x"0000", "00" & x"0359", "00" & x"06b1", "00" & x"0a03",
    "00" & x"0d4e", "00" & x"1090", "00" & x"13c7", "00" & x"16f0",
    "00" & x"1a08", "00" & x"1d0e", "00" & x"2000", "00" & x"22db",
    "00" & x"259e", "00" & x"2847", "00" & x"2ad3", "00" & x"0000",
    "00" & x"2d41", "00" & x"2f90", "00" & x"31bd", "00" & x"33c7",
    "00" & x"35ad", "00" & x"376d", "00" & x"3906", "00" & x"3a78",
    "00" & x"3bc0", "00" & x"3cde", "00" & x"3dd2", "00" & x"3e9a",
    "00" & x"3f36", "00" & x"3fa6", "00" & x"3fea", "00" & x"0000",
    -- Scale = 23170.5.
    "00" & x"5a82", "00" & x"5a63", "00" & x"5a04", "00" & x"5965",
    "00" & x"5888", "00" & x"576d", "00" & x"5614", "00" & x"5480",
    "00" & x"52af", "00" & x"50a5", "00" & x"4e62", "00" & x"4be8",
    "00" & x"4939", "00" & x"4657", "00" & x"4343", "00" & x"0000",
    "00" & x"4000", "00" & x"3c90", "00" & x"38f6", "00" & x"3533",
    "00" & x"314c", "00" & x"2d41", "00" & x"2917", "00" & x"24d0",
    "00" & x"2070", "00" & x"1bf8", "00" & x"176d", "00" & x"12d1",
    "00" & x"0e29", "00" & x"0976", "00" & x"04bd", "00" & x"0000",
    "00" & x"0000", "11" & x"fb43", "11" & x"f68a", "11" & x"f1d7",
    "11" & x"ed2f", "11" & x"e893", "11" & x"e408", "11" & x"df90",
    "11" & x"db30", "11" & x"d6e9", "11" & x"d2bf", "11" & x"ceb4",
    "11" & x"cacd", "11" & x"c70a", "11" & x"c370", "00" & x"0000",
    "11" & x"c000", "11" & x"bcbd", "11" & x"b9a9", "11" & x"b6c7",
    "11" & x"b418", "11" & x"b19e", "11" & x"af5b", "11" & x"ad51",
    "11" & x"ab80", "11" & x"a9ec", "11" & x"a893", "11" & x"a778",
    "11" & x"a69b", "11" & x"a5fc", "11" & x"a59d", "00" & x"0000",
    "11" & x"a57e", "11" & x"a59d", "11" & x"a5fc", "11" & x"a69b",
    "11" & x"a778", "11" & x"a893", "11" & x"a9ec", "11" & x"ab80",
    "11" & x"ad51", "11" & x"af5b", "11" & x"b19e", "11" & x"b418",
    "11" & x"b6c7", "11" & x"b9a9", "11" & x"bcbd", "00" & x"0000",
    "11" & x"c000", "11" & x"c370", "11" & x"c70a", "11" & x"cacd",
    "11" & x"ceb4", "11" & x"d2bf", "11" & x"d6e9", "11" & x"db30",
    "11" & x"df90", "11" & x"e408", "11" & x"e893", "11" & x"ed2f",
    "11" & x"f1d7", "11" & x"f68a", "11" & x"fb43", "00" & x"0000",
    "00" & x"0000", "00" & x"04bd", "00" & x"0976", "00" & x"0e29",
    "00" & x"12d1", "00" & x"176d", "00" & x"1bf8", "00" & x"2070",
    "00" & x"24d0", "00" & x"2917", "00" & x"2d41", "00" & x"314c",
    "00" & x"3533", "00" & x"38f6", "00" & x"3c90", "00" & x"0000",
    "00" & x"4000", "00" & x"4343", "00" & x"4657", "00" & x"4939",
    "00" & x"4be8", "00" & x"4e62", "00" & x"50a5", "00" & x"52af",
    "00" & x"5480", "00" & x"5614", "00" & x"576d", "00" & x"5888",
    "00" & x"5965", "00" & x"5a04", "00" & x"5a63", "00" & x"0000",
    -- Scale = 32768.
    "00" & x"8000", "00" & x"7fd3", "00" & x"7f4c", "00" & x"7e6d",
    "00" & x"7d34", "00" & x"7ba3", "00" & x"79bc", "00" & x"7780",
    "00" & x"74ef", "00" & x"720d", "00" & x"6eda", "00" & x"6b5a",
    "00" & x"678e", "00" & x"637a", "00" & x"5f1f", "00" & x"0000",
    "00" & x"5a82", "00" & x"55a6", "00" & x"508e", "00" & x"4b3d",
    "00" & x"45b7", "00" & x"4000", "00" & x"3a1c", "00" & x"3410",
    "00" & x"2ddf", "00" & x"278e", "00" & x"2121", "00" & x"1a9d",
    "00" & x"1406", "00" & x"0d61", "00" & x"06b3", "00" & x"0000",
    "00" & x"0000", "11" & x"f94d", "11" & x"f29f", "11" & x"ebfa",
    "11" & x"e563", "11" & x"dedf", "11" & x"d872", "11" & x"d221",
    "11" & x"cbf0", "11" & x"c5e4", "11" & x"c000", "11" & x"ba49",
    "11" & x"b4c3", "11" & x"af72", "11" & x"aa5a", "00" & x"0000",
    "11" & x"a57e", "11" & x"a0e1", "11" & x"9c86", "11" & x"9872",
    "11" & x"94a6", "11" & x"9126", "11" & x"8df3", "11" & x"8b11",
    "11" & x"8880", "11" & x"8644", "11" & x"845d", "11" & x"82cc",
    "11" & x"8193", "11" & x"80b4", "11" & x"802d", "00" & x"0000",
    "11" & x"8000", "11" & x"802d", "11" & x"80b4", "11" & x"8193",
    "11" & x"82cc", "11" & x"845d", "11" & x"8644", "11" & x"8880",
    "11" & x"8b11", "11" & x"8df3", "11" & x"9126", "11" & x"94a6",
    "11" & x"9872", "11" & x"9c86", "11" & x"a0e1", "00" & x"0000",
    "11" & x"a57e", "11" & x"aa5a", "11" & x"af72", "11" & x"b4c3",
    "11" & x"ba49", "11" & x"c000", "11" & x"c5e4", "11" & x"cbf0",
    "11" & x"d221", "11" & x"d872", "11" & x"dedf", "11" & x"e563",
    "11" & x"ebfa", "11" & x"f29f", "11" & x"f94d", "00" & x"0000",
    "00" & x"0000", "00" & x"06b3", "00" & x"0d61", "00" & x"1406",
    "00" & x"1a9d", "00" & x"2121", "00" & x"278e", "00" & x"2ddf",
    "00" & x"3410", "00" & x"3a1c", "00" & x"4000", "00" & x"45b7",
    "00" & x"4b3d", "00" & x"508e", "00" & x"55a6", "00" & x"0000",
    "00" & x"5a82", "00" & x"5f1f", "00" & x"637a", "00" & x"678e",
    "00" & x"6b5a", "00" & x"6eda", "00" & x"720d", "00" & x"74ef",
    "00" & x"7780", "00" & x"79bc", "00" & x"7ba3", "00" & x"7d34",
    "00" & x"7e6d", "00" & x"7f4c", "00" & x"7fd3", "00" & x"0000",
    -- Scale = 46341.
    "00" & x"b505", "00" & x"b4c5", "00" & x"b407", "00" & x"b2ca",
    "00" & x"b110", "00" & x"aeda", "00" & x"ac29", "00" & x"a8ff",
    "00" & x"a55f", "00" & x"a14a", "00" & x"9cc4", "00" & x"97d1",
    "00" & x"9273", "00" & x"8cae", "00" & x"8686", "00" & x"0000",
    "00" & x"8000", "00" & x"7920", "00" & x"71eb", "00" & x"6a67",
    "00" & x"6297", "00" & x"5a82", "00" & x"522e", "00" & x"49a1",
    "00" & x"40df", "00" & x"37f0", "00" & x"2eda", "00" & x"25a3",
    "00" & x"1c51", "00" & x"12ec", "00" & x"0979", "00" & x"0000",
    "00" & x"0000", "11" & x"f687", "11" & x"ed14", "11" & x"e3af",
    "11" & x"da5d", "11" & x"d126", "11" & x"c810", "11" & x"bf21",
    "11" & x"b65f", "11" & x"add2", "11" & x"a57e", "11" & x"9d69",
    "11" & x"9599", "11" & x"8e15", "11" & x"86e0", "00" & x"0000",
    "11" & x"8000", "11" & x"797a", "11" & x"7352", "11" & x"6d8d",
    "11" & x"682f", "11" & x"633c", "11" & x"5eb6", "11" & x"5aa1",
    "11" & x"5701", "11" & x"53d7", "11" & x"5126", "11" & x"4ef0",
    "11" & x"4d36", "11" & x"4bf9", "11" & x"4b3b", "00" & x"0000",
    "11" & x"4afb", "11" & x"4b3b", "11" & x"4bf9", "11" & x"4d36",
    "11" & x"4ef0", "11" & x"5126", "11" & x"53d7", "11" & x"5701",
    "11" & x"5aa1", "11" & x"5eb6", "11" & x"633c", "11" & x"682f",
    "11" & x"6d8d", "11" & x"7352", "11" & x"797a", "00" & x"0000",
    "11" & x"8000", "11" & x"86e0", "11" & x"8e15", "11" & x"9599",
    "11" & x"9d69", "11" & x"a57e", "11" & x"add2", "11" & x"b65f",
    "11" & x"bf21", "11" & x"c810", "11" & x"d126", "11" & x"da5d",
    "11" & x"e3af", "11" & x"ed14", "11" & x"f687", "00" & x"0000",
    "00" & x"0000", "00" & x"0979", "00" & x"12ec", "00" & x"1c51",
    "00" & x"25a3", "00" & x"2eda", "00" & x"37f0", "00" & x"40df",
    "00" & x"49a1", "00" & x"522e", "00" & x"5a82", "00" & x"6297",
    "00" & x"6a67", "00" & x"71eb", "00" & x"7920", "00" & x"0000",
    "00" & x"8000", "00" & x"8686", "00" & x"8cae", "00" & x"9273",
    "00" & x"97d1", "00" & x"9cc4", "00" & x"a14a", "00" & x"a55f",
    "00" & x"a8ff", "00" & x"ac29", "00" & x"aeda", "00" & x"b110",
    "00" & x"b2ca", "00" & x"b407", "00" & x"b4c5", "00" & x"0000",
    -- Scale = 65536.
    "01" & x"0000", "00" & x"ffa6", "00" & x"fe99", "00" & x"fcd9",
    "00" & x"fa68", "00" & x"f747", "00" & x"f378", "00" & x"eeff",
    "00" & x"e9de", "00" & x"e419", "00" & x"ddb4", "00" & x"d6b3",
    "00" & x"cf1c", "00" & x"c6f3", "00" & x"be3f", "00" & x"0000",
    "00" & x"b505", "00" & x"ab4c", "00" & x"a11b", "00" & x"9679",
    "00" & x"8b6d", "00" & x"8000", "00" & x"7439", "00" & x"6820",
    "00" & x"5bbe", "00" & x"4f1c", "00" & x"4242", "00" & x"353a",
    "00" & x"280c", "00" & x"1ac2", "00" & x"0d66", "00" & x"0000",
    "00" & x"0000", "11" & x"f29a", "11" & x"e53e", "11" & x"d7f4",
    "11" & x"cac6", "11" & x"bdbe", "11" & x"b0e4", "11" & x"a442",
    "11" & x"97e0", "11" & x"8bc7", "11" & x"8000", "11" & x"7493",
    "11" & x"6987", "11" & x"5ee5", "11" & x"54b4", "00" & x"0000",
    "11" & x"4afb", "11" & x"41c1", "11" & x"390d", "11" & x"30e4",
    "11" & x"294d", "11" & x"224c", "11" & x"1be7", "11" & x"1622",
    "11" & x"1101", "11" & x"0c88", "11" & x"08b9", "11" & x"0598",
    "11" & x"0327", "11" & x"0167", "11" & x"005a", "00" & x"0000",
    "11" & x"0000", "11" & x"005a", "11" & x"0167", "11" & x"0327",
    "11" & x"0598", "11" & x"08b9", "11" & x"0c88", "11" & x"1101",
    "11" & x"1622", "11" & x"1be7", "11" & x"224c", "11" & x"294d",
    "11" & x"30e4", "11" & x"390d", "11" & x"41c1", "00" & x"0000",
    "11" & x"4afb", "11" & x"54b4", "11" & x"5ee5", "11" & x"6987",
    "11" & x"7493", "11" & x"8000", "11" & x"8bc7", "11" & x"97e0",
    "11" & x"a442", "11" & x"b0e4", "11" & x"bdbe", "11" & x"cac6",
    "11" & x"d7f4", "11" & x"e53e", "11" & x"f29a", "00" & x"0000",
    "00" & x"0000", "00" & x"0d66", "00" & x"1ac2", "00" & x"280c",
    "00" & x"353a", "00" & x"4242", "00" & x"4f1c", "00" & x"5bbe",
    "00" & x"6820", "00" & x"7439", "00" & x"8000", "00" & x"8b6d",
    "00" & x"9679", "00" & x"a11b", "00" & x"ab4c", "00" & x"0000",
    "00" & x"b505", "00" & x"be3f", "00" & x"c6f3", "00" & x"cf1c",
    "00" & x"d6b3", "00" & x"ddb4", "00" & x"e419", "00" & x"e9de",
    "00" & x"eeff", "00" & x"f378", "00" & x"f747", "00" & x"fa68",
    "00" & x"fcd9", "00" & x"fe99", "00" & x"ffa6", "00" & x"0000",
    -- Scale = 92681.9.
    "01" & x"6a0a", "01" & x"698b", "01" & x"680e", "01" & x"6595",
    "01" & x"6221", "01" & x"5db4", "01" & x"5852", "01" & x"51fe",
    "01" & x"4abd", "01" & x"4294", "01" & x"3989", "01" & x"2fa2",
    "01" & x"24e5", "01" & x"195b", "01" & x"0d0c", "00" & x"0000",
    "01" & x"0000", "00" & x"f240", "00" & x"e3d7", "00" & x"d4cd",
    "00" & x"c52e", "00" & x"b505", "00" & x"a45d", "00" & x"9341",
    "00" & x"81be", "00" & x"6fe0", "00" & x"5db4", "00" & x"4b46",
    "00" & x"38a3", "00" & x"25d8", "00" & x"12f3", "00" & x"0000",
    "00" & x"0000", "11" & x"ed0d", "11" & x"da28", "11" & x"c75d",
    "11" & x"b4ba", "11" & x"a24c", "11" & x"9020", "11" & x"7e42",
    "11" & x"6cbf", "11" & x"5ba3", "11" & x"4afb", "11" & x"3ad2",
    "11" & x"2b33", "11" & x"1c29", "11" & x"0dc0", "00" & x"0000",
    "11" & x"0000", "10" & x"f2f4", "10" & x"e6a5", "10" & x"db1b",
    "10" & x"d05e", "10" & x"c677", "10" & x"bd6c", "10" & x"b543",
    "10" & x"ae02", "10" & x"a7ae", "10" & x"a24c", "10" & x"9ddf",
    "10" & x"9a6b", "10" & x"97f2", "10" & x"9675", "00" & x"0000",
    "10" & x"95f6", "10" & x"9675", "10" & x"97f2", "10" & x"9a6b",
    "10" & x"9ddf", "10" & x"a24c", "10" & x"a7ae", "10" & x"ae02",
    "10" & x"b543", "10" & x"bd6c", "10" & x"c677", "10" & x"d05e",
    "10" & x"db1b", "10" & x"e6a5", "10" & x"f2f4", "00" & x"0000",
    "11" & x"0000", "11" & x"0dc0", "11" & x"1c29", "11" & x"2b33",
    "11" & x"3ad2", "11" & x"4afb", "11" & x"5ba3", "11" & x"6cbf",
    "11" & x"7e42", "11" & x"9020", "11" & x"a24c", "11" & x"b4ba",
    "11" & x"c75d", "11" & x"da28", "11" & x"ed0d", "00" & x"0000",
    "00" & x"0000", "00" & x"12f3", "00" & x"25d8", "00" & x"38a3",
    "00" & x"4b46", "00" & x"5db4", "00" & x"6fe0", "00" & x"81be",
    "00" & x"9341", "00" & x"a45d", "00" & x"b505", "00" & x"c52e",
    "00" & x"d4cd", "00" & x"e3d7", "00" & x"f240", "00" & x"0000",
    "01" & x"0000", "01" & x"0d0c", "01" & x"195b", "01" & x"24e5",
    "01" & x"2fa2", "01" & x"3989", "01" & x"4294", "01" & x"4abd",
    "01" & x"51fe", "01" & x"5852", "01" & x"5db4", "01" & x"6221",
    "01" & x"6595", "01" & x"680e", "01" & x"698b", "00" & x"0000",
    -- Scale = 131071.
    "01" & x"ffff", "01" & x"ff4b", "01" & x"fd31", "01" & x"f9b1",
    "01" & x"f4cf", "01" & x"ee8d", "01" & x"e6f0", "01" & x"ddfd",
    "01" & x"d3bb", "01" & x"c831", "01" & x"bb67", "01" & x"ad65",
    "01" & x"9e37", "01" & x"8de5", "01" & x"7c7d", "00" & x"0000",
    "01" & x"6a09", "01" & x"5698", "01" & x"4236", "01" & x"2cf2",
    "01" & x"16da", "01" & x"0000", "00" & x"e871", "00" & x"d03f",
    "00" & x"b77c", "00" & x"9e37", "00" & x"8484", "00" & x"6a73",
    "00" & x"5018", "00" & x"3585", "00" & x"1acc", "00" & x"0000",
    "00" & x"0000", "11" & x"e534", "11" & x"ca7b", "11" & x"afe8",
    "11" & x"958d", "11" & x"7b7c", "11" & x"61c9", "11" & x"4884",
    "11" & x"2fc1", "11" & x"178f", "11" & x"0001", "10" & x"e926",
    "10" & x"d30e", "10" & x"bdca", "10" & x"a968", "00" & x"0000",
    "10" & x"95f7", "10" & x"8383", "10" & x"721b", "10" & x"61c9",
    "10" & x"529b", "10" & x"4499", "10" & x"37cf", "10" & x"2c45",
    "10" & x"2203", "10" & x"1910", "10" & x"1173", "10" & x"0b31",
    "10" & x"064f", "10" & x"02cf", "10" & x"00b5", "00" & x"0000",
    "10" & x"0001", "10" & x"00b5", "10" & x"02cf", "10" & x"064f",
    "10" & x"0b31", "10" & x"1173", "10" & x"1910", "10" & x"2203",
    "10" & x"2c45", "10" & x"37cf", "10" & x"4499", "10" & x"529b",
    "10" & x"61c9", "10" & x"721b", "10" & x"8383", "00" & x"0000",
    "10" & x"95f7", "10" & x"a968", "10" & x"bdca", "10" & x"d30e",
    "10" & x"e926", "11" & x"0000", "11" & x"178f", "11" & x"2fc1",
    "11" & x"4884", "11" & x"61c9", "11" & x"7b7c", "11" & x"958d",
    "11" & x"afe8", "11" & x"ca7b", "11" & x"e534", "00" & x"0000",
    "00" & x"0000", "00" & x"1acc", "00" & x"3585", "00" & x"5018",
    "00" & x"6a73", "00" & x"8484", "00" & x"9e37", "00" & x"b77c",
    "00" & x"d03f", "00" & x"e871", "00" & x"ffff", "01" & x"16da",
    "01" & x"2cf2", "01" & x"4236", "01" & x"5698", "00" & x"0000",
    "01" & x"6a09", "01" & x"7c7d", "01" & x"8de5", "01" & x"9e37",
    "01" & x"ad65", "01" & x"bb67", "01" & x"c831", "01" & x"d3bb",
    "01" & x"ddfd", "01" & x"e6f0", "01" & x"ee8d", "01" & x"f4cf",
    "01" & x"f9b1", "01" & x"fd31", "01" & x"ff4b", "00" & x"0000"
    );

begin
  -- The adc DDR decode.
  adc_input: for i in 0 to 6 generate
    adc_in_ibuf: ibufds generic map (diff_term => true)
      port map (I => adc_n(i), IB => adc_p(i), O => adc_ddr(i));
    adc_ddr_expand: IDDR2
      generic map (ddr_alignment => "C0")
      port map (C0 => clk_main,
                C1 => clk_main_neg,
                CE => '1',
                D => adc_ddr(i),
                Q0 => adc_data(i*2+1),
                Q1 => adc_data(i*2));
  end generate;

  usb_nRXF <= 'Z';
  usb_nTXE <= 'Z';
  usb_SIWA <= '0';
  --usb_nRD <= usb_read;

  usb_c(7 downto 5) <= "ZZZ";
  clkin125_en <= '1';

  usb_d <= usb_d_out when usb_oe else "ZZZZZZZZ";

  led_control: for i in 0 to 7 generate
    led(i) <= '0' when led_on(i) = '1' else 'Z';
  end generate;
  led_on(2) <= div25(24);

  process (clk_main)
    variable div25_inc : unsigned(25 downto 0);
    variable phase_added : unsigned7;
  begin
    if clk_main'event and clk_main = '1' then
      div25_inc := ('0' & div25) + 1;
      div25 <= div25_inc(24 downto 0);

      if state = state_max then
        state <= 0;
      else
        state <= state + 1;
      end if;

      if usb_rd_process then
        phase_r <= (others => '0');
      else
        phase_r <= addmod120(phase_r, freq);
      end if;

      cos <= cos_table(to_integer(table_select & phase_r));
      sin <= cos_table(to_integer(table_select & (phase_r + "1100000")));

      adc_r0 <= adc_data;
      adc_i0 <= adc_data;
      adc_r1 <= (x"0" & signed(adc_r0)) - offset;
      adc_i1 <= (x"0" & signed(adc_i0)) - offset;
      cos_1 <= cos;
      sin_1 <= sin;

      prod_r <= adc_r1 * cos_1;
      prod_i <= adc_i1 * sin_1;

      acc1_r <= acc1_r + prod_r;
      acc1_i <= acc1_i + prod_i;
      acc2_r <= acc2_r + acc1_r(47 downto 47 - width);
      acc2_i <= acc2_i + acc1_i(47 downto 47 - width);
      acc3_r <= acc3_r + acc2_r;
      acc3_i <= acc3_i + acc2_i;
      acc4_r <= acc4_r + acc3_r;
      acc4_i <= acc4_i + acc3_i;
      acc5_r <= acc5_r + acc4_r;
      acc5_i <= acc5_i + acc4_i;

      for i in 0 to 5 loop
        op(i) <= op_pass;
      end loop;
      case state is
        when  0 => op(2) <= op_add; -- 120 = 2 *60 +  0 = 15 +49 +56
        when  4 => op(1) <= op_add; --  64 = 1 *60 +  4 = 15 +49
        when  5 => op(3) <= op_add; -- 185 = 3 *60 +  5 = 15 +49 +56 +65
        when  9 => op(2) <= op_add; -- 129 = 2 *60 +  9 = 15 +49 +65
        when 11 => op(1) <= op_add; --  71 = 1 *60 + 11 = 15 +56
        when 14 => op(3) <= op_add; -- 194 = 3 *60 + 14 = 15 +49 +56 +74
        when 15 => op(0) <= op_add; --  15 = 0 *60 + 15 = 15
        when 16 => op(2) <= op_add; -- 136 = 2 *60 + 16 = 15 +56 +65
        when 18 => op(2) <= op_add; -- 138 = 2 *60 + 18 = 15 +49 +74
        when 19 => op(3) <= op_add; -- 199 = 3 *60 + 19 = 15 +49 +56 +79
                   op(4) <= op_add; -- 259 = 4 *60 + 19 = 15 +49 +56 +65 +74
        when 20 => op(1) <= op_add; --  80 = 1 *60 + 20 = 15 +65
        when 23 => op(2) <= op_add; -- 143 = 2 *60 + 23 = 15 +49 +79
                   op(3) <= op_add; -- 203 = 3 *60 + 23 = 15 +49 +65 +74
        when 24 => op(4) <= op_add; -- 264 = 4 *60 + 24 = 15 +49 +56 +65 +79
        when 25 => op(2) <= op_add; -- 145 = 2 *60 + 25 = 15 +56 +74
        when 28 => op(3) <= op_add; -- 208 = 3 *60 + 28 = 15 +49 +65 +79
        when 29 => op(1) <= op_add; --  89 = 1 *60 + 29 = 15 +74
        when 30 => op(2) <= op_add; -- 150 = 2 *60 + 30 = 15 +56 +79
                   op(3) <= op_add; -- 210 = 3 *60 + 30 = 15 +56 +65 +74
        when 33 => op(4) <= op_add; -- 273 = 4 *60 + 33 = 15 +49 +56 +74 +79
        when 34 => op(1) <= op_add; --  94 = 1 *60 + 34 = 15 +79
                   op(2) <= op_add; -- 154 = 2 *60 + 34 = 15 +65 +74
        when 35 => op(3) <= op_add; -- 215 = 3 *60 + 35 = 15 +56 +65 +79
        when 37 => op(3) <= op_add; -- 217 = 3 *60 + 37 = 15 +49 +74 +79
        when 38 => op(5) <= op_add; -- 338 = 5 *60 + 38 = 15 +49 +56 +65 +74 +79
        when 39 => op(2) <= op_add; -- 159 = 2 *60 + 39 = 15 +65 +79
        when 42 => op(4) <= op_add; -- 282 = 4 *60 + 42 = 15 +49 +65 +74 +79
        when 44 => op(3) <= op_add; -- 224 = 3 *60 + 44 = 15 +56 +74 +79
        when 48 => op(2) <= op_add; -- 168 = 2 *60 + 48 = 15 +74 +79
        when 49 => op(4) <= op_add; -- 289 = 4 *60 + 49 = 15 +56 +65 +74 +79
        when 53 => op(3) <= op_add; -- 233 = 3 *60 + 53 = 15 +65 +74 +79
        when 54 =>
          for i in 0 to 5 loop
            op(i) <= op_shift;
          end loop;
        when others =>
      end case;

      if op(0)(1) = '1' then
        flt_r(0) <= shift_or_add(flt_r(0), zero, acc5_r, op(0), 0);
        flt_i(0) <= shift_or_add(flt_i(0), zero, acc5_i, op(0), 0);
      end if;
      for i in 1 to 5 loop
        if op(i)(1) = '1' then
          flt_r(i) <= shift_or_add(flt_r(i), flt_r(i-1), acc5_r, op(i), i);
          flt_i(i) <= shift_or_add(flt_i(i), flt_i(i-1), acc5_i, op(i), i);
        end if;
      end loop;

      case shift(4 downto 3) is
        when "01" => out1_r <= flt_r(5)(width- 8 downto width-25);
                     out1_i <= flt_i(5)(width- 8 downto width-25);
        when "10" => out1_r <= flt_r(5)(width-16 downto width-33);
                     out1_i <= flt_i(5)(width-16 downto width-33);
        when "11" => out1_r <= flt_r(5)(width-24 downto width-41);
                     out1_i <= flt_i(5)(width-24 downto width-41);
        when others => out1_r <= flt_r(5)(width downto width-17);
                       out1_i <= flt_i(5)(width downto width-17);
      end case;
      case shift(2 downto 1) is
        when "01" => out2_r <= out1_r(15 downto 4);
                     out2_i <= out1_i(15 downto 4);
        when "10" => out2_r <= out1_r(13 downto 2);
                     out2_i <= out1_i(13 downto 2);
        when "11" => out2_r <= out1_r(11 downto 0);
                     out2_i <= out1_i(11 downto 0);
        when others => out2_r <= out1_r(17 downto 6);
                       out2_i <= out1_i(17 downto 6);
      end case;
      if state = 47 then
        if shift(0) = '0' then
          out0 <= out2_r(11 downto 5) & (lfsr(0) and out2_i(1));
          out1 <= out2_i(11 downto 5) & (lfsr(0) or out2_i(1));
          out2 <= out2_r(4 downto 1) & out2_i(4 downto 2) & lfsr(0);
        else
          out0 <= out2_r(10 downto 4) & (lfsr(0) and out2_i(0));
          out1 <= out2_i(10 downto 4) & (lfsr(0) or out2_i(0));
          out2 <= out2_r(3 downto 0) & out2_i(3 downto 1) & lfsr(0);
        end if;
        lfsr <= lfsr(30 downto 0) & (
          lfsr(31) xor lfsr(22) xor lfsr(12) xor lfsr(5));
      end if;

      case state / 16 is
        when 0 => usb_d_out <= unsigned(out0);
        when 1 => usb_d_out <= unsigned(out1);
        when others => usb_d_out <= unsigned(out2);
      end case;

      usb_oe <= false;
      usb_nWR <= '1';
      case state / 2 is
        when 0|10|20 =>
          usb_oe <= true;
        when 1|11|21 =>
          usb_nWR <= '0';
          usb_oe <= true;
        when 2|3|4 | 12|13|14 | 22|23|24 =>
          usb_nWR <= '0';
        when others =>
      end case;

      -- Sample nRXF on 56/57/58/59, reset on 28/29/30/31
      if state / 4 = 14 then
        usb_rd <= usb_nRXF = '0';
      elsif state / 4 = 7 then
        usb_rd <= false;
      end if;

      usb_nRD <= '1';
      usb_rd_process <= false;
      if usb_rd then
        case state mod 32 is
          when 6|7|8|9|10|11|12 =>
            usb_nRD <= '0';
          when 13 =>
            usb_nRD <= '0';
            usb_rd_process <= true;
          when others =>
        end case;
      end if;

      if usb_rd_process then
        case usb_d(7 downto 5) is
          when "000" =>
            adc_sen <= usb_d(0);
            adc_sdata <= usb_d(1);
            adc_sclk <= usb_d(2);
            adc_reset <= usb_d(3);
          when "001" =>
            freq(4 downto 0) <= usb_d(4 downto 0);
          when "010" =>
            freq(6 downto 5) <= usb_d(1 downto 0);
            table_select <= usb_d(4 downto 2);
          when "011" =>
            shift <= usb_d(4 downto 0);
          when "100" =>
            offset(4 downto 0) <= signed(usb_d(4 downto 0));
          when "101" =>
            offset(9 downto 5) <= signed(usb_d(4 downto 0));
          when "110" =>
            offset(14 downto 10) <= signed(usb_d(4 downto 0));
          when "111" =>
            offset(17 downto 15) <= signed(usb_d(2 downto 0));
          when others =>
        end case;
      end if;

    end if;
  end process;

  -- Clk input from ADC.  The ADC drives the data as even on P-falling followed
  -- by odd on P-rising.
  adc_reclk_in: IBUFGDS
    generic map (diff_term => true)
    port map(I => adc_reclk_n, IB => adc_reclk_p,
             O => adc_reclk_b_n);
  -- Are these needed?  Do we need to tie them together?
  adc_reclk_buf: BUFIO2 port map(
    I => adc_reclk_b_n,
    DIVCLK => adc_reclk, IOCLK => open, SERDESSTROBE => open);
  adc_reclkfb: BUFIO2FB port map(I => clk_main_neg, O => clk_main_fb);

  -- Pseudo differential drive of clock to ADC.
  adc_clk_ddr_p: ODDR2 port map(
    D0 => '1', D1 => '0', C0 => adc_clk, C1 => adc_clk_neg,
    CE => '1', Q => adc_clk_p);
  adc_clk_ddr_n: ODDR2 port map(
    D0 => '0', D1 => '1', C0 => adc_clk, C1 => adc_clk_neg,
    CE => '1', Q => adc_clk_n);

  -- Regenerate the clock from the ADC.
  -- We run the PLL oscillator at 1000MHz, i.e., 4 times the input clock.
  main_pll : PLL_BASE
    generic map(
      --BANDWIDTH            => "LOW",
      CLK_FEEDBACK         => "CLKOUT0",
      --COMPENSATION         => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 1,
      --CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 4,
      --CLKOUT0_PHASE        => 0.000,
      --CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT1_DIVIDE       => 4,
      CLKOUT1_PHASE        => 180.000
      --CLKOUT1_DUTY_CYCLE   => 0.500,
      --CLKIN_PERIOD         => 10.0,
      --REF_JITTER           => 0.001
      )
    port map(
      -- Output clocks
      CLKFBOUT => open,
      CLKOUT0  => clku_main_neg,
      CLKOUT1  => clku_main,
      CLKOUT2  => open, CLKOUT3  => open, CLKOUT4  => open,
      CLKOUT5  => open, LOCKED   => clk_main_locked,
      RST      => '0',
      CLKFBIN  => clk_main_fb,
      CLKIN    => adc_reclk);

  clk_main_bufg     : BUFG port map(I => clku_main,     O => clk_main);
  clk_main_neg_bufg : BUFG port map(I => clku_main_neg, O => clk_main_neg);

  clkin125_bufg : BUFG port map(I=>clkin125, O=>clkin125_buf);

  -- Generate the clock to the ADC.  We run the PLL oscillator at 1000MHz, (8
  -- times the input clock), and then generate a 250MHz output.
  adc_gen_pll : PLL_BASE
    generic map(
      BANDWIDTH            => "LOW",
      CLK_FEEDBACK         => "CLKFBOUT",
      --COMPENSATION         => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 8,
      --CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 4,
      --CLKOUT0_PHASE        => 0.000,
      --CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT1_DIVIDE       => 4,
      CLKOUT1_PHASE        => 180.000
      --CLKOUT1_DUTY_CYCLE   => 0.500,
      --CLKIN_PERIOD         => 8.0,
      --REF_JITTER           => 0.001
      )
    port map(
      -- Output clocks
      CLKFBOUT            => adc_clk_fb,
      CLKOUT0             => adc_clk_u,
      CLKOUT1             => adc_clk_neg_u,
      CLKOUT2             => open,
      CLKOUT3             => open,
      CLKOUT4             => open,
      CLKOUT5             => open,
      LOCKED              => adc_clk_locked,
      RST                 => '0',
      -- Input clock control
      CLKFBIN             => adc_clk_fb,
      CLKIN               => clkin125_buf);
  adc_clk_bufg     : BUFG port map (I => adc_clk_u,     O => adc_clk);
  adc_clk_neg_bufg : BUFG port map (I => adc_clk_neg_u, O => adc_clk_neg);

end Behavioral;
