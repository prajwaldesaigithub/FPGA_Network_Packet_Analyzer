--------------------------------------------------------------------------------
-- File: uart_tb.vhd
-- Description: Testbench for UART Transmitter Module
-- Test Scenario: Transmit ASCII characters 'A' and 'B' at 9600 baud
-- Clock Frequency: 100 MHz
-- Expected Waveform:
--   - Reset active for first 100 ns
--   - After reset, tx line is high (idle state)
--   - Start bit: tx goes low for ~104.17 us (1/9600)
--   - Data bits: 8 bits transmitted LSB first ('A'=0x41='01000001' -> LSB first)
--   - Stop bit: tx goes high for ~104.17 us
--   - Repeat for character 'B'
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tb is
end uart_tb;

architecture Behavioral of uart_tb is

    -- Component declaration for UART Transmitter
    component uart_tx is
        generic (
            CLK_FREQ    : integer := 100_000_000;
            BAUD_RATE   : integer := 9600
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            data_in     : in  std_logic_vector(7 downto 0);
            tx_start    : in  std_logic;
            tx          : out std_logic;
            tx_busy     : out std_logic
        );
    end component;

    -- Constants
    constant CLK_FREQ       : integer := 100_000_000;  -- 100 MHz
    constant CLK_PERIOD     : time := 10 ns;           -- 1/100MHz = 10 ns
    constant BAUD_RATE      : integer := 9600;
    constant BAUD_PERIOD    : time := 104167 ns;       -- 1/9600 ≈ 104.17 us
    
    -- Test data (ASCII characters)
    constant CHAR_A         : std_logic_vector(7 downto 0) := x"41";  -- 'A'
    constant CHAR_B         : std_logic_vector(7 downto 0) := x"42";  -- 'B'
    
    -- Signal declarations
    signal clk              : std_logic := '0';
    signal reset            : std_logic := '1';
    signal data_in          : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start         : std_logic := '0';
    signal tx               : std_logic;
    signal tx_busy          : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Instantiate UART Transmitter
    ----------------------------------------------------------------------------
    uut: uart_tx
        generic map (
            CLK_FREQ    => CLK_FREQ,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk         => clk,
            reset       => reset,
            data_in     => data_in,
            tx_start    => tx_start,
            tx          => tx,
            tx_busy     => tx_busy
        );

    ----------------------------------------------------------------------------
    -- Clock Generation (100 MHz: period = 10 ns)
    ----------------------------------------------------------------------------
    clk_gen: process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_gen;

    ----------------------------------------------------------------------------
    -- Stimulus Process
    ----------------------------------------------------------------------------
    stimulus: process
    begin
        -- Initialize all inputs
        reset       <= '1';
        data_in     <= (others => '0');
        tx_start    <= '0';
        
        -- Apply reset for 100 ns
        wait for 100 ns;
        reset <= '0';
        
        -- Wait a few clock cycles after reset deassertion
        wait for 5 * CLK_PERIOD;
        
        ------------------------------------------------------------------------
        -- Test Case 1: Transmit ASCII character 'A' (0x41)
        ------------------------------------------------------------------------
        -- Expected: START(0) | D7 D6 D5 D4 D3 D2 D1 D0 | STOP(1)
        -- Data: 0x41 = '01000001' binary
        -- LSB first: 1 0 0 0 0 0 1 0
        -- Full sequence: START(0) | 1 0 0 0 0 0 1 0 | STOP(1)
        ------------------------------------------------------------------------
        data_in <= CHAR_A;  -- 'A' = 0x41
        wait for CLK_PERIOD;
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';  -- Assert for exactly one clock cycle
        
        -- Wait until transmission completes (tx_busy goes low)
        wait until tx_busy = '0';
        wait for 2 * CLK_PERIOD;  -- Small delay between transmissions
        
        ------------------------------------------------------------------------
        -- Test Case 2: Transmit ASCII character 'B' (0x42)
        ------------------------------------------------------------------------
        -- Expected: START(0) | D7 D6 D5 D4 D3 D2 D1 D0 | STOP(1)
        -- Data: 0x42 = '01000010' binary
        -- LSB first: 0 1 0 0 0 0 1 0
        -- Full sequence: START(0) | 0 1 0 0 0 0 1 0 | STOP(1)
        ------------------------------------------------------------------------
        data_in <= CHAR_B;  -- 'B' = 0x42
        wait for CLK_PERIOD;
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';  -- Assert for exactly one clock cycle
        
        -- Wait until transmission completes (tx_busy goes low)
        wait until tx_busy = '0';
        wait for 2 * CLK_PERIOD;
        
        ------------------------------------------------------------------------
        -- End of simulation
        ------------------------------------------------------------------------
        -- Wait a bit more to observe the final state
        wait for 10 * CLK_PERIOD;
        
        report "Simulation completed successfully!" severity note;
        wait;
    end process stimulus;

end Behavioral;
