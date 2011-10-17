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

  constant state_max : integer := 47;
  signal state : integer range 0 to state_max;

  signal phase_r : unsigned7;
  signal phase_i : unsigned7;
  signal freq_r : unsigned7;
  signal freq_i : unsigned7;
  signal offset : signed18;
  signal shift : unsigned(4 downto 0);

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
  constant op_arith : opcode_t := "10";
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
    "00" & x"2d41", "00" & x"2d28", "00" & x"2cde", "00" & x"2c63",
    "00" & x"2bb6", "00" & x"2ada", "00" & x"29cf", "00" & x"2896",
    "00" & x"2731", "00" & x"25a1", "00" & x"23e7", "00" & x"2206",
    "00" & x"2000", "00" & x"1dd7", "00" & x"1b8d", "00" & x"1924",
    "00" & x"16a1", "00" & x"1404", "00" & x"1151", "00" & x"0e8c",
    "00" & x"0bb6", "00" & x"08d4", "00" & x"05e8", "00" & x"02f6",
    "00" & x"0000", "11" & x"fd0a", "11" & x"fa18", "11" & x"f72c",
    "11" & x"f44a", "11" & x"f174", "11" & x"eeaf", "11" & x"ebfc",
    "11" & x"e95f", "11" & x"e6dc", "11" & x"e473", "11" & x"e229",
    "11" & x"e000", "11" & x"ddfa", "11" & x"dc19", "11" & x"da5f",
    "11" & x"d8cf", "11" & x"d76a", "11" & x"d631", "11" & x"d526",
    "11" & x"d44a", "11" & x"d39d", "11" & x"d322", "11" & x"d2d8",
    "11" & x"d2bf", "11" & x"d2d8", "11" & x"d322", "11" & x"d39d",
    "11" & x"d44a", "11" & x"d526", "11" & x"d631", "11" & x"d76a",
    "11" & x"d8cf", "11" & x"da5f", "11" & x"dc19", "11" & x"ddfa",
    "11" & x"e000", "11" & x"e229", "11" & x"e473", "11" & x"e6dc",
    "11" & x"e95f", "11" & x"ebfc", "11" & x"eeaf", "11" & x"f174",
    "11" & x"f44a", "11" & x"f72c", "11" & x"fa18", "11" & x"fd0a",
    "00" & x"0000", "00" & x"02f6", "00" & x"05e8", "00" & x"08d4",
    "00" & x"0bb6", "00" & x"0e8c", "00" & x"1151", "00" & x"1404",
    "00" & x"16a1", "00" & x"1924", "00" & x"1b8d", "00" & x"1dd7",
    "00" & x"2000", "00" & x"2206", "00" & x"23e7", "00" & x"25a1",
    "00" & x"2731", "00" & x"2896", "00" & x"29cf", "00" & x"2ada",
    "00" & x"2bb6", "00" & x"2c63", "00" & x"2cde", "00" & x"2d28",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 16384.
    "00" & x"4000", "00" & x"3fdd", "00" & x"3f74", "00" & x"3ec5",
    "00" & x"3dd2", "00" & x"3c9b", "00" & x"3b21", "00" & x"3966",
    "00" & x"376d", "00" & x"3537", "00" & x"32c6", "00" & x"301e",
    "00" & x"2d41", "00" & x"2a33", "00" & x"26f6", "00" & x"238e",
    "00" & x"2000", "00" & x"1c4e", "00" & x"187e", "00" & x"1492",
    "00" & x"1090", "00" & x"0c7c", "00" & x"085b", "00" & x"0430",
    "00" & x"0000", "11" & x"fbd0", "11" & x"f7a5", "11" & x"f384",
    "11" & x"ef70", "11" & x"eb6e", "11" & x"e782", "11" & x"e3b2",
    "11" & x"e000", "11" & x"dc72", "11" & x"d90a", "11" & x"d5cd",
    "11" & x"d2bf", "11" & x"cfe2", "11" & x"cd3a", "11" & x"cac9",
    "11" & x"c893", "11" & x"c69a", "11" & x"c4df", "11" & x"c365",
    "11" & x"c22e", "11" & x"c13b", "11" & x"c08c", "11" & x"c023",
    "11" & x"c000", "11" & x"c023", "11" & x"c08c", "11" & x"c13b",
    "11" & x"c22e", "11" & x"c365", "11" & x"c4df", "11" & x"c69a",
    "11" & x"c893", "11" & x"cac9", "11" & x"cd3a", "11" & x"cfe2",
    "11" & x"d2bf", "11" & x"d5cd", "11" & x"d90a", "11" & x"dc72",
    "11" & x"e000", "11" & x"e3b2", "11" & x"e782", "11" & x"eb6e",
    "11" & x"ef70", "11" & x"f384", "11" & x"f7a5", "11" & x"fbd0",
    "00" & x"0000", "00" & x"0430", "00" & x"085b", "00" & x"0c7c",
    "00" & x"1090", "00" & x"1492", "00" & x"187e", "00" & x"1c4e",
    "00" & x"2000", "00" & x"238e", "00" & x"26f6", "00" & x"2a33",
    "00" & x"2d41", "00" & x"301e", "00" & x"32c6", "00" & x"3537",
    "00" & x"376d", "00" & x"3966", "00" & x"3b21", "00" & x"3c9b",
    "00" & x"3dd2", "00" & x"3ec5", "00" & x"3f74", "00" & x"3fdd",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 23170.5.
    "00" & x"5a82", "00" & x"5a51", "00" & x"59bc", "00" & x"58c5",
    "00" & x"576d", "00" & x"55b5", "00" & x"539f", "00" & x"512d",
    "00" & x"4e62", "00" & x"4b42", "00" & x"47ce", "00" & x"440c",
    "00" & x"4000", "00" & x"3bad", "00" & x"3719", "00" & x"3249",
    "00" & x"2d41", "00" & x"2808", "00" & x"22a3", "00" & x"1d18",
    "00" & x"176d", "00" & x"11a8", "00" & x"0bd0", "00" & x"05eb",
    "00" & x"0000", "11" & x"fa15", "11" & x"f430", "11" & x"ee58",
    "11" & x"e893", "11" & x"e2e8", "11" & x"dd5d", "11" & x"d7f8",
    "11" & x"d2bf", "11" & x"cdb7", "11" & x"c8e7", "11" & x"c453",
    "11" & x"c000", "11" & x"bbf4", "11" & x"b832", "11" & x"b4be",
    "11" & x"b19e", "11" & x"aed3", "11" & x"ac61", "11" & x"aa4b",
    "11" & x"a893", "11" & x"a73b", "11" & x"a644", "11" & x"a5af",
    "11" & x"a57e", "11" & x"a5af", "11" & x"a644", "11" & x"a73b",
    "11" & x"a893", "11" & x"aa4b", "11" & x"ac61", "11" & x"aed3",
    "11" & x"b19e", "11" & x"b4be", "11" & x"b832", "11" & x"bbf4",
    "11" & x"c000", "11" & x"c453", "11" & x"c8e7", "11" & x"cdb7",
    "11" & x"d2bf", "11" & x"d7f8", "11" & x"dd5d", "11" & x"e2e8",
    "11" & x"e893", "11" & x"ee58", "11" & x"f430", "11" & x"fa15",
    "00" & x"0000", "00" & x"05eb", "00" & x"0bd0", "00" & x"11a8",
    "00" & x"176d", "00" & x"1d18", "00" & x"22a3", "00" & x"2808",
    "00" & x"2d41", "00" & x"3249", "00" & x"3719", "00" & x"3bad",
    "00" & x"4000", "00" & x"440c", "00" & x"47ce", "00" & x"4b42",
    "00" & x"4e62", "00" & x"512d", "00" & x"539f", "00" & x"55b5",
    "00" & x"576d", "00" & x"58c5", "00" & x"59bc", "00" & x"5a51",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 32768.
    "00" & x"8000", "00" & x"7fba", "00" & x"7ee8", "00" & x"7d8a",
    "00" & x"7ba3", "00" & x"7935", "00" & x"7642", "00" & x"72cd",
    "00" & x"6eda", "00" & x"6a6e", "00" & x"658d", "00" & x"603c",
    "00" & x"5a82", "00" & x"5465", "00" & x"4dec", "00" & x"471d",
    "00" & x"4000", "00" & x"389d", "00" & x"30fc", "00" & x"2925",
    "00" & x"2121", "00" & x"18f9", "00" & x"10b5", "00" & x"085f",
    "00" & x"0000", "11" & x"f7a1", "11" & x"ef4b", "11" & x"e707",
    "11" & x"dedf", "11" & x"d6db", "11" & x"cf04", "11" & x"c763",
    "11" & x"c000", "11" & x"b8e3", "11" & x"b214", "11" & x"ab9b",
    "11" & x"a57e", "11" & x"9fc4", "11" & x"9a73", "11" & x"9592",
    "11" & x"9126", "11" & x"8d33", "11" & x"89be", "11" & x"86cb",
    "11" & x"845d", "11" & x"8276", "11" & x"8118", "11" & x"8046",
    "11" & x"8000", "11" & x"8046", "11" & x"8118", "11" & x"8276",
    "11" & x"845d", "11" & x"86cb", "11" & x"89be", "11" & x"8d33",
    "11" & x"9126", "11" & x"9592", "11" & x"9a73", "11" & x"9fc4",
    "11" & x"a57e", "11" & x"ab9b", "11" & x"b214", "11" & x"b8e3",
    "11" & x"c000", "11" & x"c763", "11" & x"cf04", "11" & x"d6db",
    "11" & x"dedf", "11" & x"e707", "11" & x"ef4b", "11" & x"f7a1",
    "00" & x"0000", "00" & x"085f", "00" & x"10b5", "00" & x"18f9",
    "00" & x"2121", "00" & x"2925", "00" & x"30fc", "00" & x"389d",
    "00" & x"4000", "00" & x"471d", "00" & x"4dec", "00" & x"5465",
    "00" & x"5a82", "00" & x"603c", "00" & x"658d", "00" & x"6a6e",
    "00" & x"6eda", "00" & x"72cd", "00" & x"7642", "00" & x"7935",
    "00" & x"7ba3", "00" & x"7d8a", "00" & x"7ee8", "00" & x"7fba",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 46341.
    "00" & x"b505", "00" & x"b4a2", "00" & x"b378", "00" & x"b18b",
    "00" & x"aeda", "00" & x"ab6a", "00" & x"a73d", "00" & x"a25a",
    "00" & x"9cc4", "00" & x"9683", "00" & x"8f9d", "00" & x"8819",
    "00" & x"8000", "00" & x"775b", "00" & x"6e33", "00" & x"6492",
    "00" & x"5a82", "00" & x"5010", "00" & x"4546", "00" & x"3a30",
    "00" & x"2eda", "00" & x"2351", "00" & x"17a1", "00" & x"0bd7",
    "00" & x"0000", "11" & x"f429", "11" & x"e85f", "11" & x"dcaf",
    "11" & x"d126", "11" & x"c5d0", "11" & x"baba", "11" & x"aff0",
    "11" & x"a57e", "11" & x"9b6e", "11" & x"91cd", "11" & x"88a5",
    "11" & x"8000", "11" & x"77e7", "11" & x"7063", "11" & x"697d",
    "11" & x"633c", "11" & x"5da6", "11" & x"58c3", "11" & x"5496",
    "11" & x"5126", "11" & x"4e75", "11" & x"4c88", "11" & x"4b5e",
    "11" & x"4afb", "11" & x"4b5e", "11" & x"4c88", "11" & x"4e75",
    "11" & x"5126", "11" & x"5496", "11" & x"58c3", "11" & x"5da6",
    "11" & x"633c", "11" & x"697d", "11" & x"7063", "11" & x"77e7",
    "11" & x"8000", "11" & x"88a5", "11" & x"91cd", "11" & x"9b6e",
    "11" & x"a57e", "11" & x"aff0", "11" & x"baba", "11" & x"c5d0",
    "11" & x"d126", "11" & x"dcaf", "11" & x"e85f", "11" & x"f429",
    "00" & x"0000", "00" & x"0bd7", "00" & x"17a1", "00" & x"2351",
    "00" & x"2eda", "00" & x"3a30", "00" & x"4546", "00" & x"5010",
    "00" & x"5a82", "00" & x"6492", "00" & x"6e33", "00" & x"775b",
    "00" & x"8000", "00" & x"8819", "00" & x"8f9d", "00" & x"9683",
    "00" & x"9cc4", "00" & x"a25a", "00" & x"a73d", "00" & x"ab6a",
    "00" & x"aeda", "00" & x"b18b", "00" & x"b378", "00" & x"b4a2",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 65536.
    "01" & x"0000", "00" & x"ff74", "00" & x"fdcf", "00" & x"fb15",
    "00" & x"f747", "00" & x"f26a", "00" & x"ec83", "00" & x"e599",
    "00" & x"ddb4", "00" & x"d4db", "00" & x"cb19", "00" & x"c079",
    "00" & x"b505", "00" & x"a8cb", "00" & x"9bd8", "00" & x"8e3a",
    "00" & x"8000", "00" & x"713a", "00" & x"61f8", "00" & x"524a",
    "00" & x"4242", "00" & x"31f1", "00" & x"216a", "00" & x"10be",
    "00" & x"0000", "11" & x"ef42", "11" & x"de96", "11" & x"ce0f",
    "11" & x"bdbe", "11" & x"adb6", "11" & x"9e08", "11" & x"8ec6",
    "11" & x"8000", "11" & x"71c6", "11" & x"6428", "11" & x"5735",
    "11" & x"4afb", "11" & x"3f87", "11" & x"34e7", "11" & x"2b25",
    "11" & x"224c", "11" & x"1a67", "11" & x"137d", "11" & x"0d96",
    "11" & x"08b9", "11" & x"04eb", "11" & x"0231", "11" & x"008c",
    "11" & x"0000", "11" & x"008c", "11" & x"0231", "11" & x"04eb",
    "11" & x"08b9", "11" & x"0d96", "11" & x"137d", "11" & x"1a67",
    "11" & x"224c", "11" & x"2b25", "11" & x"34e7", "11" & x"3f87",
    "11" & x"4afb", "11" & x"5735", "11" & x"6428", "11" & x"71c6",
    "11" & x"8000", "11" & x"8ec6", "11" & x"9e08", "11" & x"adb6",
    "11" & x"bdbe", "11" & x"ce0f", "11" & x"de96", "11" & x"ef42",
    "00" & x"0000", "00" & x"10be", "00" & x"216a", "00" & x"31f1",
    "00" & x"4242", "00" & x"524a", "00" & x"61f8", "00" & x"713a",
    "00" & x"8000", "00" & x"8e3a", "00" & x"9bd8", "00" & x"a8cb",
    "00" & x"b505", "00" & x"c079", "00" & x"cb19", "00" & x"d4db",
    "00" & x"ddb4", "00" & x"e599", "00" & x"ec83", "00" & x"f26a",
    "00" & x"f747", "00" & x"fb15", "00" & x"fdcf", "00" & x"ff74",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 92681.9.
    "01" & x"6a0a", "01" & x"6943", "01" & x"66f1", "01" & x"6315",
    "01" & x"5db4", "01" & x"56d3", "01" & x"4e7b", "01" & x"44b4",
    "01" & x"3989", "01" & x"2d06", "01" & x"1f39", "01" & x"1032",
    "01" & x"0000", "00" & x"eeb5", "00" & x"dc65", "00" & x"c923",
    "00" & x"b505", "00" & x"a020", "00" & x"8a8c", "00" & x"7460",
    "00" & x"5db4", "00" & x"46a1", "00" & x"2f41", "00" & x"17ae",
    "00" & x"0000", "11" & x"e852", "11" & x"d0bf", "11" & x"b95f",
    "11" & x"a24c", "11" & x"8ba0", "11" & x"7574", "11" & x"5fe0",
    "11" & x"4afb", "11" & x"36dd", "11" & x"239b", "11" & x"114b",
    "11" & x"0000", "10" & x"efce", "10" & x"e0c7", "10" & x"d2fa",
    "10" & x"c677", "10" & x"bb4c", "10" & x"b185", "10" & x"a92d",
    "10" & x"a24c", "10" & x"9ceb", "10" & x"990f", "10" & x"96bd",
    "10" & x"95f6", "10" & x"96bd", "10" & x"990f", "10" & x"9ceb",
    "10" & x"a24c", "10" & x"a92d", "10" & x"b185", "10" & x"bb4c",
    "10" & x"c677", "10" & x"d2fa", "10" & x"e0c7", "10" & x"efce",
    "11" & x"0000", "11" & x"114b", "11" & x"239b", "11" & x"36dd",
    "11" & x"4afb", "11" & x"5fe0", "11" & x"7574", "11" & x"8ba0",
    "11" & x"a24c", "11" & x"b95f", "11" & x"d0bf", "11" & x"e852",
    "00" & x"0000", "00" & x"17ae", "00" & x"2f41", "00" & x"46a1",
    "00" & x"5db4", "00" & x"7460", "00" & x"8a8c", "00" & x"a020",
    "00" & x"b505", "00" & x"c923", "00" & x"dc65", "00" & x"eeb5",
    "01" & x"0000", "01" & x"1032", "01" & x"1f39", "01" & x"2d06",
    "01" & x"3989", "01" & x"44b4", "01" & x"4e7b", "01" & x"56d3",
    "01" & x"5db4", "01" & x"6315", "01" & x"66f1", "01" & x"6943",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
