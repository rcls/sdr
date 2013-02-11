-- Filter given by a fifth order polynomial:
-- plot 10 * log ((sin(x*pi*39/48) * sin(x*pi*45/48) * sin(x*pi*53/48) * sin(x*pi*60/48) * sin(x*pi*64/48) * 48 * 48 * 48 * 48 * 48 / 39 / 45 / 53 / 60 / 64 / pi / pi / pi / pi / pi / x / x / x / x / x)**2) /log(10)

--  39,45,53,50,54

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity sample30 is
  port(adc_data : in signed14;
       freq, gain : in unsigned8;
       out_r, out_i : out signed15;
       strobe : out std_logic;
       clk : in std_logic);
end sample30;

architecture sample30 of sample30 is

  constant state_max : integer := 79;
  signal state : integer range 0 to state_max;

  signal phase : unsigned9 := "0" & x"00";
  alias shift : unsigned(3 downto 0) is gain(5 downto 2);

  -- Select part of trig. rom.
  alias table_select : unsigned2 is gain(1 downto 0);

  -- Accumulator widths minus one...
  constant width1 : integer := 62;
  constant width2 : integer := 55;
  constant width3 : integer := 48;
  constant width4 : integer := 41;
  constant width5 : integer := 34;

  -- Differencer width minus one...
  constant diffw : integer := 14;

  -- Type used for arithmetic in the differencers.
  subtype wordd is signed(diffw downto 0);
  type wordd_array is array (natural range <>) of wordd;
  constant zero : wordd := (others => '0');

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

  signal adc_r0 : signed18;
  signal adc_i0 : signed18;

  signal prod_r : signed36;
  signal prod_i : signed36;
  signal prod1_r : signed36;
  signal prod1_i : signed36;

  -- The multiplier can absorb two levels of registers; but we want to keep
  -- the second level in fabric to be as close as possible to the big adders.
  attribute keep of prod_r : signal is "true";
  attribute keep of prod_i : signal is "true";

  signal acc1_r : signed(width1 downto 0);
  signal acc1_i : signed(width1 downto 0);
  signal acc2_r : signed(width2 downto 0);
  signal acc2_i : signed(width2 downto 0);
  signal acc3_r : signed(width3 downto 0);
  signal acc3_i : signed(width3 downto 0);
  signal acc4_r : signed(width4 downto 0);
  signal acc4_i : signed(width4 downto 0);
  signal acc5_r : signed(width5 downto 0);
  signal acc5_i : signed(width5 downto 0);

  signal shift1_r : signed(diffw + 3 downto 0);
  signal shift1_i : signed(diffw + 3 downto 0);
  signal shift2_r : signed(diffw downto 0);
  signal shift2_i : signed(diffw downto 0);

  signal flt_r : wordd_array(0 to 5);
  signal flt_i : wordd_array(0 to 5);

  subtype opcode_t is std_logic_vector(1 downto 0);
  constant op_pass : opcode_t := "00";
  constant op_add : opcode_t := "10";
  constant op_shift : opcode_t := "11";
  type opcodes_t is array (natural range <>) of opcode_t;
  signal op : opcodes_t(0 to 5);
  signal op1 : opcodes_t(0 to 5);
  attribute keep of op : signal is "true";

  function shift_or_add(acc : wordd; prev : wordd; adc : wordd;
                        o : opcode_t; i : integer) return wordd is
    variable addend1 : wordd;
    variable addend2 : wordd;
    variable sum : wordd;
  begin
    if o(0) = '1' then
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

  -- The cos table is 4 tables of 160 entries.  We store half a cycle, negated.
  -- This means that +1 never occurs and we can use the full negative range.
  type signed18_array is array (natural range <>) of signed18;
  signal cos_table : signed18_array(0 to 1023) := (
    -- Scale = 77935.9.
    "10" & x"cf90", "10" & x"cf9f", "10" & x"cfcc", "10" & x"d017",
    "10" & x"d080", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"d107", "10" & x"d1ac", "10" & x"d26f", "10" & x"d350",
    "10" & x"d44e", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"d56a", "10" & x"d6a3", "10" & x"d7f9", "10" & x"d96d",
    "10" & x"dafe", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"dcac", "10" & x"de77", "10" & x"e05e", "10" & x"e261",
    "10" & x"e481", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"e6bd", "10" & x"e914", "10" & x"eb87", "10" & x"ee15",
    "10" & x"f0bf", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"f383", "10" & x"f661", "10" & x"f95a", "10" & x"fc6d",
    "10" & x"ff99", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"02df", "11" & x"063d", "11" & x"09b5", "11" & x"0d44",
    "11" & x"10ec", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"14ab", "11" & x"1881", "11" & x"1c6e", "11" & x"2072",
    "11" & x"248c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"28bb", "11" & x"2d00", "11" & x"3159", "11" & x"35c7",
    "11" & x"3a49", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"3ede", "11" & x"4386", "11" & x"4841", "11" & x"4d0e",
    "11" & x"51ed", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"56dd", "11" & x"5bde", "11" & x"60ef", "11" & x"660f",
    "11" & x"6b3f", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"707d", "11" & x"75ca", "11" & x"7b24", "11" & x"808b",
    "11" & x"85ff", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"8b7f", "11" & x"910b", "11" & x"96a1", "11" & x"9c42",
    "11" & x"a1ec", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"a7a0", "11" & x"ad5d", "11" & x"b322", "11" & x"b8ee",
    "11" & x"bec2", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"c49b", "11" & x"ca7b", "11" & x"d060", "11" & x"d64a",
    "11" & x"dc38", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"e229", "11" & x"e81d", "11" & x"ee14", "11" & x"f40c",
    "11" & x"fa06", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"05fa", "00" & x"0bf4", "00" & x"11ec",
    "00" & x"17e3", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"1dd7", "00" & x"23c8", "00" & x"29b6", "00" & x"2fa0",
    "00" & x"3585", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"3b65", "00" & x"413e", "00" & x"4712", "00" & x"4cde",
    "00" & x"52a3", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"5860", "00" & x"5e14", "00" & x"63be", "00" & x"695f",
    "00" & x"6ef5", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"7481", "00" & x"7a01", "00" & x"7f75", "00" & x"84dc",
    "00" & x"8a36", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"8f83", "00" & x"94c1", "00" & x"99f1", "00" & x"9f11",
    "00" & x"a422", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"a923", "00" & x"ae13", "00" & x"b2f2", "00" & x"b7bf",
    "00" & x"bc7a", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"c122", "00" & x"c5b7", "00" & x"ca39", "00" & x"cea7",
    "00" & x"d300", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"d745", "00" & x"db74", "00" & x"df8e", "00" & x"e392",
    "00" & x"e77f", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"eb55", "00" & x"ef14", "00" & x"f2bc", "00" & x"f64b",
    "00" & x"f9c3", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"fd21", "01" & x"0067", "01" & x"0393", "01" & x"06a6",
    "01" & x"099f", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"0c7d", "01" & x"0f41", "01" & x"11eb", "01" & x"1479",
    "01" & x"16ec", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"1943", "01" & x"1b7f", "01" & x"1d9f", "01" & x"1fa2",
    "01" & x"2189", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"2354", "01" & x"2502", "01" & x"2693", "01" & x"2807",
    "01" & x"295d", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"2a96", "01" & x"2bb2", "01" & x"2cb0", "01" & x"2d91",
    "01" & x"2e54", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"2ef9", "01" & x"2f80", "01" & x"2fe9", "01" & x"3034",
    "01" & x"3061", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 92681.9.
    "10" & x"95f6", "10" & x"9608", "10" & x"963e", "10" & x"9697",
    "10" & x"9714", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"97b4", "10" & x"9879", "10" & x"9960", "10" & x"9a6b",
    "10" & x"9b99", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"9ceb", "10" & x"9e5f", "10" & x"9ff7", "10" & x"a1b1",
    "10" & x"a38e", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"a58d", "10" & x"a7ae", "10" & x"a9f2", "10" & x"ac57",
    "10" & x"aedd", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"b185", "10" & x"b44e", "10" & x"b738", "10" & x"ba42",
    "10" & x"bd6c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"c0b6", "10" & x"c41f", "10" & x"c7a8", "10" & x"cb50",
    "10" & x"cf16", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"d2fa", "10" & x"d6fc", "10" & x"db1b", "10" & x"df57",
    "10" & x"e3af", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"e824", "10" & x"ecb4", "10" & x"f160", "10" & x"f626",
    "10" & x"fb06", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"0000", "11" & x"0513", "11" & x"0a3f", "11" & x"0f84",
    "11" & x"14e0", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"1a53", "11" & x"1fdd", "11" & x"257d", "11" & x"2b33",
    "11" & x"30fe", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"36dd", "11" & x"3cd0", "11" & x"42d6", "11" & x"48ef",
    "11" & x"4f1a", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"5556", "11" & x"5ba3", "11" & x"6201", "11" & x"686e",
    "11" & x"6eea", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"7574", "11" & x"7c0c", "11" & x"82b1", "11" & x"8963",
    "11" & x"9020", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"96e8", "11" & x"9dba", "11" & x"a497", "11" & x"ab7c",
    "11" & x"b269", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"b95f", "11" & x"c05b", "11" & x"c75d", "11" & x"ce65",
    "11" & x"d572", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"dc84", "11" & x"e398", "11" & x"eab0", "11" & x"f1c9",
    "11" & x"f8e4", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"071c", "00" & x"0e37", "00" & x"1550",
    "00" & x"1c68", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"237c", "00" & x"2a8e", "00" & x"319b", "00" & x"38a3",
    "00" & x"3fa5", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"46a1", "00" & x"4d97", "00" & x"5484", "00" & x"5b69",
    "00" & x"6246", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"6918", "00" & x"6fe0", "00" & x"769d", "00" & x"7d4f",
    "00" & x"83f4", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"8a8c", "00" & x"9116", "00" & x"9792", "00" & x"9dff",
    "00" & x"a45d", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"aaaa", "00" & x"b0e6", "00" & x"b711", "00" & x"bd2a",
    "00" & x"c330", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"c923", "00" & x"cf02", "00" & x"d4cd", "00" & x"da83",
    "00" & x"e023", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"e5ad", "00" & x"eb20", "00" & x"f07c", "00" & x"f5c1",
    "00" & x"faed", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"0000", "01" & x"04fa", "01" & x"09da", "01" & x"0ea0",
    "01" & x"134c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"17dc", "01" & x"1c51", "01" & x"20a9", "01" & x"24e5",
    "01" & x"2904", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"2d06", "01" & x"30ea", "01" & x"34b0", "01" & x"3858",
    "01" & x"3be1", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"3f4a", "01" & x"4294", "01" & x"45be", "01" & x"48c8",
    "01" & x"4bb2", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"4e7b", "01" & x"5123", "01" & x"53a9", "01" & x"560e",
    "01" & x"5852", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"5a73", "01" & x"5c72", "01" & x"5e4f", "01" & x"6009",
    "01" & x"61a1", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"6315", "01" & x"6467", "01" & x"6595", "01" & x"66a0",
    "01" & x"6787", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"684c", "01" & x"68ec", "01" & x"6969", "01" & x"69c2",
    "01" & x"69f8", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 110218.
    "10" & x"5176", "10" & x"518b", "10" & x"51cb", "10" & x"5235",
    "10" & x"52ca", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"5389", "10" & x"5472", "10" & x"5585", "10" & x"56c3",
    "10" & x"582a", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"59bc", "10" & x"5b77", "10" & x"5d5b", "10" & x"5f69",
    "10" & x"61a0", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"6400", "10" & x"6688", "10" & x"6939", "10" & x"6c12",
    "10" & x"6f13", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"723c", "10" & x"758c", "10" & x"7902", "10" & x"7ca0",
    "10" & x"8063", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"844c", "10" & x"885b", "10" & x"8c8f", "10" & x"90e8",
    "10" & x"9565", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"9a05", "10" & x"9ec9", "10" & x"a3b0", "10" & x"a8b9",
    "10" & x"ade4", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"b330", "10" & x"b89e", "10" & x"be2b", "10" & x"c3d8",
    "10" & x"c9a5", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"cf90", "10" & x"d599", "10" & x"dbc0", "10" & x"e203",
    "10" & x"e863", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"eede", "10" & x"f575", "10" & x"fc25", "11" & x"02ef",
    "11" & x"09d3", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"10ce", "11" & x"17e1", "11" & x"1f0b", "11" & x"264b",
    "11" & x"2da1", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"350c", "11" & x"3c8a", "11" & x"441c", "11" & x"4bc0",
    "11" & x"5376", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"5b3d", "11" & x"6315", "11" & x"6afc", "11" & x"72f1",
    "11" & x"7af5", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"8305", "11" & x"8b22", "11" & x"934b", "11" & x"9b7e",
    "11" & x"a3bb", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"ac02", "11" & x"b450", "11" & x"bca6", "11" & x"c503",
    "11" & x"cd65", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"d5cd", "11" & x"de38", "11" & x"e6a7", "11" & x"ef19",
    "11" & x"f78c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0874", "00" & x"10e7", "00" & x"1959",
    "00" & x"21c8", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"2a33", "00" & x"329b", "00" & x"3afd", "00" & x"435a",
    "00" & x"4bb0", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"53fe", "00" & x"5c45", "00" & x"6482", "00" & x"6cb5",
    "00" & x"74de", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"7cfb", "00" & x"850b", "00" & x"8d0f", "00" & x"9504",
    "00" & x"9ceb", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"a4c3", "00" & x"ac8a", "00" & x"b440", "00" & x"bbe4",
    "00" & x"c376", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"caf4", "00" & x"d25f", "00" & x"d9b5", "00" & x"e0f5",
    "00" & x"e81f", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"ef32", "00" & x"f62d", "00" & x"fd11", "01" & x"03db",
    "01" & x"0a8b", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"1122", "01" & x"179d", "01" & x"1dfd", "01" & x"2440",
    "01" & x"2a67", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"3070", "01" & x"365b", "01" & x"3c28", "01" & x"41d5",
    "01" & x"4762", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"4cd0", "01" & x"521c", "01" & x"5747", "01" & x"5c50",
    "01" & x"6137", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"65fb", "01" & x"6a9b", "01" & x"6f18", "01" & x"7371",
    "01" & x"77a5", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"7bb4", "01" & x"7f9d", "01" & x"8360", "01" & x"86fe",
    "01" & x"8a74", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"8dc4", "01" & x"90ed", "01" & x"93ee", "01" & x"96c7",
    "01" & x"9978", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"9c00", "01" & x"9e60", "01" & x"a097", "01" & x"a2a5",
    "01" & x"a489", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"a644", "01" & x"a7d6", "01" & x"a93d", "01" & x"aa7b",
    "01" & x"ab8e", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"ac77", "01" & x"ad36", "01" & x"adcb", "01" & x"ae35",
    "01" & x"ae75", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    -- Scale = 131072.
    "10" & x"0000", "10" & x"0019", "10" & x"0065", "10" & x"00e3",
    "10" & x"0194", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"0277", "10" & x"038d", "10" & x"04d4", "10" & x"064e",
    "10" & x"07f9", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"09d7", "10" & x"0be5", "10" & x"0e26", "10" & x"1097",
    "10" & x"1339", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"160c", "10" & x"190f", "10" & x"1c42", "10" & x"1fa5",
    "10" & x"2338", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"26f9", "10" & x"2ae9", "10" & x"2f08", "10" & x"3354",
    "10" & x"37ce", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"3c75", "10" & x"4148", "10" & x"4648", "10" & x"4b73",
    "10" & x"50c9", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"564a", "10" & x"5bf4", "10" & x"61c9", "10" & x"67c6",
    "10" & x"6deb", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"7438", "10" & x"7aac", "10" & x"8147", "10" & x"8807",
    "10" & x"8eec", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"95f6", "10" & x"9d24", "10" & x"a474", "10" & x"abe7",
    "10" & x"b37c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"bb31", "10" & x"c306", "10" & x"cafb", "10" & x"d30e",
    "10" & x"db3f", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "10" & x"e38c", "10" & x"ebf6", "10" & x"f47b", "10" & x"fd1a",
    "11" & x"05d3", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"0ea5", "11" & x"178f", "11" & x"208f", "11" & x"29a5",
    "11" & x"32d1", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"3c11", "11" & x"4564", "11" & x"4eca", "11" & x"5841",
    "11" & x"61c9", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"6b60", "11" & x"7506", "11" & x"7eb9", "11" & x"887a",
    "11" & x"9246", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"9c1d", "11" & x"a5fe", "11" & x"afe8", "11" & x"b9da",
    "11" & x"c3d2", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "11" & x"cdd1", "11" & x"d7d4", "11" & x"e1dc", "11" & x"ebe6",
    "11" & x"f5f3", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"0000", "00" & x"0a0d", "00" & x"141a", "00" & x"1e24",
    "00" & x"282c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"322f", "00" & x"3c2e", "00" & x"4626", "00" & x"5018",
    "00" & x"5a02", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"63e3", "00" & x"6dba", "00" & x"7786", "00" & x"8147",
    "00" & x"8afa", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"94a0", "00" & x"9e37", "00" & x"a7bf", "00" & x"b136",
    "00" & x"ba9c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"c3ef", "00" & x"cd2f", "00" & x"d65b", "00" & x"df71",
    "00" & x"e871", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "00" & x"f15b", "00" & x"fa2d", "01" & x"02e6", "01" & x"0b85",
    "01" & x"140a", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"1c74", "01" & x"24c1", "01" & x"2cf2", "01" & x"3505",
    "01" & x"3cfa", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"44cf", "01" & x"4c84", "01" & x"5419", "01" & x"5b8c",
    "01" & x"62dc", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"6a0a", "01" & x"7114", "01" & x"77f9", "01" & x"7eb9",
    "01" & x"8554", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"8bc8", "01" & x"9215", "01" & x"983a", "01" & x"9e37",
    "01" & x"a40c", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"a9b6", "01" & x"af37", "01" & x"b48d", "01" & x"b9b8",
    "01" & x"beb8", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"c38b", "01" & x"c832", "01" & x"ccac", "01" & x"d0f8",
    "01" & x"d517", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"d907", "01" & x"dcc8", "01" & x"e05b", "01" & x"e3be",
    "01" & x"e6f1", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"e9f4", "01" & x"ecc7", "01" & x"ef69", "01" & x"f1da",
    "01" & x"f41b", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"f629", "01" & x"f807", "01" & x"f9b2", "01" & x"fb2c",
    "01" & x"fc73", "00" & x"0000", "00" & x"0000", "00" & x"0000",
    "01" & x"fd89", "01" & x"fe6c", "01" & x"ff1d", "01" & x"ff9b",
    "01" & x"ffe7", "00" & x"0000", "00" & x"0000", "00" & x"0000"
    );

