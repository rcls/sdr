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
        usb_SIWA : out std_logic := '1';

        config : out unsigned(config_bytes * 8 - 1 downto 0) := resize(
          defconfig, config_bytes * 8);

        packet : in unsigned(packet_bytes * 8 - 1 downto 0);
        xmit : in std_logic; -- toggle to xmit.
        last : in std_logic; -- strobe for channel 0.
        xmit_channel : in unsigned2;
        xmit_length : in integer range 0 to packet_bytes;
        tx_overrun : out std_logic;

        clk : in std_logic);
end usbio;

architecture usbio of usbio is
  type state_t is (state_idle, state_write, state_pause);
  signal state : state_t := state_idle;
  signal config_strobes : std_logic_vector(31 downto 0) := (others => '0');
  signal config_magic : unsigned8;
  signal config_address : unsigned8;

  signal xmit_prev : std_logic;
  signal xmit_buffer : unsigned(packet_bytes * 8 - 1 downto 0);
  signal xmit_buffered : std_logic := '0';
  signal xmit_buffer_length : integer range 0 to packet_bytes;
  signal xmit_queue : unsigned(packet_bytes * 8 - 1 downto 0);
  signal xmit_channel_counter : unsigned2 := "00";
  signal to_xmit : integer range 0 to packet_bytes := 0;
  signal prefer_tx : boolean := true;
begin
  process
  begin
    wait until rising_edge(clk);

    usb_nRD <= '1';
    usb_nWR <= '1';
    usb_oe_n <= '1';
    usb_SIWA <= '1';
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
    if config_strobes(30) = '1' then
      config_magic <= usbd_in;
    end if;

    -- If we're in state idle, decide what to do next.  Prefer reads over
    -- writes.
    if state = state_idle then
      if usb_nTXE = '0' and to_xmit /= 0 and (usb_nRXF = '1' or prefer_tx) then
        state <= state_write;
        usb_oe_n <= '0';
      elsif usb_nRXF = '0' then
        prefer_tx <= true;
        state <= state_pause;
        usb_nRD <= '0';
        config_strobes(to_integer(config_address(4 downto 0))) <= '1';
        config_address <= x"ff";
      end if;
    end if;

    if state = state_write then
      prefer_tx <= false;
      usb_oe_n <= '0';
      usb_nWR <= '0';
      state <= state_pause;
      to_xmit <= to_xmit - 1;
      xmit_queue(packet_bytes * 8 - 9 downto 0)
        <= xmit_queue(packet_bytes * 8 - 1 downto 8);
      xmit_queue(packet_bytes * 8 - 1 downto packet_bytes * 8 - 8)
        <= "XXXXXXXX";
    end if;

    if state = state_pause then
      usb_SIWA <= '0';
    end if;

    xmit_prev <= xmit;
    if xmit /= xmit_prev and xmit_channel = xmit_channel_counter
    then
      tx_overrun <= xmit_buffered and b2s(to_xmit /= 0);
      xmit_buffered <= '1';
      xmit_buffer <= packet;
      xmit_buffer_length <= xmit_length;
    end if;
    if xmit /= xmit_prev then
      if last = '1' then
        xmit_channel_counter <= "00";
      else
        xmit_channel_counter <= xmit_channel_counter + 1;
      end if;
    end if;
    if xmit_buffered = '1' and to_xmit = 0 then
      to_xmit <= xmit_buffer_length;
      xmit_buffered <= '0';
      xmit_queue <= xmit_buffer;
    end if;

    -- If the config magic is not correct, then do not allow programming any
    -- other registers.
    if config_magic /= x"b5" then
      config_strobes(29 downto 0) <= (others => '0');
    end if;

  end process;
end usbio;
