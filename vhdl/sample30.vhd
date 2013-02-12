-- Filter given by a fifth order polynomial:
-- plot 10 * log ((sin(x*pi*65/80) * sin(x*pi*74/80) * sin(x*pi*87/80) * sin(x*pi*99/80) * sin(x*pi*106/80) * 80 * 80 * 80 * 80 * 80 / 65 / 74 / 87 / 99 / 106 / pi / pi / pi / pi / pi / x / x / x / x / x)**2) /log(10)

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

  alias enable : std_logic is gain(7);

  -- Accumulator widths minus one...
  constant width1 : integer := 52;
  constant width2 : integer := 39;
  constant width3 : integer := 30;
  constant width4 : integer := 22;
  constant width5 : integer := 14;

  -- Differencer width minus one...
  constant diffw : integer := 14;

  -- Type used for arithmetic in the differencers.
  subtype wordd is signed(diffw downto 0);
  type wordd_array is array (natural range <>) of wordd;
  constant zero : wordd := (others => '0');

  signal cos, sin, cos_1, sin_1, cos_2, sin_2 : signed16;

  signal cos_neg : boolean;
  signal sin_neg : boolean;
  signal cos_neg_1 : boolean;
  signal sin_neg_1 : boolean;
  signal cos_neg_2 : boolean;
  signal sin_neg_2 : boolean;
  signal cos_neg_3 : boolean;
  signal sin_neg_3 : boolean;
  signal cos_neg_4 : boolean;
  signal sin_neg_4 : boolean;

  signal adc_r0 : signed18;
  signal adc_i0 : signed18;

  constant wprod : integer := 33;
  signal prod_r : signed(wprod downto 0);
  signal prod_i : signed(wprod downto 0);
  signal prod1_r : signed(wprod downto 0);
  signal prod1_i : signed(wprod downto 0);

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
  type signed16_array is array (natural range <>) of signed16;
  signal cos_table : signed16_array(0 to 1023) := (
    -- Scale = 19484.
    x"b3e4", x"b3e8", x"b3f3", x"b406",  x"b420", x"0000", x"0000", x"0000",
    x"b442", x"b46b", x"b49c", x"b4d4",  x"b513", x"0000", x"0000", x"0000",
    x"b55a", x"b5a9", x"b5fe", x"b65b",  x"b6c0", x"0000", x"0000", x"0000",
    x"b72b", x"b79e", x"b817", x"b898",  x"b920", x"0000", x"0000", x"0000",
    x"b9af", x"ba45", x"bae2", x"bb85",  x"bc30", x"0000", x"0000", x"0000",
    x"bce1", x"bd98", x"be57", x"bf1b",  x"bfe6", x"0000", x"0000", x"0000",
    x"c0b8", x"c18f", x"c26d", x"c351",  x"c43b", x"0000", x"0000", x"0000",
    x"c52b", x"c620", x"c71c", x"c81c",  x"c923", x"0000", x"0000", x"0000",
    x"ca2f", x"cb40", x"cc56", x"cd72",  x"ce92", x"0000", x"0000", x"0000",
    x"cfb8", x"d0e2", x"d210", x"d344",  x"d47b", x"0000", x"0000", x"0000",
    x"d5b7", x"d6f7", x"d83c", x"d984",  x"dad0", x"0000", x"0000", x"0000",
    x"dc1f", x"dd72", x"dec9", x"e023",  x"e180", x"0000", x"0000", x"0000",
    x"e2e0", x"e443", x"e5a8", x"e710",  x"e87b", x"0000", x"0000", x"0000",
    x"e9e8", x"eb57", x"ecc8", x"ee3c",  x"efb0", x"0000", x"0000", x"0000",
    x"f127", x"f29f", x"f418", x"f592",  x"f70e", x"0000", x"0000", x"0000",
    x"f88a", x"fa07", x"fb85", x"fd03",  x"fe81", x"0000", x"0000", x"0000",
    x"0000", x"017f", x"02fd", x"047b",  x"05f9", x"0000", x"0000", x"0000",
    x"0776", x"08f2", x"0a6e", x"0be8",  x"0d61", x"0000", x"0000", x"0000",
    x"0ed9", x"1050", x"11c4", x"1338",  x"14a9", x"0000", x"0000", x"0000",
    x"1618", x"1785", x"18f0", x"1a58",  x"1bbd", x"0000", x"0000", x"0000",
    x"1d20", x"1e80", x"1fdd", x"2137",  x"228e", x"0000", x"0000", x"0000",
    x"23e1", x"2530", x"267c", x"27c4",  x"2909", x"0000", x"0000", x"0000",
    x"2a49", x"2b85", x"2cbc", x"2df0",  x"2f1e", x"0000", x"0000", x"0000",
    x"3048", x"316e", x"328e", x"33aa",  x"34c0", x"0000", x"0000", x"0000",
    x"35d1", x"36dd", x"37e4", x"38e4",  x"39e0", x"0000", x"0000", x"0000",
    x"3ad5", x"3bc5", x"3caf", x"3d93",  x"3e71", x"0000", x"0000", x"0000",
    x"3f48", x"401a", x"40e5", x"41a9",  x"4268", x"0000", x"0000", x"0000",
    x"431f", x"43d0", x"447b", x"451e",  x"45bb", x"0000", x"0000", x"0000",
    x"4651", x"46e0", x"4768", x"47e9",  x"4862", x"0000", x"0000", x"0000",
    x"48d5", x"4940", x"49a5", x"4a02",  x"4a57", x"0000", x"0000", x"0000",
    x"4aa6", x"4aed", x"4b2c", x"4b64",  x"4b95", x"0000", x"0000", x"0000",
    x"4bbe", x"4be0", x"4bfa", x"4c0d",  x"4c18", x"0000", x"0000", x"0000",
    -- Scale = 23170.5.
    x"a57e", x"a582", x"a58f", x"a5a6",  x"a5c5", x"0000", x"0000", x"0000",
    x"a5ed", x"a61e", x"a658", x"a69b",  x"a6e6", x"0000", x"0000", x"0000",
    x"a73b", x"a798", x"a7fe", x"a86c",  x"a8e3", x"0000", x"0000", x"0000",
    x"a963", x"a9ec", x"aa7c", x"ab16",  x"abb7", x"0000", x"0000", x"0000",
    x"ac61", x"ad13", x"adce", x"ae90",  x"af5b", x"0000", x"0000", x"0000",
    x"b02d", x"b108", x"b1ea", x"b2d4",  x"b3c5", x"0000", x"0000", x"0000",
    x"b4be", x"b5bf", x"b6c7", x"b7d6",  x"b8ec", x"0000", x"0000", x"0000",
    x"ba09", x"bb2d", x"bc58", x"bd89",  x"bec1", x"0000", x"0000", x"0000",
    x"c000", x"c145", x"c290", x"c3e1",  x"c538", x"0000", x"0000", x"0000",
    x"c695", x"c7f7", x"c95f", x"cacd",  x"cc3f", x"0000", x"0000", x"0000",
    x"cdb7", x"cf34", x"d0b5", x"d23c",  x"d3c6", x"0000", x"0000", x"0000",
    x"d556", x"d6e9", x"d880", x"da1b",  x"dbba", x"0000", x"0000", x"0000",
    x"dd5d", x"df03", x"e0ac", x"e259",  x"e408", x"0000", x"0000", x"0000",
    x"e5ba", x"e76f", x"e926", x"eadf",  x"ec9a", x"0000", x"0000", x"0000",
    x"ee58", x"f017", x"f1d7", x"f399",  x"f55d", x"0000", x"0000", x"0000",
    x"f721", x"f8e6", x"faac", x"fc72",  x"fe39", x"0000", x"0000", x"0000",
    x"0000", x"01c7", x"038e", x"0554",  x"071a", x"0000", x"0000", x"0000",
    x"08df", x"0aa3", x"0c67", x"0e29",  x"0fe9", x"0000", x"0000", x"0000",
    x"11a8", x"1366", x"1521", x"16da",  x"1891", x"0000", x"0000", x"0000",
    x"1a46", x"1bf8", x"1da7", x"1f54",  x"20fd", x"0000", x"0000", x"0000",
    x"22a3", x"2446", x"25e5", x"2780",  x"2917", x"0000", x"0000", x"0000",
    x"2aaa", x"2c3a", x"2dc4", x"2f4b",  x"30cc", x"0000", x"0000", x"0000",
    x"3249", x"33c1", x"3533", x"36a1",  x"3809", x"0000", x"0000", x"0000",
    x"396b", x"3ac8", x"3c1f", x"3d70",  x"3ebb", x"0000", x"0000", x"0000",
    x"4000", x"413f", x"4277", x"43a8",  x"44d3", x"0000", x"0000", x"0000",
    x"45f7", x"4714", x"482a", x"4939",  x"4a41", x"0000", x"0000", x"0000",
    x"4b42", x"4c3b", x"4d2c", x"4e16",  x"4ef8", x"0000", x"0000", x"0000",
    x"4fd3", x"50a5", x"5170", x"5232",  x"52ed", x"0000", x"0000", x"0000",
    x"539f", x"5449", x"54ea", x"5584",  x"5614", x"0000", x"0000", x"0000",
    x"569d", x"571d", x"5794", x"5802",  x"5868", x"0000", x"0000", x"0000",
    x"58c5", x"591a", x"5965", x"59a8",  x"59e2", x"0000", x"0000", x"0000",
    x"5a13", x"5a3b", x"5a5a", x"5a71",  x"5a7e", x"0000", x"0000", x"0000",
    -- Scale = 27554.5.
    x"945e", x"9463", x"9473", x"948d",  x"94b2", x"0000", x"0000", x"0000",
    x"94e2", x"951d", x"9561", x"95b1",  x"960b", x"0000", x"0000", x"0000",
    x"966f", x"96de", x"9757", x"97da",  x"9868", x"0000", x"0000", x"0000",
    x"9900", x"99a2", x"9a4e", x"9b05",  x"9bc5", x"0000", x"0000", x"0000",
    x"9c8f", x"9d63", x"9e41", x"9f28",  x"a019", x"0000", x"0000", x"0000",
    x"a113", x"a217", x"a324", x"a43a",  x"a559", x"0000", x"0000", x"0000",
    x"a681", x"a7b2", x"a8ec", x"aa2e",  x"ab79", x"0000", x"0000", x"0000",
    x"accc", x"ae27", x"af8b", x"b0f6",  x"b269", x"0000", x"0000", x"0000",
    x"b3e4", x"b566", x"b6f0", x"b881",  x"ba19", x"0000", x"0000", x"0000",
    x"bbb8", x"bd5d", x"bf09", x"c0bc",  x"c275", x"0000", x"0000", x"0000",
    x"c434", x"c5f8", x"c7c3", x"c993",  x"cb68", x"0000", x"0000", x"0000",
    x"cd43", x"cf23", x"d107", x"d2f0",  x"d4de", x"0000", x"0000", x"0000",
    x"d6cf", x"d8c5", x"dabf", x"dcbc",  x"debd", x"0000", x"0000", x"0000",
    x"e0c1", x"e2c9", x"e4d3", x"e6e0",  x"e8ef", x"0000", x"0000", x"0000",
    x"eb00", x"ed14", x"ef2a", x"f141",  x"f359", x"0000", x"0000", x"0000",
    x"f573", x"f78e", x"f9aa", x"fbc6",  x"fde3", x"0000", x"0000", x"0000",
    x"0000", x"021d", x"043a", x"0656",  x"0872", x"0000", x"0000", x"0000",
    x"0a8d", x"0ca7", x"0ebf", x"10d6",  x"12ec", x"0000", x"0000", x"0000",
    x"1500", x"1711", x"1920", x"1b2d",  x"1d37", x"0000", x"0000", x"0000",
    x"1f3f", x"2143", x"2344", x"2541",  x"273b", x"0000", x"0000", x"0000",
    x"2931", x"2b22", x"2d10", x"2ef9",  x"30dd", x"0000", x"0000", x"0000",
    x"32bd", x"3498", x"366d", x"383d",  x"3a08", x"0000", x"0000", x"0000",
    x"3bcc", x"3d8b", x"3f44", x"40f7",  x"42a3", x"0000", x"0000", x"0000",
    x"4448", x"45e7", x"477f", x"4910",  x"4a9a", x"0000", x"0000", x"0000",
    x"4c1c", x"4d97", x"4f0a", x"5075",  x"51d9", x"0000", x"0000", x"0000",
    x"5334", x"5487", x"55d2", x"5714",  x"584e", x"0000", x"0000", x"0000",
    x"597f", x"5aa7", x"5bc6", x"5cdc",  x"5de9", x"0000", x"0000", x"0000",
    x"5eed", x"5fe7", x"60d8", x"61bf",  x"629d", x"0000", x"0000", x"0000",
    x"6371", x"643b", x"64fb", x"65b2",  x"665e", x"0000", x"0000", x"0000",
    x"6700", x"6798", x"6826", x"68a9",  x"6922", x"0000", x"0000", x"0000",
    x"6991", x"69f5", x"6a4f", x"6a9f",  x"6ae3", x"0000", x"0000", x"0000",
    x"6b1e", x"6b4e", x"6b73", x"6b8d",  x"6b9d", x"0000", x"0000", x"0000",
    -- Scale = 32768.
    x"8000", x"8006", x"8019", x"8039",  x"8065", x"0000", x"0000", x"0000",
    x"809e", x"80e3", x"8135", x"8193",  x"81fe", x"0000", x"0000", x"0000",
    x"8276", x"82f9", x"8389", x"8426",  x"84ce", x"0000", x"0000", x"0000",
    x"8583", x"8644", x"8711", x"87e9",  x"88ce", x"0000", x"0000", x"0000",
    x"89be", x"8aba", x"8bc2", x"8cd5",  x"8df3", x"0000", x"0000", x"0000",
    x"8f1d", x"9052", x"9192", x"92dd",  x"9432", x"0000", x"0000", x"0000",
    x"9592", x"96fd", x"9872", x"99f1",  x"9b7b", x"0000", x"0000", x"0000",
    x"9d0e", x"9eab", x"a052", x"a202",  x"a3bb", x"0000", x"0000", x"0000",
    x"a57e", x"a749", x"a91d", x"aafa",  x"acdf", x"0000", x"0000", x"0000",
    x"aecc", x"b0c2", x"b2bf", x"b4c3",  x"b6d0", x"0000", x"0000", x"0000",
    x"b8e3", x"bafe", x"bd1f", x"bf47",  x"c175", x"0000", x"0000", x"0000",
    x"c3a9", x"c5e4", x"c824", x"ca69",  x"ccb4", x"0000", x"0000", x"0000",
    x"cf04", x"d159", x"d3b2", x"d610",  x"d872", x"0000", x"0000", x"0000",
    x"dad8", x"dd41", x"dfae", x"e21e",  x"e492", x"0000", x"0000", x"0000",
    x"e707", x"e980", x"ebfa", x"ee76",  x"f0f5", x"0000", x"0000", x"0000",
    x"f374", x"f5f5", x"f877", x"fafa",  x"fd7d", x"0000", x"0000", x"0000",
    x"0000", x"0283", x"0506", x"0789",  x"0a0b", x"0000", x"0000", x"0000",
    x"0c8c", x"0f0b", x"118a", x"1406",  x"1680", x"0000", x"0000", x"0000",
    x"18f9", x"1b6e", x"1de2", x"2052",  x"22bf", x"0000", x"0000", x"0000",
    x"2528", x"278e", x"29f0", x"2c4e",  x"2ea7", x"0000", x"0000", x"0000",
    x"30fc", x"334c", x"3597", x"37dc",  x"3a1c", x"0000", x"0000", x"0000",
    x"3c57", x"3e8b", x"40b9", x"42e1",  x"4502", x"0000", x"0000", x"0000",
    x"471d", x"4930", x"4b3d", x"4d41",  x"4f3e", x"0000", x"0000", x"0000",
    x"5134", x"5321", x"5506", x"56e3",  x"58b7", x"0000", x"0000", x"0000",
    x"5a82", x"5c45", x"5dfe", x"5fae",  x"6155", x"0000", x"0000", x"0000",
    x"62f2", x"6485", x"660f", x"678e",  x"6903", x"0000", x"0000", x"0000",
    x"6a6e", x"6bce", x"6d23", x"6e6e",  x"6fae", x"0000", x"0000", x"0000",
    x"70e3", x"720d", x"732b", x"743e",  x"7546", x"0000", x"0000", x"0000",
    x"7642", x"7732", x"7817", x"78ef",  x"79bc", x"0000", x"0000", x"0000",
    x"7a7d", x"7b32", x"7bda", x"7c77",  x"7d07", x"0000", x"0000", x"0000",
    x"7d8a", x"7e02", x"7e6d", x"7ecb",  x"7f1d", x"0000", x"0000", x"0000",
    x"7f62", x"7f9b", x"7fc7", x"7fe7",  x"7ffa", x"0000", x"0000", x"0000"
    );

