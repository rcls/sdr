library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;
use work.sincos.all;

entity quadcheby is
  port (D : in mf_signed;
        Q : out signed36;
        last_in : in std_logic;
        last_out : out std_logic;
        clk : in std_logic);
end quadcheby;

architecture quadcheby of quadcheby is
  -- We implement:
  -- d/dt U = - D - alpha U - beta I
  -- d/dt I = U + V
  -- d/dt V = - alpha V - beta I
  -- Q = 2 alpha V

  -- Letting A = U+V, we have
  -- d/dt I = A,
  -- d/dt A = -D - alpha A - 2 beta I
  -- (d/dt)^2 A + alpha d/dt A + 2 beta A + d/dt D = 0.

  -- Letting B = U - V, we have
  -- d/dt B = -D - alpha B

  -- In s-domain,
  -- A = -s / (s^2 + alpha s + 2 beta) D
  -- B = -1 / (s + alpha) D
  -- Q = alpha(A - B) = alpha [ 1/(s+alpha) - s/(s^2 + alpha s + 2beta)] D
  -- = 2 alpha beta / (s + alpha)(s^2 + alpha s + 2 beta) D

  -- For reference:
  -- V = beta / (s + alpha)(s^2 + alpha s + 2 beta) D

  -- U = (A + B)/2 = [ 1/(s + alpha) + s/(s^2 + alpha s + 2beta ] D / 2
  -- = D (s^2 + alpha s + beta) / (s+alpha)(s^2 + alpha s + 2 beta)
  -- = D [1 - beta / (s + alpha s + 2 beta)] / (s + alpha)

  -- I = -1 / (s^2 + alpha s + 2 beta) D

  -- We have 4 channels TDMd over 16 cycles.

  -- We want an overall bandwidth of around 200kHz = 1/1250 f_clk.
  -- With beta=4alpha^2, the bandwidth is about pi*alpha rads/clk
  -- = alpha/2 f_clk.
  -- Remembering that f_clk is 250MHz / 16, take alpha = 1/32.

  constant alpha_b : integer := 5;

  -- Split beta into two parts; one applied going into I, one coming out.
  constant beta1_b : integer := alpha_b;
  constant beta2_b : integer := alpha_b - 1;

  constant iwidth : integer := maximum(37, mf_width + alpha_b);
  constant itop : integer := iwidth - alpha_b;
  subtype acc_t is signed(iwidth - 1 downto 0);

  signal U, U_a, U_b, U_c, U_d : acc_t := (others => '0');
  signal V, V_a, V_b, V_c, V_d : acc_t := (others => '0');
  signal I, I_a, I_b, I_c, I_d : acc_t := (others => '0');

  signal Uaddend : acc_t := (others => '0');
  signal Uc, Vc, Ic : std_logic := '0';

  signal phase : unsigned2 := "00";
  signal strobe0 : std_logic := '1';
  signal strobe1 : std_logic := '0';

  attribute keep_hierarchy : string;
  attribute keep_hierarchy of quadcheby : architecture is "soft";

begin
  process
    variable U1, U2, V2, I2 : acc_t;
  begin
    wait until rising_edge(clk);
    strobe0 <= phase(0) and phase(1);
    strobe1 <= strobe0;
    if strobe0 = '1' then
      V_a <= V;
      V_b <= V_a;
      V_c <= V_b;
      V_d <= V_c;
      I_a <= I;
      I_b <= I_a;
      I_c <= I_b;
      I_d <= I_c;
      U_a <= U;
      U_b <= U_a;
      U_c <= U_b;
      U_d <= U_c;
    end if;

    case phase is
      when "01" =>
        Uaddend <= resize(U_d(iwidth - 1 downto alpha_b), iwidth);
        Uc <= not U_d(alpha_b - 1);
      when "10" =>
        Uaddend <= resize(I_d(iwidth - 1 downto beta2_b), iwidth);
        Uc <= not I_d(beta2_b - 1);
      when others =>
        Uaddend <= (others => 'X');
        Uc <= '1';
    end case;

    if strobe1 = '1' then
      U1 := U_d;
      U2 := resize(D, iwidth) sll (itop - mf_width);
      last_out <= last_in;
      Q <= V_d(itop + alpha_b - 2 downto itop + alpha_b - 37);
    else
      U1 := U;
      U2 := Uaddend;
    end if;
    U <= U1 + (not U2) + ("0" & Uc);

    if phase = "01" then
      Vc <= not V_d(alpha_b - 1);
      Ic <= U_d(beta1_b - 1);
    elsif phase = "10" then
      Vc <= not I_d(beta2_b - 1);
      Ic <= V_d(beta1_b - 1);
    else
      Vc <= '0';
      Ic <= '0';
    end if;

    case phase is
      when "10" =>
        V2 := not resize(V_d(iwidth - 1 downto alpha_b), iwidth);
        I2 := resize(U_d(iwidth - 1 downto beta1_b), iwidth);
      when "11" =>
        V2 := not resize(I_d(iwidth - 1 downto beta2_b), iwidth);
        I2 := resize(V_d(iwidth - 1 downto beta1_b), iwidth);
      when others =>
        V2 := V_d;
        I2 := I_d;
    end case;
    V <= V + V2 + ("0" & Vc);
    I <= I + I2 + ("0" & Ic);
    if strobe0 = '1' then
      V <= (others => '0');
      I <= (others => '0');
    end if;

    phase <= phase + 1;
  end process;
end quadcheby;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity test_quadcheby is
  port (clk : out std_logic;
        Q : out signed(35 downto 0);
        last_out : out std_logic);
end test_quadcheby;

architecture test_quadcheby of test_quadcheby is
  signal clk_main : std_logic := '0';
  signal count : unsigned(10 downto 0) := (others => '0');
  signal D : mf_signed := (others => '0');
  signal last_in : std_logic := '0';
begin

  uut : entity work.quadcheby port map(D, Q, last_in, last_out, clk_main);
  clk <= clk_main;

  process
  begin
    wait for 2ns;
    clk_main <= not clk_main;
  end process;

  process(clk_main)
  begin
    if clk_main'event and clk_main = '1' then
      count <= count + 1;
      if count(1 downto 0) = "00" then
        last_in <= '0';
        --D <= (others => '0');
      end if;
      if count(3 downto 0) = "1100" then
        last_in <= '1';
      end if;
      if count(3 downto 0) = "0000" then
        if count(10) = '1' then
          D <= to_signed(262144, mf_width);
        else
          D <= to_signed(-262144, mf_width);
        end if;
      end if;
    end if;
  end process;
end test_quadcheby;
