library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity packet_deframer is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        rx_byte     : in  std_logic_vector(7 downto 0);
        rx_valid    : in  std_logic;
        payload     : out std_logic_vector(15 downto 0);
        payload_len : out integer;
        packet_ok   : out std_logic
    );
end entity;

architecture rtl of packet_deframer is

    type state_t is (
        IDLE,
        LEN,
        DATA0,
        DATA1,
        CRC,
        STOP
    );

    signal state       : state_t := IDLE;
    signal payload_reg : std_logic_vector(15 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state       <= IDLE;
                payload_reg <= (others => '0');
                payload_len <= 0;
                packet_ok   <= '0';

            else
                packet_ok <= '0'; -- default

                if rx_valid = '1' then
                    case state is

                        when IDLE =>
                            if rx_byte = x"AA" then
                                state <= LEN;
                            end if;

                        when LEN =>
                            payload_len <= to_integer(unsigned(rx_byte));
                            state <= DATA0;

                        when DATA0 =>
                            payload_reg(15 downto 8) <= rx_byte;
                            state <= DATA1;

                        when DATA1 =>
                            payload_reg(7 downto 0) <= rx_byte;
                            state <= CRC;

                        when CRC =>
                            -- CRC skipped for now
                            state <= STOP;

                        when STOP =>
                            if rx_byte = x"55" then
                                packet_ok <= '1';
                                payload   <= payload_reg;
                            end if;
                            state <= IDLE;

                    end case;
                end if;
            end if;
        end if;
    end process;

end architecture;
