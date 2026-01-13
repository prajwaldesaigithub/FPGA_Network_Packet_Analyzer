library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 9600
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        rx       : in  std_logic; -- Serial input
        data_out : out std_logic_vector(7 downto 0);
        rx_done  : out std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is

    constant BAUD_COUNT : integer := CLK_FREQ / BAUD_RATE;
    constant HALF_BAUD  : integer := BAUD_COUNT / 2;

    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_type := IDLE;

    signal baud_counter : integer range 0 to BAUD_COUNT := 0;
    signal bit_counter  : integer range 0 to 7 := 0;
    signal data_reg     : std_logic_vector(7 downto 0) := (others => '0');

begin

    data_out <= data_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state         <= IDLE;
                baud_counter  <= 0;
                bit_counter   <= 0;
                data_reg      <= (others => '0');
                rx_done       <= '0';
            else
                rx_done <= '0';  -- default

                case state is

                    -------------------------------------------------
                    -- IDLE: Wait for start bit (rx goes LOW)
                    -------------------------------------------------
                    when IDLE =>
                        if rx = '0' then
                            state        <= START_BIT;
                            baud_counter <= 0;
                        end if;

                    -------------------------------------------------
                    -- START_BIT: sample at mid-bit
                    -------------------------------------------------
                    when START_BIT =>
                        if baud_counter = HALF_BAUD then
                            if rx = '0' then
                                baud_counter <= 0;
                                bit_counter  <= 0;
                                state        <= DATA_BITS;
                            else
                                state <= IDLE; -- false start
                            end if;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    -------------------------------------------------
                    -- DATA_BITS: sample every full baud
                    -------------------------------------------------
                    when DATA_BITS =>
                        if baud_counter = BAUD_COUNT then
                            baud_counter <= 0;
                            data_reg(bit_counter) <= rx;

                            if bit_counter = 7 then
                                state <= STOP_BIT;
                            else
                                bit_counter <= bit_counter + 1;
                            end if;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    -------------------------------------------------
                    -- STOP_BIT: expect rx = 1
                    -------------------------------------------------
                    when STOP_BIT =>
                        if baud_counter = BAUD_COUNT then
                            rx_done      <= '1';
                            baud_counter <= 0;
                            state        <= IDLE;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
