library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.defs.all;

entity sample is
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
end sample;

architecture Behavioral of sample is

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

--  signal phase : unsigned(3 downto 0) := x"0";
  constant phase_max : integer := 14;
  signal phase : integer range 0 to phase_max;

  signal usb_d_out : unsigned8;
  signal usb_oe : boolean := false;
  signal usb_rdn : boolean := false;
  signal capture : boolean := false; -- Process data from USB.

  signal sample : boolean;

  attribute S : string;
  attribute S of led : signal is "yes";
--  attribute S of usb_c : signal is "yes";

  signal div25 : unsigned(24 downto 0);

  alias full : std_logic is led_on(3);
  alias empty : std_logic is led_on(4);
  alias capture_hi : std_logic is led_on(5);
--  signal full_stretch : boolean;

  -- Poly is 0x100802041
  signal lfsr : std_logic_vector(31 downto 0) := x"00000001";

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
  --usb_nRD <= usb_rdn;

  usb_c(7 downto 5) <= "ZZZ";
  clkin125_en <= '1';

  usb_d <= usb_d_out when usb_oe else "ZZZZZZZZ";

  led_control: for i in 0 to 7 generate
    led(i) <= '0' when led_on(i) = '1' else 'Z';
  end generate;
  led_on(2) <= div25(24);

  -- We run on a period of 100ns, from a sample rate of 100MHz.  We output the
  -- 7 low bits of the ADC, and an LFSR generated bit.
  process (clk_main)
    variable div25_inc : unsigned(25 downto 0);
  begin
    if clk_main'event and clk_main = '1' then
      div25_inc := ('0' & div25) + 1;
      div25 <= div25_inc(24 downto 0);

      if phase = phase_max then
        phase <= 0;
        sample <= true;
      else
        phase <= phase + 1;
        sample <= false;
      end if;

      if sample then -- phase = 0
        if capture_hi = '1' then
          usb_d_out <= lfsr(0) & adc_data(13 downto 7);
        else
          usb_d_out <= lfsr(0) & adc_data(6 downto 0);
        end if;

        lfsr <= lfsr(30 downto 0) & (
          lfsr(31) xor lfsr(22) xor lfsr(12) xor lfsr(5));

        usb_rdn <= USB_nRXF = '0';
      end if;
      if sample and usb_nTXE = '0' then
        empty <= '1';
      elsif div25_inc(25) = '1' then
        empty <= '0';
      end if;
      if sample and usb_nTXE = '1' then
        full <= '1';
      elsif div25_inc(25) = '1' then
        full <= '0';
      end if;

      usb_oe <= false;
      usb_nWR <= '1';
      usb_nRD <= '1';
      if usb_rdn then
        case phase is
          when 1|2|3|4|5|6|7 =>
            usb_nRD <= '0';
          when 8 =>
            if usb_rdn then
              adc_sen <= usb_d(0);
              adc_sdata <= usb_d(1);
              adc_sclk <= usb_d(2);
              adc_reset <= usb_d(3);
              capture_hi <= usb_d(4);
            end if;
          when others =>
        end case;
      else
        case phase is
          when 1|2 =>
            usb_oe <= true;
          when 3|4 =>
            usb_nWR <= '0';
            usb_oe <= true;
          when 5|6|7|8|9 =>
            usb_nWR <= '0';
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
      --CLKIN_PERIOD         => 4.571428,
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
