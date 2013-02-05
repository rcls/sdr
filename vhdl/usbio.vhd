library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

-- We run off a 12.5mhz clock, transferring 1 byte every 4 cycles.  This gives
-- us a 3.125MB/s transfer rate, which should be comfortably within the ability
-- of the FT2232H async I/O.
-- xmit strobes data in [subject to dead time] on clocks that are a multiple
-- of 4.
-- tx_overrun is asserted if xmit does not writes a block.
-- it is cleared when xmit takes effected.
entity usbio is
  generic (config_bytes : integer;
           packet_bytes : integer;
           defconfig : unsigned := "0");
  port (usbd_in : in unsigned8;
        usbd_out : out unsigned8;
        usb_oe_n : out std_logic := '1';

        usb_nRXF : in std_logic;
        usb_nTXE : in std_logic;
        usb_nRD : out std_logic := '1';
        usb_nWR : out std_logic := '1';

        config : out unsigned(config_bytes * 8 - 1 downto 0) := resize(
          defconfig, config_bytes * 8);

        packet : in unsigned(packet_bytes * 8 - 1 downto 0);
        xmit : in std_logic; -- toggle to xmit.
        tx_overrun : out std_logic;

        clk : in std_logic);
end usbio;

architecture usbio of usbio is
  type state_t is (state_idle, state_write, state_pause);
  signal state : state_t := state_idle;
  signal config_strobes : std_logic_vector(31 downto 0) := (others => '0');
  signal config_address : unsigned8;

  signal xmit_prev : std_logic;
  signal xmit_buffer : unsigned(packet_bytes * 8 - 1 downto 0);
  signal xmit_buffered : std_logic := '0';
  signal xmit_queue : unsigned(packet_bytes * 8 - 1 downto 0);
  signal to_xmit : integer range 0 to packet_bytes := 0;
begin
  process
  begin
    wait until rising_edge(clk);

    usb_nRD <= '1';
    usb_nWR <= '1';
    usb_oe_n <= '1';
    state <= state_idle;
    config_strobes <= (others => '0');
    usbd_out <= xmit_queue(7 downto 0);

    for i in 0 to config_bytes - 1 loop
      if config_strobes(i) = '1' then
        config(i * 8 + 7 downto i * 8) <= usbd_in;
      end if;
    end loop;
    if config_strobes(31) = '1' then
      config_address <= usbd_in;
    end if;

    -- If we're in state idle, decide what to do next.  Prefer reads over
    -- writes.
    if state = state_idle then
      if usb_nRXF = '0' then
        state <= state_pause;
        usb_nRD <= '0';
        config_strobes(to_integer(config_address(4 downto 0))) <= '1';
        config_address <= x"ff";
      elsif usb_nTXE = '0' and to_xmit /= 0 then
        state <= state_write;
        usb_oe_n <= '0';
      end if;
    end if;

    if state = state_write then
      usb_oe_n <= '0';
      state <= state_pause;
      to_xmit <= to_xmit - 1;
      xmit_queue(packet_bytes * 8 - 9 downto 0)
        <= xmit_queue(packet_bytes * 8 - 1 downto 8);
      xmit_queue(packet_bytes * 8 - 1 downto packet_bytes * 8 - 8)
        <= "XXXXXXXX";
    end if;

    xmit_prev <= xmit;
    if xmit /= xmit_prev then
      tx_overrun <= xmit_buffered;
      xmit_buffered <= '1';
      xmit_buffer <= packet;
    end if;
    if xmit_buffered = '1' and to_xmit = 0 then
      to_xmit <= 5;
      xmit_buffered <= '0';
      xmit_queue <= xmit_buffer;
    end if;
  end process;
end usbio;
