-- Conf registers from the SPI port.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.defs.all;

entity spiconf is
  generic (config_bytes : integer := 2;
           data_bytes : integer := 2;
           defconfig : unsigned);
  port (spi_ss, spi_in : in std_logic;
        spi_out : out std_logic;
        spi_clk : in std_logic;
        spi_ss_fast, spi_in_fast : in std_logic;
        data : in unsigned(data_bytes * 8 - 1 downto 0);
        data_ack : out unsigned(data_bytes - 1 downto 0);
        config : out unsigned(config_bytes * 8 - 1 downto 0) := defconfig;
        config_strobe : out unsigned(config_bytes - 1 downto 0);
        clk : in std_logic);
end spiconf;

architecture spiconf of spiconf is
  signal bit_count : unsigned(3 downto 0);
  signal shift_in : unsigned(14 downto 0);

  signal shift_out : unsigned8;
  signal spi_clk2 : std_logic;

  signal write_strobe : unsigned(config_bytes - 1 downto 0);

  signal tdi : std_logic;
  signal drck, drck2, drck3, idle : std_logic := '1';
begin
  spi_out <= shift_out(7) when bit_count(3) = '1' else spi_in_fast
             when spi_ss_fast = '0' else idle;

  jtag : bscan_spartan6 port map (drck => drck, tdi => tdi, tdo => idle);

  process
  begin
    wait until rising_edge(clk);

    spi_clk2 <= spi_clk;
    data_ack <= (others => '0');

    -- Rising edge of spi_clk.
    write_strobe <= (others => '0');
    if spi_clk = '1' and spi_clk2 = '0' then
      if bit_count = x"f" and shift_in(7) = '1' then
        for i in 0 to config_bytes - 1 loop
          if shift_in(12 downto 8) = to_unsigned(i, 5) then
            write_strobe(i) <= '1';
          end if;
        end loop;
      end if;
      shift_in <= shift_in(13 downto 0) & spi_in;
      bit_count <= bit_count + 1;

      -- By the time these get out, it'll be well pass the edge...
      shift_out <= shift_out sll 1;
      -- When bit_count=8, we process the read.  Always read, only ack if asked.
      if bit_count = x"7" then
        shift_out <= "XXXXXXXX";
        for i in 0 to data_bytes - 1 loop
          if shift_in(5 downto 0) = to_unsigned(i, 6) then
            shift_out <= data(i * 8 + 7 downto i * 8);
            if spi_in = '0' then
              data_ack(i) <= '1';
            end if;
          end if;
        end loop;
      end if;
    end if;

    -- Process writes.
    config_strobe <= write_strobe;
    for i in 0 to config_bytes - 1 loop
      if write_strobe(i) = '1' then
        config(i * 8 + 7 downto i * 8) <= shift_in(7 downto 0);
      end if;
    end loop;

    if spi_ss = '1' then
      bit_count <= x"0";
    end if;

    drck2 <= drck;
    drck3 <= drck2;
    if drck2 = '1' and drck3 = '0' then
      idle <= tdi;
    end if;
  end process;
end spiconf;
