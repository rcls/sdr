library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


library work;
use work.defs.all;

entity usbio is
  generic (config_bytes : integer);
  port (usbd_in : in unsigned8;
        usbd_out : out unsigned8;
        usb_oe : out std_logic;

        usb_nRXF : in std_logic;
        usb_nTXE : in std_logic;
        usb_nRD : out std_logic := '1';
        usb_nWR : out std_logic := '1';

        config : out unsigned(config_bytes * 8 - 1 downto 0);
        send : in unsigned24;
        xmit : in boolean;

        clk : in std_logic);
end usbio;

architecture behavioural of usbio is
  -- We do 1 byte in each direction every 80 clock cycles, 3.125MB/s.
  signal phase : unsigned(6 downto 0);
  -- The logic drives off clock/20, this is the /20 strobe.
  signal go : boolean;
  -- Asserted for a single cycle to commit config.
  signal config_load : boolean;

  -- Position in config.
  signal conf_count : integer range 0 to config_bytes - 1;

  -- Config being captured from USB.
  signal in_buf : unsigned(config_bytes * 8 - 1 downto 0);

  signal nTXE : std_logic;
  signal nRXF : std_logic;

  -- 00/01/10 to decide which byte to output.
  signal obyte : unsigned2;
begin
  process (clk)
  begin
    if clk'event and clk = '1' then
      -- We divide by 80 by counting mod 5 on the low 3 bits.
      if phase(2) = '0' then
        phase <= phase + 1;
      else
        phase <= phase + 4;
      end if;
      -- Asserted once every twenty cycles.
      go <= phase(4 downto 2) = "111";

      config_load <= go and conf_count = config_bytes - 1
                     and phase(6 downto 5) = "11";
      if config_load then
        config <= in_buf;
      end if;

      sample_in <= obyte(1) = '1' and go and phase(6 downto 5) = "11";
      if sample_in then
        out_buf <= send;
      end if;

      -- We run off /20, so we have 4 periods of 80ns.
      -- 0/1 write, 3 capture txe.
      -- 2/3 read, 1 capture rxf.
      if go then
        case obyte is
          when "00" =>
            usbd_out <= out_buf(7 downto 0);
          when "01" =>
            usbd_out <= out_buf(15 downto 8);
          when others =>
            usbd_out <= out_buf(23 downto 16);
        end case;

        usb_nWR <= '1';
        usb_nRD <= '0';
        usb_oe <= '0';
        case phase(6 downto 5) is
          when "00" =>
            if nTXE = '0' and xmit then
              usb_oe <= '1';
              usb_nWR <= '0';
            end if;
            if nRXF = '1' or conf_count = config_bytes - 1 then
              config_bytes <= 0;
            else
              config_bytes <= config_bytes + 1;
            end if;
          when "01" =>
            if nTXE = '0' and xmit then
              usb_oe <= '1';
            end if;
            nRXF <= usb_nRXF;
          when "10" =>
            usb_nRD <= nRXF;
            if obyte(1) = '0' then
              obyte <= obyte + 1;
            else
              obyte <= "00";
            end if;
          when "11" =>
            in_buf <= in_buf(config_bytes * 8 - 9 downto 0) & usbd_in;
            nTXE <= usb_nTXE;
          when others =>
        end case;
      end if;
    end if;
  end process;
end behavioural;
