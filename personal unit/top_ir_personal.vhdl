library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity personal_unit_top is
    Port (
        CLK100MHZ : in std_logic;
        rst_btn   : in std_logic;
        sw_id     : in std_logic_vector(2 downto 0);
        ir_tx     : out std_logic;
        ir_rx     : in  std_logic;
        led_r, led_g, led_b : out std_logic;
        
        -- DEBUG: Shows Packet Count during TX, ID during Idle
        led_id    : out std_logic_vector(2 downto 0) 
    );
end personal_unit_top;

architecture Behavioral of personal_unit_top is
    constant SEC_KEY  : std_logic_vector(7 downto 0) := x"42"; 
    constant PING_CMD : std_logic_vector(7 downto 0) := x"A5";
    
    constant REPLY_DELAY_CYCLES : integer := 10_000_000; -- 100ms
    constant INTER_BYTE_DELAY   : integer := 200_000;    -- 2ms (Tight Gap)
    constant BURST_COUNT        : integer := 64;         -- 64 Packets

    signal sys_rst : std_logic;
    signal tx_start, tx_busy, rx_done : std_logic;
    signal tx_data, rx_data : std_logic_vector(7 downto 0);
    signal uart_tx_raw : std_logic;

    type state_type is (LISTEN, WAIT_DELAY, PREPARE_DATA, SEND_PREAMBLE, WAIT_PREAMBLE, 
                        SEND_BYTE, WAIT_TX_DONE, INTER_DELAY);
    signal state : state_type := LISTEN;
    
    signal led_rx_cnt : integer range 0 to 10_000_000 := 0;
    signal delay_timer : integer range 0 to REPLY_DELAY_CYCLES := 0;
    
    signal packet_idx : integer range 0 to BURST_COUNT := 0;
    signal current_response_byte : std_logic_vector(7 downto 0);
    
    signal bursting : std_logic := '0';

begin
    sys_rst <= NOT rst_btn;
    
    -- VISUAL DEBUG: 
    -- If Bursting -> Show Packet Index (Lower 3 bits) so we see it counting
    -- If Idle -> Show the User ID Switch settings
    led_id <= std_logic_vector(to_unsigned(packet_idx, 3)) when bursting = '1' else sw_id;
    
    u_uart: entity work.uart_transceiver port map (CLK100MHZ, sys_rst, tx_start, tx_data, tx_busy, uart_tx_raw, ir_rx, rx_data, rx_done);
    u_phys: entity work.ir_phys_layer port map (CLK100MHZ, sys_rst, uart_tx_raw, ir_tx);

    process(CLK100MHZ)
        variable full_uid : std_logic_vector(7 downto 0);
    begin
        if rising_edge(CLK100MHZ) then
            if sys_rst = '1' then
                state <= LISTEN; tx_start <= '0'; packet_idx <= 0; bursting <= '0';
            else
                tx_start <= '0';

                case state is
                    when LISTEN =>
                        bursting <= '0';
                        if rx_done = '1' then
                            led_rx_cnt <= 10_000_000;
                            if rx_data = PING_CMD then
                                delay_timer <= 0;
                                state <= WAIT_DELAY;
                            end if;
                        end if;

                    when WAIT_DELAY =>
                        if delay_timer < REPLY_DELAY_CYCLES then delay_timer <= delay_timer + 1;
                        else state <= PREPARE_DATA; end if;

                    when PREPARE_DATA =>
                        current_response_byte <= ("00000" & sw_id) XOR SEC_KEY;
                        packet_idx <= 0;
                        bursting <= '1'; 
                        state <= SEND_PREAMBLE;

                    -- SEND DUMMY BYTE (0xFF) TO WAKE UP AGC
                    when SEND_PREAMBLE =>
                        tx_data <= x"FF";
                        tx_start <= '1';
                        state <= WAIT_PREAMBLE;

                    when WAIT_PREAMBLE =>
                        if tx_busy = '0' and tx_start = '0' then
                            delay_timer <= 0;
                            state <= INTER_DELAY; -- Wait small gap before real data
                        end if;

                    when SEND_BYTE =>
                        tx_data <= current_response_byte;
                        tx_start <= '1';
                        state <= WAIT_TX_DONE;

                    when WAIT_TX_DONE =>
                        if tx_busy = '0' and tx_start = '0' then
                            if packet_idx < BURST_COUNT then
                                packet_idx <= packet_idx + 1;
                                delay_timer <= 0;
                                state <= INTER_DELAY;
                            else
                                state <= LISTEN;
                            end if;
                        end if;

                    when INTER_DELAY =>
                        if delay_timer < INTER_BYTE_DELAY then delay_timer <= delay_timer + 1;
                        else state <= SEND_BYTE; end if;
                end case;
            end if;

            if led_rx_cnt > 0 then led_rx_cnt <= led_rx_cnt - 1; end if;
        end if;
    end process;

    led_r <= sys_rst;
    led_g <= bursting; -- Solid Green during burst
    led_b <= '1' when led_rx_cnt > 0 else '0';

end Behavioral;