begin

  process
  begin
    -- A little bit of logic outside the enable: reseting the state counter
    -- and the output strobe.  This makes sure the strobe does not get stuck
    -- high while we're disabled.
    wait until rising_edge(clk);
    strobe <= '0';
    if state = state_max then
      state <= 0;
      strobe <= '1';
    elsif enable = '1' then
      state <= state + 1;
    end if;
  end process;

  process
    variable sprod_r, sprod_i : signed(wprod downto 0);
    variable shift0_r : signed(diffw + 11 downto 0);
    variable shift0_i : signed(diffw + 11 downto 0);
  begin
    wait until rising_edge(clk) and enable = '1';

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

    cos_2 <= cos_1;
    sin_2 <= sin_1;
    cos_neg_2 <= cos_neg_1;
    sin_neg_2 <= sin_neg_1;

    prod_r <= adc_r0 * cos_2;
    prod_i <= adc_i0 * sin_2;
    cos_neg_3 <= cos_neg_2;
    sin_neg_3 <= sin_neg_2;

    prod1_r <= prod_r;
    prod1_i <= prod_i;
    cos_neg_4 <= cos_neg_3;
    sin_neg_4 <= sin_neg_3;

    if shift(3) = '1' then
      sprod_r := prod1_r;
      sprod_i := prod1_i;
    else
      sprod_r := (others => prod1_r(wprod));
      sprod_i := (others => prod1_i(wprod));
      sprod_r(wprod - 8 downto 0) := prod1_r(wprod downto 8);
      sprod_i(wprod - 8 downto 0) := prod1_i(wprod downto 8);
    end if;

    if cos_neg_4 then
      acc1_r <= acc1_r - sprod_r;
    else
      acc1_r <= acc1_r + sprod_r;
    end if;
    if sin_neg_4 then
      acc1_i <= acc1_i - sprod_i;
    else
      acc1_i <= acc1_i + sprod_i;
    end if;
    acc2_r <= acc2_r + take(acc1_r(width1 downto width1 - width2 - 2),
                            2, shift and x"2");
    acc2_i <= acc2_i + take(acc1_i(width1 downto width1 - width2 - 2),
                            2, shift and x"2");
    acc3_r <= acc3_r + take(acc2_r(width2 downto width2 - width3 - 1),
                            1, shift and x"1");
    acc3_i <= acc3_i + take(acc2_i(width2 downto width2 - width3 - 1),
                            1, shift and x"1");
    acc4_r <= acc4_r + acc3_r(width3 downto width3 - width4);
    acc4_i <= acc4_i + acc3_i(width3 downto width3 - width4);
    acc5_r <= acc5_r + acc4_r(width4 downto width4 - width5);
    acc5_i <= acc5_i + acc4_i(width4 downto width4 - width5);

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
      flt_r(0) <= shift_or_add(flt_r(0), zero, acc5_r, op1(0), 0);
      flt_i(0) <= shift_or_add(flt_i(0), zero, acc5_i, op1(0), 0);
    end if;
    for i in 1 to 5 loop
      if op1(i)(1) = '1' then
        flt_r(i) <= shift_or_add(flt_r(i), flt_r(i-1), acc5_r, op1(i), i);
        flt_i(i) <= shift_or_add(flt_i(i), flt_i(i-1), acc5_i, op1(i), i);
      end if;
    end loop;

    if state = state_max then
      out_r <= flt_r(5)(diffw downto diffw - 14);
      out_i <= flt_i(5)(diffw downto diffw - 14);
    end if;
  end process;

end sample30;