-- Scale = 131071.
    "01" & x"ffff", "01" & x"fee6", "01" & x"fb9e", "01" & x"f629",
    "01" & x"ee8d", "01" & x"e4d3", "01" & x"d906", "01" & x"cb32",
    "01" & x"bb67", "01" & x"a9b6", "01" & x"9632", "01" & x"80f0",
    "01" & x"6a09", "01" & x"5195", "01" & x"37af", "01" & x"1c73",
    "01" & x"0000", "00" & x"e273", "00" & x"c3ef", "00" & x"a493",
    "00" & x"8484", "00" & x"63e3", "00" & x"42d4", "00" & x"217c",
    "00" & x"0000", "11" & x"de84", "11" & x"bd2c", "11" & x"9c1d",
    "11" & x"7b7c", "11" & x"5b6d", "11" & x"3c11", "11" & x"1d8d",
    "11" & x"0001", "10" & x"e38d", "10" & x"c851", "10" & x"ae6b",
    "10" & x"95f7", "10" & x"7f10", "10" & x"69ce", "10" & x"564a",
    "10" & x"4499", "10" & x"34ce", "10" & x"26fa", "10" & x"1b2d",
    "10" & x"1173", "10" & x"09d7", "10" & x"0462", "10" & x"011a",
    "10" & x"0001", "10" & x"011a", "10" & x"0462", "10" & x"09d7",
    "10" & x"1173", "10" & x"1b2d", "10" & x"26fa", "10" & x"34ce",
    "10" & x"4499", "10" & x"564a", "10" & x"69ce", "10" & x"7f10",
    "10" & x"95f7", "10" & x"ae6b", "10" & x"c851", "10" & x"e38d",
    "11" & x"0000", "11" & x"1d8d", "11" & x"3c11", "11" & x"5b6d",
    "11" & x"7b7c", "11" & x"9c1d", "11" & x"bd2c", "11" & x"de84",
    "00" & x"0000", "00" & x"217c", "00" & x"42d4", "00" & x"63e3",
    "00" & x"8484", "00" & x"a493", "00" & x"c3ef", "00" & x"e273",
    "00" & x"ffff", "01" & x"1c73", "01" & x"37af", "01" & x"5195",
    "01" & x"6a09", "01" & x"80f0", "01" & x"9632", "01" & x"a9b6",
    "01" & x"bb67", "01" & x"cb32", "01" & x"d906", "01" & x"e4d3",
    "01" & x"ee8d", "01" & x"f629", "01" & x"fb9e", "01" & x"fee6",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0000", "00" & x"0000", "00" & x"0000"
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
  begin
    if clk_main'event and clk_main = '1' then
      div25_inc := ('0' & div25) + 1;
      div25 <= div25_inc(24 downto 0);

      if state = state_max then
        state <= 0;
      else
        state <= state + 1;
      end if;

      phase_r <= addmod96(phase_r, freq_r);
      phase_i <= addmod96(phase_r, freq_i);
      freq_i <= addmod96(freq_r, "1001000");

      cos <= cos_table(to_integer(table_select & phase_r));
      sin <= cos_table(to_integer(table_select & phase_i));

      adc_r0 <= adc_data;
      adc_i0 <= adc_data;
      adc_r1 <= (x"0" & signed(adc_r0)) + offset;
      adc_i1 <= (x"0" & signed(adc_i0)) + offset;
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
        when  0 => op(2) <= op_arith; --  96 = 12 + 39 + 45
        when  3 => op(1) <= op_arith; --  51 = 12 + 39
        when  5 => op(3) <= op_arith; -- 149 = 12 + 39 + 45 + 53
        when  8 => op(2) <= op_arith; -- 104 = 12 + 39 + 53
        when  9 => op(1) <= op_arith; --  57 = 12 + 45
        when 12 => op(0) <= op_arith; --  12
                   op(3) <= op_arith; -- 156 = 12 + 39 + 45 + 60
        when 14 => op(2) <= op_arith; -- 110 = 12 + 45 + 53
        when 15 => op(2) <= op_arith; -- 111 = 12 + 39 + 60
        when 16 => op(3) <= op_arith; -- 160 = 12 + 39 + 45 + 64
        when 17 => op(1) <= op_arith; --  65 = 12 + 53
                   op(4) <= op_arith; -- 209 = 12 + 39 + 45 + 53 + 60
        when 19 => op(2) <= op_arith; -- 115 = 12 + 39 + 64
        when 20 => op(3) <= op_arith; -- 164 = 12 + 39 + 53 + 60
        when 21 => op(2) <= op_arith; -- 117 = 12 + 45 + 60
                   op(4) <= op_arith; -- 213 = 12 + 39 + 45 + 53 + 64
        when 24 => op(1) <= op_arith; --  72 = 12 + 60
                   op(3) <= op_arith; -- 168 = 12 + 39 + 53 + 64
        when 25 => op(2) <= op_arith; -- 121 = 12 + 45 + 64
        when 26 => op(3) <= op_arith; -- 170 = 12 + 45 + 53 + 60
        when 28 => op(1) <= op_arith; --  76 = 12 + 64
                   op(4) <= op_arith; -- 220 = 12 + 39 + 45 + 60 + 64
        when 29 => op(2) <= op_arith; -- 125 = 12 + 53 + 60
        when 30 => op(3) <= op_arith; -- 174 = 12 + 45 + 53 + 64
        when 31 => op(3) <= op_arith; -- 175 = 12 + 39 + 60 + 64
        when 33 => op(2) <= op_arith; -- 129 = 12 + 53 + 64
                   op(5) <= op_arith; -- 273 = 12 + 39 + 45 + 53 + 60 + 64
        when 36 => op(4) <= op_arith; -- 228 = 12 + 39 + 53 + 60 + 64
        when 37 => op(3) <= op_arith; -- 181 = 12 + 45 + 60 + 64
        when 40 => op(2) <= op_arith; -- 136 = 12 + 60 + 64
        when 42 => op(4) <= op_arith; -- 234 = 12 + 45 + 53 + 60 + 64
        when 45 => op(3) <= op_arith; -- 189 = 12 + 53 + 60 + 64
        when 46 =>
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
          out1 <= out2_i(11 downto 5) & lfsr(0);
          out2 <= out2_r(4 downto 1) & out2_i(4 downto 2)
                  & (lfsr(0) or out2_i(1));
        else
          out0 <= out2_r(10 downto 4) & (lfsr(0) and out2_i(0));
          out1 <= out2_i(10 downto 4) & lfsr(0);
          out2 <= out2_r(3 downto 0) & out2_i(3 downto 1)
                  & (lfsr(0) or out2_i(0));
        end if;
        lfsr <= lfsr(30 downto 0) & (
          lfsr(31) xor lfsr(22) xor lfsr(12) xor lfsr(5));
      end if;

      case state / 16 is
        when 0 => usb_d_out <= unsigned(out0);
        when 1 => usb_d_out <= unsigned(out1);
        when 2 => usb_d_out <= unsigned(out2);
        when others => usb_d_out <= "XXXXXXXX";
      end case;

      usb_oe <= false;
      usb_nWR <= '1';
      case state mod 16 is
        when 0|1 =>
          usb_oe <= true;
        when 2|3 =>
          usb_nWR <= '0';
          usb_oe <= true;
        when 4|5|6|7|8|9 =>
          usb_nWR <= '1';
        when others =>
      end case;

      -- Sample nRXF on 5, reset on 21, 37.
      if state mod 16 = 5 then
        usb_rd <= (state / 16 = 0) and usb_nRXF = '0';
      end if;

      usb_nRD <= '1';
      usb_rd_process <= false;
      if usb_rd then
        case state mod 16 is
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
            freq_r(4 downto 0) <= usb_d(4 downto 0);
          when "010" =>
            freq_r(6 downto 5) <= usb_d(1 downto 0);
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
  -- We run the PLL oscillator at 875MHz, i.e., 4 times the input clock.
  main_pll : PLL_BASE
    generic map(
      BANDWIDTH            => "LOW",
      CLK_FEEDBACK         => "CLKOUT0",
      --COMPENSATION         => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 1,
      --CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 4,
      --CLKOUT0_PHASE        => 0.000,
      --CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT1_DIVIDE       => 4,
      CLKOUT1_PHASE        => 180.000,
      --CLKOUT1_DUTY_CYCLE   => 0.500,
      --CLKIN_PERIOD         => 10.0,
      REF_JITTER           => 0.001)
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

  -- Generate the clock to the ADC.  We run the PLL oscillator at 875MHz, (7
  -- times the input clock), and then generate a 217.5MHz output.
  adc_gen_pll : PLL_BASE
    generic map(
      BANDWIDTH            => "LOW",
      CLK_FEEDBACK         => "CLKFBOUT",
      --COMPENSATION         => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 7,
      --CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 4,
      --CLKOUT0_PHASE        => 0.000,
      --CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT1_DIVIDE       => 4,
      CLKOUT1_PHASE        => 180.000,
      --CLKOUT1_DUTY_CYCLE   => 0.500,
      --CLKIN_PERIOD         => 8.0,
      REF_JITTER           => 0.001)
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
