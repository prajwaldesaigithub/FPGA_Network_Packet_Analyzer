library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx_tb is
end entity;

architecture tb of uart_rx_tb is

    -- Clock / timing
    constant CLK_PERIOD : time := 10 ns;          -- 100 MHz
    constant BIT_TIME   : time := 104 us;          -- 9600 baud

    -- Signals
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';

    signal tx_start  : std_logic := '0';
    signal data_in   : std_logic_vector(7 downto 0) := (others => '0');

    signal tx_line   : std_logic;
    signal rx_data   : std_logic_vector(7 downto 0);
    signal rx_done   : std_logic;

begin

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    --------------------------------------------------------------------
    -- UART TX instance
    --------------------------------------------------------------------
    tx_inst : entity work.uart_tx
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => data_in,
            tx_start => tx_start,
            tx       => tx_line,
            tx_busy  => open
        );

    --------------------------------------------------------------------
    -- UART RX instance (loopback from TX)
    --------------------------------------------------------------------
    rx_inst : entity work.uart_rx
        port map (
            clk      => clk,
            reset    => reset,
            rx       => tx_line,
            data_out => rx_data,
            rx_done  => rx_done
        );

    --------------------------------------------------------------------
    -- Test process
    --------------------------------------------------------------------
    stimulus : process
    begin
        ------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------
        reset <= '1';
        wait for 200 ns;
        reset <= '0';
        wait for 200 ns;

        ------------------------------------------------------------
        -- Send 'A' (0x41)
        ------------------------------------------------------------
        data_in  <= x"41";        -- ASCII 'A'
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        wait until rx_done = '1';
        assert rx_data = x"41"
            report "RX ERROR: Expected 'A' (0x41)"
            severity error;

        report "RX received A (0x41) SUCCESS";

        wait for 1 ms;

        ------------------------------------------------------------
        -- Send 'B' (0x42)
        ------------------------------------------------------------
        data_in  <= x"42";        -- ASCII 'B'
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        wait until rx_done = '1';
        assert rx_data = x"42"
            report "RX ERROR: Expected 'B' (0x42)"
            severity error;

        report "RX received B (0x42) SUCCESS";

        ------------------------------------------------------------
        -- End simulation
        ------------------------------------------------------------
        report "UART RX TEST PASSED";
        wait;
    end process;

end architecture;