library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity packet_deframer_tb is
end;

architecture tb of packet_deframer_tb is

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '1';

    signal rx_data     : std_logic_vector(7 downto 0);
    signal rx_done     : std_logic;

    signal payload_out : std_logic_vector(7 downto 0);
    signal payload_valid : std_logic;
    signal packet_done  : std_logic;
    signal packet_error : std_logic;

    type packet_t is array (0 to 5) of std_logic_vector(7 downto 0);
    constant test_packet : packet_t :=
        (x"AA", x"02", x"48", x"49", x"01", x"55");

begin

    clk <= not clk after 5 ns;

    uut: entity work.packet_deframer
        port map (
            clk => clk,
            reset => reset,
            rx_data => rx_data,
            rx_done => rx_done,
            payload_out => payload_out,
            payload_valid => payload_valid,
            packet_done => packet_done,
            packet_error => packet_error
        );

    stimulus: process
    begin
        rx_done <= '0';
        wait for 20 ns;
        reset <= '0';

        for i in 0 to 5 loop
            rx_data <= test_packet(i);
            rx_done <= '1';
            wait for 10 ns;
            rx_done <= '0';
            wait for 40 ns;
        end loop;

        wait for 200 ns;

        if packet_done = '1' then
            report "RX PACKET DEFRAMER TEST PASSED" severity note;
        else
            report "RX PACKET DEFRAMER TEST FAILED" severity error;
        end if;

        wait;
    end process;

end architecture;
