library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

-- We run off a 50mhz clock, transferring 1 byte every 4 cycles.  This gives
-- up to 12.5MB/s transfer rate, to achieve the maximum rate we need to use
-- 'turbo' mode that ignores the FT2232H async strobes.
-- xmit strobes data in [subject to dead time] on clocks that are a multiple
-- of 4.
-- tx_overrun is asserted if xmit does not write a block.  It is cleared on the
-- next successful xmit.  In turbo mode, we have no idea if the write succeeds.
-- Instead tx_overrun outputs a LFSR which may be used to synchronise streams.
entity usbio is
  generic (packet_bytes : integer);
  port (usbd_in : in unsigned8;
        usbd_out : out unsigned8;
        usb_oe_n : out std_logic := '1';

        usb_nRXF : in std_logic;
        usb_nTXE : in std_logic;
        usb_nRD : out std_logic := '1';
        usb_nWR : out std_logic := '1';
        usb_SIWU : out std_logic := '1';

        read_ok : in std_logic := '1';
        byte_in : out unsigned8;
        byte_in_strobe : out std_logic;

        packet : in unsigned(packet_bytes * 8 - 1 downto 0);
        xmit : in std_logic; -- toggle to xmit.
        last : in std_logic; -- strobe for highest number channel.
        xmit_channel : in unsigned2;
        xmit_length : in integer range 0 to packet_bytes;
        low_latency, turbo : in std_logic;
        tx_overrun : out std_logic;
        clk : in std_logic);
end usbio;

architecture usbio of usbio is
  type state_t is (state_idle, state_write, state_write2, state_read,
                   state_read2, state_pause);
  signal state : state_t := state_idle;

  signal xmit_prev : std_logic;
  signal xmit_buffer : unsigned(packet_bytes * 8 - 1 downto 0);
  signal xmit_buffered : std_logic := '0';
  signal xmit_buffer_length : integer range 0 to packet_bytes;
  signal xmit_queue : unsigned(packet_bytes * 8 - 1 downto 0);
  signal xmit_channel_counter : unsigned2 := "00";
  signal to_xmit : integer range 0 to packet_bytes := 0;

  -- In turbo mode the overrun flags get replaced by an LFSR generated
  -- pattern.  Poly is 0x100802041.
  signal lfsr : std_logic_vector(31 downto 0) := x"00000001";

begin
  usbd_out <= xmit_queue(7 downto 0);

  process
    variable rx_available : boolean;
    variable tx_available : boolean;
  begin
    wait until rising_edge(clk);

    usb_nRD <= '1';
    usb_nWR <= '1';
    usb_oe_n <= '1';
    state <= state_idle;
    byte_in_strobe <= '0';

    if state /= state_pause then
      usb_SIWU <= '1';
    end if;

    -- If we're in state idle, decide what to do next.  Prefer reads over
    -- writes.  The read handshake ensures that a write will get out
    -- anyway.
    rx_available := usb_nRXF = '0' and read_ok = '1';
    tx_available := (usb_nTXE = '0' or turbo = '1') and to_xmit /= 0;
    if state = state_idle then
      if rx_available then
        state <= state_read;
        usb_nRD <= '0';
      elsif tx_available then
        state <= state_write;
        usb_oe_n <= '0';
      end if;
    end if;

    if state = state_write then
      usb_oe_n <= '0';
      usb_nWR <= '0';
      state <= state_write2;
      to_xmit <= to_xmit - 1;
    end if;

    if state = state_write2 then
      usb_nWR <= '0';
      state <= state_pause;
      xmit_queue(packet_bytes * 8 - 9 downto 0)
        <= xmit_queue(packet_bytes * 8 - 1 downto 8);
      xmit_queue(packet_bytes * 8 - 1 downto packet_bytes * 8 - 8)
        <= "XXXXXXXX";
      if to_xmit = 0 and xmit_buffered = '0' and low_latency = '1' then
        usb_SIWU <= '0';
      end if;
    end if;

    if state = state_read then
      usb_nRD <= '0';
      state <= state_read2;
    end if;

    if state = state_read2 then
      byte_in <= usbd_in;
      byte_in_strobe <= '1';
      state <= state_pause;
    end if;

    if xmit_buffered = '1' and to_xmit = 0 then
      to_xmit <= xmit_buffer_length;
      xmit_buffered <= '0';
      xmit_queue <= xmit_buffer;
    end if;

    xmit_prev <= xmit;
    if xmit /= xmit_prev and xmit_channel = xmit_channel_counter
    then
      xmit_buffered <= '1';
      xmit_buffer <= packet;
      xmit_buffer_length <= xmit_length;
      lfsr <= lfsr(30 downto 0) & (
        lfsr(31) xor lfsr(22) xor lfsr(12) xor lfsr(5));
      if turbo = '1' then
        tx_overrun <= lfsr(0);
      else
        tx_overrun <= xmit_buffered and b2s(to_xmit /= 0);
      end if;
    end if;
    if xmit /= xmit_prev then
      if last = '1' then
        xmit_channel_counter <= "00";
      else
        xmit_channel_counter <= xmit_channel_counter + 1;
      end if;
    end if;

  end process;
end usbio;