begin
  process
    variable shift0_r : signed(diffw + 11 downto 0);
    variable shift0_i : signed(diffw + 11 downto 0);
  begin
    wait until rising_edge(clk);

    if state = state_max then
      state <= 0;
    else
      state <= state + 1;
    end if;

    phase <= addmod320(phase, '0' & freq);

    -- We actually use -cos(phase) + i sin(phase).
    cos <= cos_table(to_integer(table_select & phase(7 downto 0)));
    sin <= cos_table(to_integer(table_select & phase(7 downto 0)
                                xor "0010000000"));
    cos_neg <= phase(8) = '1';
    sin_neg <= phase(8) /= phase(7);

    if shift(2) = '1' then
      adc_r0 <= adc_data & "0000";
      adc_i0 <= adc_data & "0000";
    else
      adc_r0 <= (others => adc_data(13));
      adc_i0 <= (others => adc_data(13));
      adc_r0(13 downto 0) <= adc_data;
      adc_i0(13 downto 0) <= adc_data;
    end if;

    cos_1 <= cos;
    sin_1 <= sin;
    cos_neg_1 <= cos_neg;
    sin_neg_1 <= sin_neg;

    prod_r <= adc_r0 * cos_1;
    prod_i <= adc_i0 * sin_1;
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
    acc2_r <= acc2_r + acc1_r(width1 downto width1 - width2);
    acc2_i <= acc2_i + acc1_i(width1 downto width1 - width2);
    acc3_r <= acc3_r + acc2_r(width2 downto width2 - width3);
    acc3_i <= acc3_i + acc2_i(width2 downto width2 - width3);
    acc4_r <= acc4_r + acc3_r(width3 downto width3 - width4);
    acc4_i <= acc4_i + acc3_i(width3 downto width3 - width4);
    acc5_r <= acc5_r + acc4_r(width4 downto width4 - width5);
    acc5_i <= acc5_i + acc4_i(width4 downto width4 - width5);

    -- Do the left shift here, leaving us with a 32 bit word into the
    -- differencing.
    shift0_r(diffw + 11 downto 0) := acc5_r(width5 downto width5 - diffw - 11);
    shift0_i(diffw + 11 downto 0) := acc5_i(width5 downto width5 - diffw - 11);
    if shift(3) = '1' then
      shift1_r <= shift0_r(diffw + 3 downto 0);
      shift1_i <= shift0_i(diffw + 3 downto 0);
    else
      shift1_r <= shift0_r(diffw + 11 downto 8);
      shift1_i <= shift0_i(diffw + 11 downto 8);
    end if;
    case shift(1 downto 0) is
      when "11" => shift2_r <= shift1_r(diffw downto 0);
                   shift2_i <= shift1_i(diffw downto 0);
      when "10" => shift2_r <= shift1_r(diffw + 1 downto 1);
                   shift2_i <= shift1_i(diffw + 1 downto 1);
      when "01" => shift2_r <= shift1_r(diffw + 2 downto 2);
                   shift2_i <= shift1_i(diffw + 2 downto 2);
      when others => shift2_r <= shift1_r(diffw + 3 downto 3);
                     shift2_i <= shift1_i(diffw + 3 downto 3);
    end case;

    for i in 0 to 5 loop
      op(i) <= op_pass;
    end loop;
    case state is
      when  0 => op(2) <= op_add; -- 160 = 2*80 + 0 = 21 +65 +74
      when  6 => op(1) <= op_add; --  86 = 1*80 + 6 = 21 +65
      when  7 => op(3) <= op_add; -- 247 = 3*80 + 7 = 21 +65 +74 +87
      when 13 => op(2) <= op_add; -- 173 = 2*80 +13 = 21 +65 +87
      when 15 => op(1) <= op_add; --  95 = 1*80 +15 = 21 +74
      when 19 => op(3) <= op_add; -- 259 = 3*80 +19 = 21 +65 +74 +99
      when 21 => op(0) <= op_add; --  21 = 0*80 +21 = 21
      when 22 => op(2) <= op_add; -- 182 = 2*80 +22 = 21 +74 +87
      when 25 => op(2) <= op_add; -- 185 = 2*80 +25 = 21 +65 +99
      when 26 => op(3) <= op_add; -- 266 = 3*80 +26 = 21 +65 +74 +106
                 op(4) <= op_add; -- 346 = 4*80 +26 = 21 +65 +74 +87 +99
      when 28 => op(1) <= op_add; -- 108 = 1*80 +28 = 21 +87
      when 32 => op(2) <= op_add; -- 192 = 2*80 +32 = 21 +65 +106
                 op(3) <= op_add; -- 272 = 3*80 +32 = 21 +65 +87 +99
      when 33 => op(4) <= op_add; -- 353 = 4*80 +33 = 21 +65 +74 +87 +106
      when 34 => op(2) <= op_add; -- 194 = 2*80 +34 = 21 +74 +99
      when 39 => op(3) <= op_add; -- 279 = 3*80 +39 = 21 +65 +87 +106
      when 40 => op(1) <= op_add; -- 120 = 1*80 +40 = 21 +99
      when 41 => op(2) <= op_add; -- 201 = 2*80 +41 = 21 +74 +106
                 op(3) <= op_add; -- 281 = 3*80 +41 = 21 +74 +87 +99
      when 45 => op(4) <= op_add; -- 365 = 4*80 +45 = 21 +65 +74 +99 +106
      when 47 => op(1) <= op_add; -- 127 = 1*80 +47 = 21 +106
                 op(2) <= op_add; -- 207 = 2*80 +47 = 21 +87 +99
      when 48 => op(3) <= op_add; -- 288 = 3*80 +48 = 21 +74 +87 +106
      when 51 => op(3) <= op_add; -- 291 = 3*80 +51 = 21 +65 +99 +106
      when 52 => op(5) <= op_add; -- 452 = 5*80 +52 = 21 +65 +74 +87 +99 +106
      when 54 => op(2) <= op_add; -- 214 = 2*80 +54 = 21 +87 +106
      when 58 => op(4) <= op_add; -- 378 = 4*80 +58 = 21 +65 +87 +99 +106
      when 60 => op(3) <= op_add; -- 300 = 3*80 +60 = 21 +74 +99 +106
      when 66 => op(2) <= op_add; -- 226 = 2*80 +66 = 21 +99 +106
      when 67 => op(4) <= op_add; -- 387 = 4*80 +67 = 21 +74 +87 +99 +106
      when 73 => op(3) <= op_add; -- 313 = 3*80 +73 = 21 +87 +99 +106
      when 78 =>
        for i in 0 to 5 loop
          op(i) <= op_shift;
        end loop;
      when others =>
    end case;

    op1 <= op;

    if op1(0)(1) = '1' then
      flt_r(0) <= shift_or_add(flt_r(0), zero, shift2_r, op1(0), 0);
      flt_i(0) <= shift_or_add(flt_i(0), zero, shift2_i, op1(0), 0);
    end if;
    for i in 1 to 5 loop
      if op1(i)(1) = '1' then
        flt_r(i) <= shift_or_add(flt_r(i), flt_r(i-1), shift2_r, op1(i), i);
        flt_i(i) <= shift_or_add(flt_i(i), flt_i(i-1), shift2_i, op1(i), i);
      end if;
    end loop;

    strobe <= '0';
    if state = 79 then
      strobe <= '1';
      out_r <= flt_r(5)(diffw downto diffw - 14);
      out_i <= flt_i(5)(diffw downto diffw - 14);
    end if;
  end process;

end sample30;
