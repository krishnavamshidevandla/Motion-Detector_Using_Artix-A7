library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_ir_alarm is
    Port (
        CLK100MHZ    : in  std_logic;
        reset        : in  std_logic;
        triggered    : in  std_logic;
        tx           : out std_logic;
        rx           : in  std_logic;
        personal_id  : out std_logic_vector(7 downto 0); -- Outputs DECRYPTED ID on success
        auth_success : out std_logic;
        auth_fail    : out std_logic
    );
end top_ir_alarm;

architecture Behavioral of top_ir_alarm is
    constant SEC_KEY  : std_logic_vector(7 downto 0) := x"42"; 
    constant PING_CMD : std_logic_vector(7 downto 0) := x"A5";

    type state_type is (IDLE, SEND_PING, BLIND_WAIT, LISTENING_WINDOW, CHECK_SCORE, COOLDOWN);
    signal state : state_type := IDLE;

    signal tx_start, tx_busy, rx_done : std_logic;
    signal tx_data, rx_data : std_logic_vector(7 downto 0);
    signal uart_tx_raw, rx_masked : std_logic;
    
    -- Timers
    signal timer : integer range 0 to 100_000_000 := 0;
    constant BLIND_CYCLES   : integer := 5_000_000;   -- 50ms blind
    constant LISTEN_CYCLES  : integer := 50_000_000;  -- 500ms listening window
    
    -- Scoring
    signal valid_packet_count : integer range 0 to 10 := 0;
    signal last_valid_id      : std_logic_vector(7 downto 0);

begin

    rx_masked <= rx when (tx_busy = '0' and state /= SEND_PING and state /= BLIND_WAIT) else '1';

    u_uart: entity work.uart_transceiver
    port map (CLK100MHZ, reset, tx_start, tx_data, tx_busy, uart_tx_raw, rx_masked, rx_data, rx_done);

    u_phys: entity work.ir_phys_layer
    port map (CLK100MHZ, reset, uart_tx_raw, tx);

    process(CLK100MHZ)
        variable decrypted_temp : std_logic_vector(7 downto 0);
    begin
        if rising_edge(CLK100MHZ) then
            if reset = '1' then
                state <= IDLE;
                auth_success <= '0'; auth_fail <= '0';
                personal_id <= (others => '0');
                tx_start <= '0';
            else
                tx_start <= '0'; 

                case state is
                    when IDLE =>
                        auth_success <= '0'; auth_fail <= '0';
                        valid_packet_count <= 0;
                        if triggered = '1' then state <= SEND_PING; end if;

                    when SEND_PING =>
                        tx_data <= PING_CMD; tx_start <= '1';
                        state <= BLIND_WAIT;

                    when BLIND_WAIT =>
                        -- Wait 50ms to ignore own Echo
                        if timer < BLIND_CYCLES then timer <= timer + 1;
                        else timer <= 0; state <= LISTENING_WINDOW; end if;

                    when LISTENING_WINDOW =>
                        -- Stay here for 500ms. Catch ANYTHING valid.
                        if timer < LISTEN_CYCLES then
                            timer <= timer + 1;
                            
                            if rx_done = '1' then
                                -- Try to decrypt whatever we just heard
                                decrypted_temp := rx_data XOR SEC_KEY;
                                
                                -- Check if it looks like a valid ID (0-7)
                                if unsigned(decrypted_temp) < 8 then
                                    if valid_packet_count < 10 then
                                        valid_packet_count <= valid_packet_count + 1;
                                    end if;
                                    last_valid_id <= decrypted_temp;
                                end if;
                            end if;
                        else
                            state <= CHECK_SCORE;
                        end if;

                    when CHECK_SCORE =>
                        -- Did we catch at least 2 valid packets in the noise?
                        if valid_packet_count >= 2 then
                            auth_success <= '1';
                            personal_id <= last_valid_id; -- Send ID to Controller
                        else
                            auth_fail <= '1';
                        end if;
                        
                        timer <= 0;
                        state <= COOLDOWN;

                    when COOLDOWN =>
                        if timer < 100_000_000 then timer <= timer + 1;
                        else state <= IDLE; end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;