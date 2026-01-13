--------------------------------------------------------------------------------
-- File: packet_framer_tb.vhd
-- Description: Testbench for Packet Framer Module
-- Test: Send payload "HI" (0x48, 0x49)
-- Expected packet: AA 02 48 49 01 55
--   Start: 0xAA
--   Length: 0x02 (2 bytes)
--   Payload: 0x48 ('H'), 0x49 ('I')
--   Checksum: 0x48 XOR 0x49 = 0x01
--   End: 0x55
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity packet_framer_tb is
end packet_framer_tb;

architecture Behavioral of packet_framer_tb is
    
    -- Component declaration for Packet Framer
    component packet_framer is
        port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            payload_data  : in  std_logic_vector(7 downto 0);
            payload_valid : in  std_logic;
            payload_last  : in  std_logic;
            tx_data       : out std_logic_vector(7 downto 0);
            tx_start      : out std_logic;
            tx_busy       : in  std_logic
        );
    end component;
    
    -- Component declaration for UART TX (to simulate tx_busy)
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
    
    -- Test data
    constant CHAR_H         : std_logic_vector(7 downto 0) := x"48";  -- 'H'
    constant CHAR_I         : std_logic_vector(7 downto 0) := x"49";  -- 'I'
    
    -- Expected packet sequence: AA 02 48 49 01 55
    type packet_array_t is array (0 to 5) of std_logic_vector(7 downto 0);
    constant EXPECTED_PACKET : packet_array_t := (
        x"AA",  -- Start byte
        x"02",  -- Length (2 bytes)
        x"48",  -- 'H'
        x"49",  -- 'I'
        x"01",  -- Checksum (0x48 XOR 0x49 = 0x01)
        x"55"   -- End byte
    );
    
    -- Signal declarations
    signal clk              : std_logic := '0';
    signal reset            : std_logic := '1';
    signal payload_data     : std_logic_vector(7 downto 0) := (others => '0');
    signal payload_valid    : std_logic := '0';
    signal payload_last     : std_logic := '0';
    signal tx_data          : std_logic_vector(7 downto 0);
    signal tx_start         : std_logic;
    signal tx_busy          : std_logic;
    signal tx               : std_logic;
    
    -- Test tracking
    signal packet_index     : integer := 0;
    signal test_passed      : boolean := false;
    signal test_failed      : boolean := false;
    
begin
    
    ----------------------------------------------------------------------------
    -- Instantiate Packet Framer
    ----------------------------------------------------------------------------
    uut: packet_framer
        port map (
            clk           => clk,
            reset         => reset,
            payload_data  => payload_data,
            payload_valid => payload_valid,
            payload_last  => payload_last,
            tx_data       => tx_data,
            tx_start      => tx_start,
            tx_busy       => tx_busy
        );
    
    ----------------------------------------------------------------------------
    -- Instantiate UART TX (to provide tx_busy feedback)
    ----------------------------------------------------------------------------
    uart_tx_inst: uart_tx
        generic map (
            CLK_FREQ    => CLK_FREQ,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk         => clk,
            reset       => reset,
            data_in     => tx_data,
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
    -- Packet Verification Process
    -- Monitors tx_data and tx_start to verify packet sequence
    ----------------------------------------------------------------------------
    verify_packet: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                if tx_start = '1' then
                    report "TX BYTE SENT = 0x" & to_hstring(tx_data);
                    -- Check if we're still within expected packet length
                    if packet_index < EXPECTED_PACKET'length then
                        -- Verify byte matches expected value
                        if tx_data = EXPECTED_PACKET(packet_index) then
                            report "Byte " & integer'image(packet_index) & 
                                   " correct: " & to_hstring(tx_data) severity note;
                            packet_index <= packet_index + 1;
                            
                            -- Check if complete packet received
                            if packet_index = EXPECTED_PACKET'length - 1 then
                                test_passed <= true;
                                report "========================================" severity note;
                                report "TEST PASSED: Complete packet verified!" severity note;
                                report "Packet: AA 02 48 49 01 55" severity note;
                                report "========================================" severity note;
                            end if;
                        else
                            test_failed <= true;
                            report "========================================" severity error;
                            report "TEST FAILED: Byte " & integer'image(packet_index) & 
                                   " mismatch!" severity error;
                            report "Expected: " & to_hstring(EXPECTED_PACKET(packet_index)) &
                                   ", Got: " & to_hstring(tx_data) severity error;
                            report "========================================" severity error;
                        end if;
                    else
                        test_failed <= true;
                        report "TEST FAILED: Too many bytes transmitted!" severity error;
                    end if;
                end if;
            else
                -- Reset verification state
                packet_index <= 0;
                test_passed <= false;
                test_failed <= false;
            end if;
        end if;
    end process verify_packet;
    
    ----------------------------------------------------------------------------
    -- Stimulus Process
    ----------------------------------------------------------------------------
    stimulus: process
    begin
        -- Initialize all inputs
        reset       <= '1';
        payload_data <= (others => '0');
        payload_valid <= '0';
        payload_last <= '0';
        
        -- Apply reset for 100 ns
        wait for 100 ns;
        reset <= '0';
        
        -- Wait a few clock cycles after reset deassertion
        wait for 5 * CLK_PERIOD;
        
        ------------------------------------------------------------------------
        -- Send payload "HI" (0x48, 0x49)
        ------------------------------------------------------------------------
        -- Send first byte 'H'
        payload_data <= CHAR_H;
        payload_valid <= '1';
        payload_last <= '0';
        wait for CLK_PERIOD;
        payload_valid <= '0';
        wait for 2 * CLK_PERIOD;
        
        -- Send second byte 'I' (last byte)
        payload_data <= CHAR_I;
        payload_valid <= '1';
        payload_last <= '1';
        wait for CLK_PERIOD;
        payload_valid <= '0';
        payload_last <= '0';
        
        -- Wait for complete packet transmission
        -- Packet has 6 bytes, each byte takes ~1.04 ms at 9600 baud
        -- Total time: 6 * 1.04 ms = ~6.25 ms
        wait for 10 ms;
        
        ------------------------------------------------------------------------
        -- Final verification and report
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;
        
        -- Assert test results
        assert test_passed = true
            report "TEST FAILED: Packet verification did not pass!"
            severity failure;
        
        assert test_failed = false
            report "TEST FAILED: Packet verification detected errors!"
            severity failure;
        
        if test_passed and not test_failed then
            report "========================================" severity note;
            report "FINAL RESULT: TEST PASSED" severity note;
            report "Packet framer correctly generated:" severity note;
            report "  Start: 0xAA" severity note;
            report "  Length: 0x02" severity note;
            report "  Payload: 0x48 0x49 ('HI')" severity note;
            report "  Checksum: 0x01" severity note;
            report "  End: 0x55" severity note;
            report "========================================" severity note;
        end if;
        
        wait;
    end process stimulus;
    
end Behavioral;
