--------------------------------------------------------------------------------
-- File: packet_framer.vhd
-- Description: Packet Framer Module
-- Builds framed packets and sends them byte-by-byte via UART TX
-- Packet format: Start(0xAA) | Length | Payload | Checksum(XOR) | End(0x55)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity packet_framer is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        
        -- Payload input interface
        payload_data  : in  std_logic_vector(7 downto 0);
        payload_valid : in  std_logic;
        payload_last  : in  std_logic;
        
        -- UART TX interface
        tx_data       : out std_logic_vector(7 downto 0);
        tx_start      : out std_logic;
        tx_busy       : in  std_logic
    );
end packet_framer;

architecture rtl of packet_framer is
    
    -- FSM states
    type state_t is (
        IDLE,
        SEND_START,
        SEND_LEN,
        SEND_PAYLOAD,
        SEND_CHECKSUM,
        SEND_END
    );
    
    signal state : state_t := IDLE;
    
    -- Internal storage
    type mem_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal buffer_mem : mem_t;
    signal length      : integer range 0 to 255 := 0;
    signal index       : integer range 0 to 255 := 0;
    signal checksum    : std_logic_vector(7 downto 0) := (others => '0');
    
begin
    
    ----------------------------------------------------------------------------
    -- Packet Framer State Machine
    ----------------------------------------------------------------------------
    framer_fsm: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset all signals
                state      <= IDLE;
                tx_start   <= '0';
                tx_data    <= (others => '0');
                length     <= 0;
                index      <= 0;
                checksum   <= (others => '0');
                
            else
                -- Default: deassert tx_start (pulse for one clock cycle)
                tx_start <= '0';
                
                case state is
                    
                    -----------------------------------------------------------------
                    -- IDLE State: Buffer payload bytes when payload_valid pulses
                    -----------------------------------------------------------------
                    when IDLE =>
                        if payload_valid = '1' then
                            -- Store payload byte and update checksum
                            buffer_mem(length) <= payload_data;
                            checksum <= checksum xor payload_data;
                            length <= length + 1;
                            
                            -- If this is the last payload byte, start transmission
                            if payload_last = '1' then
                                index <= 0;
                                state <= SEND_START;
                            end if;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- SEND_START State: Send start byte (0xAA)
                    -----------------------------------------------------------------
                    when SEND_START =>
                        if tx_busy = '0' then
                            tx_data <= x"AA";
                            tx_start <= '1';
                            state <= SEND_LEN;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- SEND_LEN State: Send length byte
                    -----------------------------------------------------------------
                    when SEND_LEN =>
                        if tx_busy = '0' then
                            tx_data <= std_logic_vector(to_unsigned(length, 8));
                            tx_start <= '1';
                            state <= SEND_PAYLOAD;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- SEND_PAYLOAD State: Send all buffered payload bytes
                    -----------------------------------------------------------------
                    when SEND_PAYLOAD =>
                        if tx_busy = '0' then
                            tx_data <= buffer_mem(index);
                            tx_start <= '1';
                            
                            -- Check if this is the last payload byte
                            if index >= length - 1 then
                                state <= SEND_CHECKSUM;
                            else
                                index <= index + 1;
                            end if;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- SEND_CHECKSUM State: Send checksum (XOR of payload bytes)
                    -----------------------------------------------------------------
                    when SEND_CHECKSUM =>
                        if tx_busy = '0' then
                            tx_data <= checksum;
                            tx_start <= '1';
                            state <= SEND_END;
                        end if;
                    
                    -----------------------------------------------------------------
                    -- SEND_END State: Send end byte (0x55) and return to IDLE
                    -----------------------------------------------------------------
                    when SEND_END =>
                        if tx_busy = '0' then
                            tx_data <= x"55";
                            tx_start <= '1';
                            state <= IDLE;
                            -- Reset for next packet
                            length <= 0;
                            checksum <= (others => '0');
                        end if;
                    
                    -----------------------------------------------------------------
                    -- Default case (should never occur)
                    -----------------------------------------------------------------
                    when others =>
                        state <= IDLE;
                        tx_start <= '0';
                        length <= 0;
                        index <= 0;
                        checksum <= (others => '0');
                
                end case;
            end if;
        end if;
    end process framer_fsm;
    
end architecture rtl;
