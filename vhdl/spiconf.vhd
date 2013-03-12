-- Conf registers from the SPI port.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity spiconf is
  generic (config_bytes : integer := 2;
           data_bytes : integer := 2);
  port (spi_ss : in std_logic;
        spi_in : in std_logic;
        spi_out : out std_logic;
        spi_clk : in std_logic;
        data : in unsigned(data_bytes * 8 - 1 downto 0);
        data_ack : out unsigned(data_bytes - 1 downto 0);
        config : out unsigned(config_bytes * 8 - 1 downto 0);
        config_strobe : out unsigned(config_bytes - 1 downto 0);
        clk : in std_logic);
end spiconf;

architecture spiconf of spiconf is
  signal bit_count : unsigned(3 downto 0);
  signal shift_in : unsigned(14 downto 0);

  signal shift_out : unsigned8;
  signal post_rise : boolean;

  signal spi_sss, spi_ins, spi_clks, spi_clks2 : std_logic;
begin
  spi_out <= shift_out(7);

  process
  begin
    wait until rising_edge(clk);

    spi_sss <= spi_ss;
    spi_ins <= spi_in;
    spi_clks <= spi_clk;
    spi_clks2 <= spi_clks;

    -- Rising edge of spi_clk.
    post_rise <= false;
    config_strobe <= (others => '0');
    if spi_clks = '1' and spi_clks2 = '0' then
      if bit_count = x"f" and shift_in(7) = '1' then
        for i in 0 to config_bytes - 1 loop
          if shift_in(12 downto 8) = to_unsigned(i, 5) then
            config(i * 8 + 7 downto i * 8) <= shift_in(6 downto 0) & spi_ins;
            config_strobe(i) <= '1';
          end if;
        end loop;
      end if;
      shift_in <= shift_in(13 downto 0) & spi_ins;
      post_rise <= true;
      bit_count <= bit_count + 1;
    end if;

    data_ack <= (others => '0');
    if post_rise then -- Around about the falling edge.
      shift_out <= shift_out sll 1;
      -- When bit_count=8, we process the read.  Always read, only ack if asked.
      if bit_count = x"8" then
        for i in 0 to data_bytes - 1 loop
          if shift_in(5 downto 1) = to_unsigned(i, 5) then
            shift_out <= data(i * 8 + 7 downto i * 8);
            if shift_in(0) = '0' then
              data_ack(i) <= '1';
            end if;
          end if;
        end loop;
      end if;
    end if;

    if spi_sss = '1' then
      bit_count <= x"0";
    end if;
  end process;
end spiconf;
