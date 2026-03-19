library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_transceiver is
    Generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 9600
    );
    Port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        tx_start : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_busy  : out std_logic;
        tx_line  : out std_logic;
        rx_line  : in  std_logic;
        rx_data  : out std_logic_vector(7 downto 0);
        rx_done  : out std_logic
    );
end uart_transceiver;

architecture Behavioral of uart_transceiver is
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    
    type tx_state_type is (S_TX_IDLE, S_TX_START, S_TX_BITS, S_TX_STOP);
    signal tx_state : tx_state_type := S_TX_IDLE;
    signal tx_timer : integer range 0 to BIT_PERIOD := 0;
    signal tx_bit_idx : integer range 0 to 7 := 0;
    signal tx_shifter : std_logic_vector(7 downto 0) := (others => '0');
    
    type rx_state_type is (S_RX_IDLE, S_RX_START, S_RX_BITS, S_RX_STOP);
    signal rx_state : rx_state_type := S_RX_IDLE;
    signal rx_timer : integer range 0 to BIT_PERIOD := 0;
    signal rx_bit_idx : integer range 0 to 7 := 0;
    signal rx_shifter : std_logic_vector(7 downto 0) := (others => '0');
    
    signal rx_pulse_latched : std_logic := '0';
    signal rx_sync : std_logic_vector(1 downto 0) := "11";
    signal debounce_cnt : integer range 0 to 15 := 0;

begin

    -- TX Process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= S_TX_IDLE;
                tx_line <= '1';
                tx_busy <= '0';
            else
                case tx_state is
                    when S_TX_IDLE =>
                        tx_line <= '1';
                        if tx_start = '1' then
                            tx_state <= S_TX_START;
                            tx_shifter <= tx_data;
                            tx_timer <= 0;
                            tx_busy <= '1';
                        else tx_busy <= '0'; end if;
                    when S_TX_START =>
                        tx_line <= '0';
                        if tx_timer < BIT_PERIOD - 1 then tx_timer <= tx_timer + 1;
                        else tx_timer <= 0; tx_state <= S_TX_BITS; tx_bit_idx <= 0; end if;
                    when S_TX_BITS =>
                        tx_line <= tx_shifter(tx_bit_idx);
                        if tx_timer < BIT_PERIOD - 1 then tx_timer <= tx_timer + 1;
                        else tx_timer <= 0;
                            if tx_bit_idx < 7 then tx_bit_idx <= tx_bit_idx + 1; else tx_state <= S_TX_STOP; end if;
                        end if;
                    when S_TX_STOP =>
                        tx_line <= '1';
                        if tx_timer < BIT_PERIOD - 1 then tx_timer <= tx_timer + 1; else tx_state <= S_TX_IDLE; tx_busy <= '0'; end if;
                end case;
            end if;
        end if;
    end process;

    -- RX Process (Debounced Latch)
    process(clk)
    begin
        if rising_edge(clk) then
            rx_sync <= rx_sync(0) & rx_line;
            if rst = '1' then
                rx_state <= S_RX_IDLE; rx_done <= '0'; rx_pulse_latched <= '0'; debounce_cnt <= 0;
            else
                rx_done <= '0';
                
                -- FILTER: Only accept pulse if logic 0 for > 10 cycles (100ns)
                if rx_sync(1) = '0' then
                    if debounce_cnt < 10 then debounce_cnt <= debounce_cnt + 1;
                    else rx_pulse_latched <= '1'; end if; -- Latch confirmed pulse
                else
                    debounce_cnt <= 0;
                end if;

                case rx_state is
                    when S_RX_IDLE =>
                        rx_pulse_latched <= '0';
                        -- Wait for start bit (Debounced low)
                        if rx_sync(1) = '0' and debounce_cnt >= 10 then
                            rx_state <= S_RX_START; rx_timer <= 0;
                        end if;
                    when S_RX_START =>
                        if rx_timer < BIT_PERIOD - 1 then rx_timer <= rx_timer + 1;
                        else rx_timer <= 0; rx_state <= S_RX_BITS; rx_bit_idx <= 0; rx_pulse_latched <= '0'; end if;
                    when S_RX_BITS =>
                        if rx_timer < BIT_PERIOD - 1 then rx_timer <= rx_timer + 1;
                        else rx_timer <= 0;
                            -- Invert logic: Pulse(1) = Bit(0), NoPulse(0) = Bit(1)
                            if rx_pulse_latched = '1' then rx_shifter(rx_bit_idx) <= '0'; 
                            else rx_shifter(rx_bit_idx) <= '1'; end if;
                            rx_pulse_latched <= '0';
                            if rx_bit_idx < 7 then rx_bit_idx <= rx_bit_idx + 1; else rx_state <= S_RX_STOP; end if;
                        end if;
                    when S_RX_STOP =>
                        if rx_timer < BIT_PERIOD - 1 then rx_timer <= rx_timer + 1;
                        else rx_done <= '1'; rx_data <= rx_shifter; rx_state <= S_RX_IDLE; end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;