--------------------------------------------------------------------------------
-- File: uart_tx.vhd
-- Description: UART Transmitter Module
-- Features: Parameterizable baud rate, 8N1 format, FSM-based implementation
-- Compatible with ModelSim and Xilinx ISE 14.7
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic (
        CLK_FREQ    : integer := 100_000_000;  -- System clock frequency in Hz
        BAUD_RATE   : integer := 9600          -- Baud rate (default: 9600)
    );
    port (
        clk         : in  std_logic;           -- System clock
        reset       : in  std_logic;           -- Active high reset
        data_in     : in  std_logic_vector(7 downto 0);  -- 8-bit data to transmit
        tx_start    : in  std_logic;           -- Start transmission (active high)
        tx          : out std_logic;           -- Serial output
        tx_busy     : out std_logic            -- Transmitter busy flag
    );
end uart_tx;

architecture Behavioral of uart_tx is

    -- Baud rate counter constant: clock cycles per baud period
    constant BAUD_COUNT : integer := CLK_FREQ / BAUD_RATE;
    
    -- FSM states
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state        : state_type := IDLE;
    
    -- Internal signals
    signal baud_counter : integer range 0 to BAUD_COUNT - 1 := 0;
    signal bit_counter  : integer range 0 to 7 := 0;
    signal data_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg       : std_logic := '1';  -- Idle state is high
    signal busy_reg     : std_logic := '0';

begin

    -- Output assignments
    tx      <= tx_reg;
    tx_busy <= busy_reg;

    ----------------------------------------------------------------------------
    -- UART Transmitter State Machine
    ----------------------------------------------------------------------------
    uart_tx_fsm: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset state
                state        <= IDLE;
                baud_counter <= 0;
                bit_counter  <= 0;
                data_reg     <= (others => '0');
                tx_reg       <= '1';  -- Idle state: line is high
                busy_reg     <= '0';
            else
                case state is
                    
                    -----------------------------------------------------------------
                    -- IDLE State: Wait for transmission request
                    -----------------------------------------------------------------
                    when IDLE =>
                        tx_reg       <= '1';  -- Idle line is high
                        busy_reg     <= '0';
                        baud_counter <= 0;
                        bit_counter  <= 0;
                        
                        if tx_start = '1' then
                            data_reg     <= data_in;  -- Latch input data
                            state        <= START_BIT;
                            busy_reg     <= '1';
                            baud_counter <= 0;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- START_BIT State: Send start bit (low for one baud period)
                    -----------------------------------------------------------------
                    when START_BIT =>
                        tx_reg <= '0';  -- Start bit is low
                        
                        if baud_counter < BAUD_COUNT - 1 then
                            baud_counter <= baud_counter + 1;
                        else
                            baud_counter <= 0;
                            state        <= DATA_BITS;
                            bit_counter  <= 0;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- DATA_BITS State: Send 8 data bits, LSB first
                    -----------------------------------------------------------------
                    when DATA_BITS =>
                        tx_reg <= data_reg(bit_counter);  -- Send bit (LSB first)
                        
                        if baud_counter < BAUD_COUNT - 1 then
                            baud_counter <= baud_counter + 1;
                        else
                            baud_counter <= 0;
                            
                            if bit_counter < 7 then
                                bit_counter <= bit_counter + 1;
                            else
                                bit_counter <= 0;
                                state        <= STOP_BIT;
                            end if;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- STOP_BIT State: Send stop bit (high for one baud period)
                    -----------------------------------------------------------------
                    when STOP_BIT =>
                        tx_reg <= '1';  -- Stop bit is high
                        
                        if baud_counter < BAUD_COUNT - 1 then
                            baud_counter <= baud_counter + 1;
                        else
                            baud_counter <= 0;
                            state        <= IDLE;
                            busy_reg     <= '0';
                        end if;
                    
                    -----------------------------------------------------------------
                    -- Default case (should never occur)
                    -----------------------------------------------------------------
                    when others =>
                        state        <= IDLE;
                        tx_reg       <= '1';
                        busy_reg     <= '0';
                        baud_counter <= 0;
                        bit_counter  <= 0;
                
                end case;
            end if;
        end if;
    end process uart_tx_fsm;

end Behavioral;
