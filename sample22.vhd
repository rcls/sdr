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
       clkin125_en : out std_logic);
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

  signal phase : unsigned8 := x"00";
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

  -- Accumulator width minus one...
  constant width : integer := 62;

  -- Type that used for arithmetic in the filter chain.
  subtype word is signed(width downto 0);
  type signed32_array is array (natural range <>) of signed32;
  constant zero : signed32 := (others => '0');

  signal cos : signed18;
  signal sin : signed18;
  signal cos_1 : signed18;
  signal sin_1 : signed18;

  signal cos_neg : boolean;
  signal sin_neg : boolean;
  signal cos_neg_1 : boolean;
  signal sin_neg_1 : boolean;
  signal cos_neg_2 : boolean;
  signal sin_neg_2 : boolean;
  signal cos_neg_3 : boolean;
  signal sin_neg_3 : boolean;

  signal adc_r0 : unsigned14;
  signal adc_i0 : unsigned14;
  signal adc_r1 : signed18;
  signal adc_i1 : signed18;

  signal prod_r : signed36;
  signal prod_i : signed36;
  signal prod1_r : signed36;
  signal prod1_i : signed36;

  -- The multiplier can absorb two levels of registers; but we want to keep
  -- the second level in fabric to be as close as possible to the big adders.
  attribute keep : string;
  attribute keep of prod_r : signal is "true";
  attribute keep of prod_i : signal is "true";

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

  signal shift1_r : signed(38 downto 0);
  signal shift1_i : signed(38 downto 0);
  signal shift2_r : signed(32 downto 0);
  signal shift2_i : signed(32 downto 0);
  signal shift_r : signed32;
  signal shift_i : signed32;

  signal flt_r : signed32_array(0 to 5);
  signal flt_i : signed32_array(0 to 5);

  signal out0 : signed(7 downto 0);
  signal out1 : signed(7 downto 0);
  signal out2 : signed(7 downto 0);

  subtype opcode_t is std_logic_vector(1 downto 0);
  constant op_pass : opcode_t := "00";
  constant op_add : opcode_t := "10";
  constant op_shift : opcode_t := "11";
  type opcodes_t is array (natural range <>) of opcode_t;
  signal op : opcodes_t(0 to 5);

  function shift_or_add(acc : signed32; prev : signed32; adc : signed32;
                        op : opcode_t; i : integer) return signed32 is
    variable addend1 : signed32;
    variable addend2 : signed32;
    variable sum : signed32;
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

  -- The cos table is 8 tables of 120 entries.  We store half a cycle, negated.
  -- This means that +1 never occurs and we can use the full negative range.
  type signed18_array is array (natural range <>) of signed18;
  signal cos_table : signed18_array(0 to 1023) := (
    -- Scale = 38967.9.
    "11" & x"67c8", "11" & x"67d5", "11" & x"67fd", "11" & x"6840",
    "11" & x"689e", "11" & x"6915", "11" & x"69a8", "11" & x"6a55",
    "11" & x"6b1c", "11" & x"6bfd", "11" & x"6cf8", "11" & x"6e0d",
    "11" & x"6f3b", "11" & x"7083", "11" & x"71e4", "00" & x"0000",
    "11" & x"735e", "11" & x"74f1", "11" & x"769c", "11" & x"785f",
    "11" & x"7a3a", "11" & x"7c2d", "11" & x"7e36", "11" & x"8057",
    "11" & x"828e", "11" & x"84da", "11" & x"873d", "11" & x"89b4",
    "11" & x"8c41", "11" & x"8ee1", "11" & x"9196", "00" & x"0000",
    "11" & x"945e", "11" & x"9738", "11" & x"9a25", "11" & x"9d24",
    "11" & x"a035", "11" & x"a356", "11" & x"a687", "11" & x"a9c8",
    "11" & x"ad19", "11" & x"b077", "11" & x"b3e4", "11" & x"b75e",
    "11" & x"bae5", "11" & x"be78", "11" & x"c216", "00" & x"0000",
    "11" & x"c5c0", "11" & x"c973", "11" & x"cd30", "11" & x"d0f6",
    "11" & x"d4c5", "11" & x"d89a", "11" & x"dc77", "11" & x"e05a",
    "11" & x"e443", "11" & x"e830", "11" & x"ec22", "11" & x"f017",
    "11" & x"f40f", "11" & x"f809", "11" & x"fc04", "00" & x"0000",
    "00" & x"0000", "00" & x"03fc", "00" & x"07f7", "00" & x"0bf1",
    "00" & x"0fe9", "00" & x"13de", "00" & x"17d0", "00" & x"1bbd",
    "00" & x"1fa6", "00" & x"2389", "00" & x"2766", "00" & x"2b3b",
    "00" & x"2f0a", "00" & x"32d0", "00" & x"368d", "00" & x"0000",
    "00" & x"3a40", "00" & x"3dea", "00" & x"4188", "00" & x"451b",
    "00" & x"48a2", "00" & x"4c1c", "00" & x"4f89", "00" & x"52e7",
    "00" & x"5638", "00" & x"5979", "00" & x"5caa", "00" & x"5fcb",
    "00" & x"62dc", "00" & x"65db", "00" & x"68c8", "00" & x"0000",
    "00" & x"6ba2", "00" & x"6e6a", "00" & x"711f", "00" & x"73bf",
    "00" & x"764c", "00" & x"78c3", "00" & x"7b26", "00" & x"7d72",
    "00" & x"7fa9", "00" & x"81ca", "00" & x"83d3", "00" & x"85c6",
    "00" & x"87a1", "00" & x"8964", "00" & x"8b0f", "00" & x"0000",
    "00" & x"8ca2", "00" & x"8e1c", "00" & x"8f7d", "00" & x"90c5",
    "00" & x"91f3", "00" & x"9308", "00" & x"9403", "00" & x"94e4",
    "00" & x"95ab", "00" & x"9658", "00" & x"96eb", "00" & x"9762",
    "00" & x"97c0", "00" & x"9803", "00" & x"982b", "00" & x"0000",
    -- Scale = 46341.
    "11" & x"4afb", "11" & x"4b0b", "11" & x"4b3b", "11" & x"4b8a",
    "11" & x"4bf9", "11" & x"4c88", "11" & x"4d36", "11" & x"4e03",
    "11" & x"4ef0", "11" & x"4ffb", "11" & x"5126", "11" & x"526f",
    "11" & x"53d7", "11" & x"555d", "11" & x"5701", "00" & x"0000",
    "11" & x"58c3", "11" & x"5aa1", "11" & x"5c9d", "11" & x"5eb6",
    "11" & x"60eb", "11" & x"633c", "11" & x"65a8", "11" & x"682f",
    "11" & x"6ad1", "11" & x"6d8d", "11" & x"7063", "11" & x"7352",
    "11" & x"765a", "11" & x"797a", "11" & x"7cb1", "00" & x"0000",
    "11" & x"8000", "11" & x"8365", "11" & x"86e0", "11" & x"8a70",
    "11" & x"8e15", "11" & x"91cd", "11" & x"9599", "11" & x"9978",
    "11" & x"9d69", "11" & x"a16b", "11" & x"a57e", "11" & x"a9a0",
    "11" & x"add2", "11" & x"b212", "11" & x"b65f", "00" & x"0000",
    "11" & x"baba", "11" & x"bf21", "11" & x"c393", "11" & x"c810",
    "11" & x"cc96", "11" & x"d126", "11" & x"d5be", "11" & x"da5d",
    "11" & x"df03", "11" & x"e3af", "11" & x"e85f", "11" & x"ed14",
    "11" & x"f1cc", "11" & x"f687", "11" & x"fb43", "00" & x"0000",
    "00" & x"0000", "00" & x"04bd", "00" & x"0979", "00" & x"0e34",
    "00" & x"12ec", "00" & x"17a1", "00" & x"1c51", "00" & x"20fd",
    "00" & x"25a3", "00" & x"2a42", "00" & x"2eda", "00" & x"336a",
    "00" & x"37f0", "00" & x"3c6d", "00" & x"40df", "00" & x"0000",
    "00" & x"4546", "00" & x"49a1", "00" & x"4dee", "00" & x"522e",
    "00" & x"5660", "00" & x"5a82", "00" & x"5e95", "00" & x"6297",
    "00" & x"6688", "00" & x"6a67", "00" & x"6e33", "00" & x"71eb",
    "00" & x"7590", "00" & x"7920", "00" & x"7c9b", "00" & x"0000",
    "00" & x"8000", "00" & x"834f", "00" & x"8686", "00" & x"89a6",
    "00" & x"8cae", "00" & x"8f9d", "00" & x"9273", "00" & x"952f",
    "00" & x"97d1", "00" & x"9a58", "00" & x"9cc4", "00" & x"9f15",
    "00" & x"a14a", "00" & x"a363", "00" & x"a55f", "00" & x"0000",
    "00" & x"a73d", "00" & x"a8ff", "00" & x"aaa3", "00" & x"ac29",
    "00" & x"ad91", "00" & x"aeda", "00" & x"b005", "00" & x"b110",
    "00" & x"b1fd", "00" & x"b2ca", "00" & x"b378", "00" & x"b407",
    "00" & x"b476", "00" & x"b4c5", "00" & x"b4f5", "00" & x"0000",
    -- Scale = 55109.
    "11" & x"28bb", "11" & x"28ce", "11" & x"2907", "11" & x"2965",
    "11" & x"29e9", "11" & x"2a92", "11" & x"2b61", "11" & x"2c56",
    "11" & x"2d6f", "11" & x"2eae", "11" & x"3011", "11" & x"3198",
    "11" & x"3344", "11" & x"3514", "11" & x"3707", "00" & x"0000",
    "11" & x"391e", "11" & x"3b57", "11" & x"3db3", "11" & x"4032",
    "11" & x"42d1", "11" & x"4592", "11" & x"4874", "11" & x"4b76",
    "11" & x"4e97", "11" & x"51d8", "11" & x"5537", "11" & x"58b4",
    "11" & x"5c4f", "11" & x"6006", "11" & x"63d9", "00" & x"0000",
    "11" & x"67c8", "11" & x"6bd1", "11" & x"6ff5", "11" & x"7432",
    "11" & x"7887", "11" & x"7cf4", "11" & x"8178", "11" & x"8612",
    "11" & x"8ac1", "11" & x"8f86", "11" & x"945e", "11" & x"9948",
    "11" & x"9e45", "11" & x"a353", "11" & x"a871", "00" & x"0000",
    "11" & x"ad9f", "11" & x"b2db", "11" & x"b824", "11" & x"bd7a",
    "11" & x"c2dc", "11" & x"c849", "11" & x"cdbf", "11" & x"d33e",
    "11" & x"d8c5", "11" & x"de53", "11" & x"e3e7", "11" & x"e980",
    "11" & x"ef1c", "11" & x"f4bc", "11" & x"fa5d", "00" & x"0000",
    "00" & x"0000", "00" & x"05a3", "00" & x"0b44", "00" & x"10e4",
    "00" & x"1680", "00" & x"1c19", "00" & x"21ad", "00" & x"273b",
    "00" & x"2cc2", "00" & x"3241", "00" & x"37b7", "00" & x"3d24",
    "00" & x"4286", "00" & x"47dc", "00" & x"4d25", "00" & x"0000",
    "00" & x"5261", "00" & x"578f", "00" & x"5cad", "00" & x"61bb",
    "00" & x"66b8", "00" & x"6ba2", "00" & x"707a", "00" & x"753f",
    "00" & x"79ee", "00" & x"7e88", "00" & x"830c", "00" & x"8779",
    "00" & x"8bce", "00" & x"900b", "00" & x"942f", "00" & x"0000",
    "00" & x"9838", "00" & x"9c27", "00" & x"9ffa", "00" & x"a3b1",
    "00" & x"a74c", "00" & x"aac9", "00" & x"ae28", "00" & x"b169",
    "00" & x"b48a", "00" & x"b78c", "00" & x"ba6e", "00" & x"bd2f",
    "00" & x"bfce", "00" & x"c24d", "00" & x"c4a9", "00" & x"0000",
    "00" & x"c6e2", "00" & x"c8f9", "00" & x"caec", "00" & x"ccbc",
    "00" & x"ce68", "00" & x"cfef", "00" & x"d152", "00" & x"d291",
    "00" & x"d3aa", "00" & x"d49f", "00" & x"d56e", "00" & x"d617",
    "00" & x"d69b", "00" & x"d6f9", "00" & x"d732", "00" & x"0000",
    -- Scale = 65536.
    "11" & x"0000", "11" & x"0016", "11" & x"005a", "11" & x"00ca",
    "11" & x"0167", "11" & x"0231", "11" & x"0327", "11" & x"0449",
    "11" & x"0598", "11" & x"0713", "11" & x"08b9", "11" & x"0a8b",
    "11" & x"0c88", "11" & x"0eaf", "11" & x"1101", "00" & x"0000",
    "11" & x"137d", "11" & x"1622", "11" & x"18f0", "11" & x"1be7",
    "11" & x"1f06", "11" & x"224c", "11" & x"25b9", "11" & x"294d",
    "11" & x"2d06", "11" & x"30e4", "11" & x"34e7", "11" & x"390d",
    "11" & x"3d56", "11" & x"41c1", "11" & x"464e", "00" & x"0000",
    "11" & x"4afb", "11" & x"4fc8", "11" & x"54b4", "11" & x"59be",
    "11" & x"5ee5", "11" & x"6428", "11" & x"6987", "11" & x"6f00",
    "11" & x"7493", "11" & x"7a3e", "11" & x"8000", "11" & x"85d9",
    "11" & x"8bc7", "11" & x"91ca", "11" & x"97e0", "00" & x"0000",
    "11" & x"9e08", "11" & x"a442", "11" & x"aa8c", "11" & x"b0e4",
    "11" & x"b74b", "11" & x"bdbe", "11" & x"c43d", "11" & x"cac6",
    "11" & x"d159", "11" & x"d7f4", "11" & x"de96", "11" & x"e53e",
    "11" & x"ebea", "11" & x"f29a", "11" & x"f94c", "00" & x"0000",
    "00" & x"0000", "00" & x"06b4", "00" & x"0d66", "00" & x"1416",
    "00" & x"1ac2", "00" & x"216a", "00" & x"280c", "00" & x"2ea7",
    "00" & x"353a", "00" & x"3bc3", "00" & x"4242", "00" & x"48b5",
    "00" & x"4f1c", "00" & x"5574", "00" & x"5bbe", "00" & x"0000",
    "00" & x"61f8", "00" & x"6820", "00" & x"6e36", "00" & x"7439",
    "00" & x"7a27", "00" & x"8000", "00" & x"85c2", "00" & x"8b6d",
    "00" & x"9100", "00" & x"9679", "00" & x"9bd8", "00" & x"a11b",
    "00" & x"a642", "00" & x"ab4c", "00" & x"b038", "00" & x"0000",
    "00" & x"b505", "00" & x"b9b2", "00" & x"be3f", "00" & x"c2aa",
    "00" & x"c6f3", "00" & x"cb19", "00" & x"cf1c", "00" & x"d2fa",
    "00" & x"d6b3", "00" & x"da47", "00" & x"ddb4", "00" & x"e0fa",
    "00" & x"e419", "00" & x"e710", "00" & x"e9de", "00" & x"0000",
    "00" & x"ec83", "00" & x"eeff", "00" & x"f151", "00" & x"f378",
    "00" & x"f575", "00" & x"f747", "00" & x"f8ed", "00" & x"fa68",
    "00" & x"fbb7", "00" & x"fcd9", "00" & x"fdcf", "00" & x"fe99",
    "00" & x"ff36", "00" & x"ffa6", "00" & x"ffea", "00" & x"0000",
    -- Scale = 77935.9.
    "10" & x"cf90", "10" & x"cfab", "10" & x"cffb", "10" & x"d080",
    "10" & x"d13b", "10" & x"d22b", "10" & x"d350", "10" & x"d4a9",
    "10" & x"d637", "10" & x"d7f9", "10" & x"d9f0", "10" & x"dc1a",
    "10" & x"de77", "10" & x"e106", "10" & x"e3c9", "00" & x"0000",
    "10" & x"e6bd", "10" & x"e9e2", "10" & x"ed38", "10" & x"f0bf",
    "10" & x"f475", "10" & x"f85a", "10" & x"fc6d", "11" & x"00ad",
    "11" & x"051b", "11" & x"09b5", "11" & x"0e79", "11" & x"1368",
    "11" & x"1881", "11" & x"1dc2", "11" & x"232b", "00" & x"0000",
    "11" & x"28bb", "11" & x"2e70", "11" & x"344b", "11" & x"3a49",
    "11" & x"4069", "11" & x"46ac", "11" & x"4d0e", "11" & x"5391",
    "11" & x"5a31", "11" & x"60ef", "11" & x"67c8", "11" & x"6ebc",
    "11" & x"75ca", "11" & x"7cf0", "11" & x"842d", "00" & x"0000",
    "11" & x"8b7f", "11" & x"92e6", "11" & x"9a60", "11" & x"a1ec",
    "11" & x"a989", "11" & x"b135", "11" & x"b8ee", "11" & x"c0b4",
    "11" & x"c885", "11" & x"d060", "11" & x"d843", "11" & x"e02d",
    "11" & x"e81d", "11" & x"f011", "11" & x"f808", "00" & x"0000",
    "00" & x"0000", "00" & x"07f8", "00" & x"0fef", "00" & x"17e3",
    "00" & x"1fd3", "00" & x"27bd", "00" & x"2fa0", "00" & x"377b",
    "00" & x"3f4c", "00" & x"4712", "00" & x"4ecb", "00" & x"5677",
    "00" & x"5e14", "00" & x"65a0", "00" & x"6d1a", "00" & x"0000",
    "00" & x"7481", "00" & x"7bd3", "00" & x"8310", "00" & x"8a36",
    "00" & x"9144", "00" & x"9838", "00" & x"9f11", "00" & x"a5cf",
    "00" & x"ac6f", "00" & x"b2f2", "00" & x"b954", "00" & x"bf97",
    "00" & x"c5b7", "00" & x"cbb5", "00" & x"d190", "00" & x"0000",
    "00" & x"d745", "00" & x"dcd5", "00" & x"e23e", "00" & x"e77f",
    "00" & x"ec98", "00" & x"f187", "00" & x"f64b", "00" & x"fae5",
    "00" & x"ff53", "01" & x"0393", "01" & x"07a6", "01" & x"0b8b",
    "01" & x"0f41", "01" & x"12c8", "01" & x"161e", "00" & x"0000",
    "01" & x"1943", "01" & x"1c37", "01" & x"1efa", "01" & x"2189",
    "01" & x"23e6", "01" & x"2610", "01" & x"2807", "01" & x"29c9",
    "01" & x"2b57", "01" & x"2cb0", "01" & x"2dd5", "01" & x"2ec5",
    "01" & x"2f80", "01" & x"3005", "01" & x"3055", "00" & x"0000",
    -- Scale = 92681.9.
    "10" & x"95f6", "10" & x"9616", "10" & x"9675", "10" & x"9714",
    "10" & x"97f2", "10" & x"990f", "10" & x"9a6b", "10" & x"9c06",
    "10" & x"9ddf", "10" & x"9ff7", "10" & x"a24c", "10" & x"a4df",
    "10" & x"a7ae", "10" & x"aaba", "10" & x"ae02", "00" & x"0000",
    "10" & x"b185", "10" & x"b543", "10" & x"b93b", "10" & x"bd6c",
    "10" & x"c1d6", "10" & x"c677", "10" & x"cb50", "10" & x"d05e",
    "10" & x"d5a2", "10" & x"db1b", "10" & x"e0c7", "10" & x"e6a5",
    "10" & x"ecb4", "10" & x"f2f4", "10" & x"f963", "00" & x"0000",
    "11" & x"0000", "11" & x"06ca", "11" & x"0dc0", "11" & x"14e0",
    "11" & x"1c29", "11" & x"239b", "11" & x"2b33", "11" & x"32f0",
    "11" & x"3ad2", "11" & x"42d6", "11" & x"4afb", "11" & x"5340",
    "11" & x"5ba3", "11" & x"6423", "11" & x"6cbf", "00" & x"0000",
    "11" & x"7574", "11" & x"7e42", "11" & x"8726", "11" & x"9020",
    "11" & x"992d", "11" & x"a24c", "11" & x"ab7c", "11" & x"b4ba",
    "11" & x"be06", "11" & x"c75d", "11" & x"d0bf", "11" & x"da28",
    "11" & x"e398", "11" & x"ed0d", "11" & x"f686", "00" & x"0000",
    "00" & x"0000", "00" & x"097a", "00" & x"12f3", "00" & x"1c68",
    "00" & x"25d8", "00" & x"2f41", "00" & x"38a3", "00" & x"41fa",
    "00" & x"4b46", "00" & x"5484", "00" & x"5db4", "00" & x"66d3",
    "00" & x"6fe0", "00" & x"78da", "00" & x"81be", "00" & x"0000",
    "00" & x"8a8c", "00" & x"9341", "00" & x"9bdd", "00" & x"a45d",
    "00" & x"acc0", "00" & x"b505", "00" & x"bd2a", "00" & x"c52e",
    "00" & x"cd10", "00" & x"d4cd", "00" & x"dc65", "00" & x"e3d7",
    "00" & x"eb20", "00" & x"f240", "00" & x"f936", "00" & x"0000",
    "01" & x"0000", "01" & x"069d", "01" & x"0d0c", "01" & x"134c",
    "01" & x"195b", "01" & x"1f39", "01" & x"24e5", "01" & x"2a5e",
    "01" & x"2fa2", "01" & x"34b0", "01" & x"3989", "01" & x"3e2a",
    "01" & x"4294", "01" & x"46c5", "01" & x"4abd", "00" & x"0000",
    "01" & x"4e7b", "01" & x"51fe", "01" & x"5546", "01" & x"5852",
    "01" & x"5b21", "01" & x"5db4", "01" & x"6009", "01" & x"6221",
    "01" & x"63fa", "01" & x"6595", "01" & x"66f1", "01" & x"680e",
    "01" & x"68ec", "01" & x"698b", "01" & x"69ea", "00" & x"0000",
    -- Scale = 110218.
    "10" & x"5176", "10" & x"519c", "10" & x"520d", "10" & x"52ca",
    "10" & x"53d2", "10" & x"5525", "10" & x"56c3", "10" & x"58ac",
    "10" & x"5adf", "10" & x"5d5b", "10" & x"6022", "10" & x"6331",
    "10" & x"6688", "10" & x"6a28", "10" & x"6e0f", "00" & x"0000",
    "10" & x"723c", "10" & x"76af", "10" & x"7b67", "10" & x"8063",
    "10" & x"85a3", "10" & x"8b24", "10" & x"90e8", "10" & x"96eb",
    "10" & x"9d2e", "10" & x"a3b0", "10" & x"aa6e", "10" & x"b169",
    "10" & x"b89e", "10" & x"c00c", "10" & x"c7b3", "00" & x"0000",
    "10" & x"cf90", "10" & x"d7a3", "10" & x"dfea", "10" & x"e863",
    "10" & x"f10e", "10" & x"f9e8", "11" & x"02ef", "11" & x"0c24",
    "11" & x"1583", "11" & x"1f0b", "11" & x"28bb", "11" & x"3291",
    "11" & x"3c8a", "11" & x"46a6", "11" & x"50e2", "00" & x"0000",
    "11" & x"5b3d", "11" & x"65b5", "11" & x"7048", "11" & x"7af5",
    "11" & x"85b8", "11" & x"9091", "11" & x"9b7e", "11" & x"a67c",
    "11" & x"b18a", "11" & x"bca6", "11" & x"c7ce", "11" & x"d2ff",
    "11" & x"de38", "11" & x"e978", "11" & x"f4bb", "00" & x"0000",
    "00" & x"0000", "00" & x"0b45", "00" & x"1688", "00" & x"21c8",
    "00" & x"2d01", "00" & x"3832", "00" & x"435a", "00" & x"4e76",
    "00" & x"5984", "00" & x"6482", "00" & x"6f6f", "00" & x"7a48",
    "00" & x"850b", "00" & x"8fb8", "00" & x"9a4b", "00" & x"0000",
    "00" & x"a4c3", "00" & x"af1e", "00" & x"b95a", "00" & x"c376",
    "00" & x"cd6f", "00" & x"d745", "00" & x"e0f5", "00" & x"ea7d",
    "00" & x"f3dc", "00" & x"fd11", "01" & x"0618", "01" & x"0ef2",
    "01" & x"179d", "01" & x"2016", "01" & x"285d", "00" & x"0000",
    "01" & x"3070", "01" & x"384d", "01" & x"3ff4", "01" & x"4762",
    "01" & x"4e97", "01" & x"5592", "01" & x"5c50", "01" & x"62d2",
    "01" & x"6915", "01" & x"6f18", "01" & x"74dc", "01" & x"7a5d",
    "01" & x"7f9d", "01" & x"8499", "01" & x"8951", "00" & x"0000",
    "01" & x"8dc4", "01" & x"91f1", "01" & x"95d8", "01" & x"9978",
    "01" & x"9ccf", "01" & x"9fde", "01" & x"a2a5", "01" & x"a521",
    "01" & x"a754", "01" & x"a93d", "01" & x"aadb", "01" & x"ac2e",
    "01" & x"ad36", "01" & x"adf3", "01" & x"ae64", "00" & x"0000",
    -- Scale = 131072.
    "10" & x"0000", "10" & x"002d", "10" & x"00b4", "10" & x"0194",
    "10" & x"02ce", "10" & x"0461", "10" & x"064e", "10" & x"0893",
    "10" & x"0b30", "10" & x"0e26", "10" & x"1172", "10" & x"1516",
    "10" & x"190f", "10" & x"1d5e", "10" & x"2202", "00" & x"0000",
    "10" & x"26f9", "10" & x"2c44", "10" & x"31e0", "10" & x"37ce",
    "10" & x"3e0c", "10" & x"4498", "10" & x"4b73", "10" & x"529a",
    "10" & x"5a0c", "10" & x"61c9", "10" & x"69ce", "10" & x"721a",
    "10" & x"7aac", "10" & x"8383", "10" & x"8c9c", "00" & x"0000",
    "10" & x"95f6", "10" & x"9f90", "10" & x"a968", "10" & x"b37c",
    "10" & x"bdca", "10" & x"c850", "10" & x"d30e", "10" & x"de00",
    "10" & x"e925", "10" & x"f47b", "11" & x"0000", "11" & x"0bb2",
    "11" & x"178f", "11" & x"2394", "11" & x"2fc0", "00" & x"0000",
    "11" & x"3c11", "11" & x"4884", "11" & x"5517", "11" & x"61c9",
    "11" & x"6e96", "11" & x"7b7c", "11" & x"887a", "11" & x"958d",
    "11" & x"a2b2", "11" & x"afe8", "11" & x"bd2c", "11" & x"ca7b",
    "11" & x"d7d4", "11" & x"e534", "11" & x"f299", "00" & x"0000",
    "00" & x"0000", "00" & x"0d67", "00" & x"1acc", "00" & x"282c",
    "00" & x"3585", "00" & x"42d4", "00" & x"5018", "00" & x"5d4e",
    "00" & x"6a73", "00" & x"7786", "00" & x"8484", "00" & x"916a",
    "00" & x"9e37", "00" & x"aae9", "00" & x"b77c", "00" & x"0000",
    "00" & x"c3ef", "00" & x"d040", "00" & x"dc6c", "00" & x"e871",
    "00" & x"f44e", "01" & x"0000", "01" & x"0b85", "01" & x"16db",
    "01" & x"2200", "01" & x"2cf2", "01" & x"37b0", "01" & x"4236",
    "01" & x"4c84", "01" & x"5698", "01" & x"6070", "00" & x"0000",
    "01" & x"6a0a", "01" & x"7364", "01" & x"7c7d", "01" & x"8554",
    "01" & x"8de6", "01" & x"9632", "01" & x"9e37", "01" & x"a5f4",
    "01" & x"ad66", "01" & x"b48d", "01" & x"bb68", "01" & x"c1f4",
    "01" & x"c832", "01" & x"ce20", "01" & x"d3bc", "00" & x"0000",
    "01" & x"d907", "01" & x"ddfe", "01" & x"e2a2", "01" & x"e6f1",
    "01" & x"eaea", "01" & x"ee8e", "01" & x"f1da", "01" & x"f4d0",
    "01" & x"f76d", "01" & x"f9b2", "01" & x"fb9f", "01" & x"fd32",
    "01" & x"fe6c", "01" & x"ff4c", "01" & x"ffd3", "00" & x"0000"
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

    variable shift0_r : signed(62 downto 0);
    variable shift0_i : signed(62 downto 0);

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
        phase <= (others => '0');
      else
        phase <= addmod240(phase, '0' & freq);
      end if;

      -- We actually use -cos(phase) + i sin(phase).
      cos <= cos_table(to_integer(table_select & phase(6 downto 0)));
      sin <= cos_table(to_integer(table_select & phase(6 downto 0)
                                  xor "0001000000"));
      cos_neg <= phase(7) = '1';
      sin_neg <= phase(7) /= phase(6);

      adc_r0 <= adc_data;
      adc_i0 <= adc_data;
      adc_r1 <= (x"0" & signed(adc_r0)) - offset;
      adc_i1 <= (x"0" & signed(adc_i0)) - offset;
      cos_1 <= cos;
      sin_1 <= sin;
      cos_neg_1 <= cos_neg;
      sin_neg_1 <= sin_neg;

      prod_r <= adc_r1 * cos_1;
      prod_i <= adc_i1 * sin_1;
      cos_neg_2 <= cos_neg_1;
      sin_neg_2 <= sin_neg_1;

      prod1_r <= prod_r;
      prod1_i <= prod_i;
      cos_neg_3 <= cos_neg_2;
      sin_neg_3 <= sin_neg_2;

      if cos_neg_3 then
        acc1_r <= acc1_r - prod1_r;
      else
        acc1_r <= acc1_r + prod1_r;
      end if;
      if sin_neg_3 then
        acc1_i <= acc1_i - prod1_i;
      else
        acc1_i <= acc1_i + prod1_i;
      end if;
      acc2_r <= acc2_r + acc1_r;
      acc2_i <= acc2_i + acc1_i;
      acc3_r <= acc3_r + acc2_r;
      acc3_i <= acc3_i + acc2_i;
      acc4_r <= acc4_r + acc3_r;
      acc4_i <= acc4_i + acc3_i;
      acc5_r <= acc5_r + acc4_r;
      acc5_i <= acc5_i + acc4_i;

      -- Do the left shift here, leaving us with a 32 bit word into the
      -- differencing.
      shift0_r := (others => '0');
      shift0_r(62 downto 62 - width) := acc5_r;
      shift0_i := (others => '0');
      shift0_i(62 downto 62 - width) := acc5_i;
      case shift(4 downto 3) is
        when "11" => shift1_r <= shift0_r(38 downto 0);
                     shift1_i <= shift0_i(38 downto 0);
        when "10" => shift1_r <= shift0_r(46 downto 8);
                     shift1_i <= shift0_i(46 downto 8);
        when "01" => shift1_r <= shift0_r(54 downto 16);
                     shift1_i <= shift0_i(54 downto 16);
        when others => shift1_r <= shift0_r(62 downto 24);
                       shift1_i <= shift0_i(62 downto 24);
      end case;
      case shift(2 downto 1) is
        when "11" => shift2_r <= shift1_r(32 downto 0);
                     shift2_i <= shift1_i(32 downto 0);
        when "10" => shift2_r <= shift1_r(34 downto 2);
                     shift2_i <= shift1_i(34 downto 2);
        when "01" => shift2_r <= shift1_r(36 downto 4);
                     shift2_i <= shift1_i(36 downto 4);
        when others => shift2_r <= shift1_r(38 downto 6);
                       shift2_i <= shift1_i(38 downto 6);
      end case;
      case shift(0) is
        when '1' => shift_r <= shift2_r(31 downto 0);
                    shift_i <= shift2_i(31 downto 0);
        when others => shift_r <= shift2_r(32 downto 1);
                       shift_i <= shift2_i(32 downto 1);
      end case;

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
        flt_r(0) <= shift_or_add(flt_r(0), zero, shift_r, op(0), 0);
        flt_i(0) <= shift_or_add(flt_i(0), zero, shift_i, op(0), 0);
      end if;
      for i in 1 to 5 loop
        if op(i)(1) = '1' then
          flt_r(i) <= shift_or_add(flt_r(i), flt_r(i-1), shift_r, op(i), i);
          flt_i(i) <= shift_or_add(flt_i(i), flt_i(i-1), shift_i, op(i), i);
        end if;
      end loop;

      if state = 47 then
        out0 <= flt_r(5)(31 downto 25) & (lfsr(0) and flt_i(5)(21));
        out1 <= flt_i(5)(31 downto 25) & (lfsr(0) or flt_i(5)(21));
        out2 <= flt_r(5)(24 downto 21) & flt_i(5)(24 downto 22) & lfsr(0);
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
          when 8|9|10|11|12|13|14 =>
            usb_nRD <= '0';
          when 15 =>
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
