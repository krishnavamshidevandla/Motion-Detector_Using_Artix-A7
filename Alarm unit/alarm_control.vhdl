library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alarm_control is
    Port (
        clk, rst          : in std_logic;
        sw_arm            : in std_logic;
        sw_manual_id      : in std_logic_vector(2 downto 0);
        sw_force_auth     : in std_logic;
        sw_force_intruder : in std_logic;
        
        motion_detected   : in std_logic;
        tamper_signal     : in std_logic;
        
        ir_rx_done        : in std_logic; 
        ir_rx_data        : in std_logic_vector(7 downto 0);
        
        uart_busy         : in std_logic;
        
        alm_auth, alm_unauth : out std_logic;
        
        ir_tx_start          : out std_logic;
        ir_tx_data           : out std_logic_vector(7 downto 0);
        
        uart_pc_start        : out std_logic;
        uart_pc_data         : out std_logic_vector(7 downto 0);
        
        lcd_msg_sel          : out std_logic_vector(2 downto 0);
        lcd_user_id          : out std_logic_vector(2 downto 0);
        led_mode             : out std_logic_vector(1 downto 0) 
    );
end alarm_control;

architecture Behavioral of alarm_control is
    type state_type is (DISARMED, IDLE, DETECTED, WAIT_RESPONSE, 
                        LOG_ID, LOG_H, LOG_H_W, LOG_M, LOG_M_W, LOG_S, LOG_S_W,
                        ALARM_ON, ALARM_OFF, TAMPER_ALARM);
    signal state : state_type := DISARMED;
    signal timer : integer range 0 to 500_000_000 := 0;
    
    constant TIMEOUT    : integer := 300_000_000; -- 3 sec
    constant AUTO_RESET : integer := 300_000_000; -- 3 sec
    
    signal clk_cnt : integer range 0 to 100_000_000 := 0;
    signal h : integer range 0 to 23 := 12;
    signal m, s : integer range 0 to 59 := 0;

begin
    -- 1. OUTPUT LOGIC (COMBINATIONAL)
    process(state)
    begin
        -- Defaults
        lcd_msg_sel <= "001"; -- Default to "System Armed"
        led_mode    <= "01";
        
        case state is
            when DISARMED => 
                lcd_msg_sel <= "000"; -- "System Disarmed"
                led_mode    <= "00";
                
            when IDLE | DETECTED | WAIT_RESPONSE => 
                lcd_msg_sel <= "001"; -- "System Armed..."
                led_mode    <= "01";
                
            when ALARM_ON => 
                lcd_msg_sel <= "010"; -- "INTRUDER ALERT"
                led_mode    <= "11";
                
            when TAMPER_ALARM =>
                lcd_msg_sel <= "100"; -- "Tampering Detect"
                led_mode    <= "11";
                
            when LOG_ID | LOG_H | LOG_H_W | LOG_M | LOG_M_W | LOG_S | LOG_S_W | ALARM_OFF =>
                -- Keep showing User ID during logging/success
                lcd_msg_sel <= "011"; 
                led_mode    <= "10";
                
            when others =>
                lcd_msg_sel <= "001";
                led_mode    <= "01";
        end case;
    end process;

    -- 2. TIME KEEPING
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then 
                clk_cnt<=0; h<=12; m<=0; s<=0;
            else
                if clk_cnt < 100_000_000 then 
                    clk_cnt <= clk_cnt + 1;
                else 
                    clk_cnt<=0;
                    if s<59 then s<=s+1; else s<=0;
                        if m<59 then m<=m+1; else m<=0;
                            if h<23 then h<=h+1; else h<=0; end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- 3. MAIN FSM
    process(clk)
        variable temp_id : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= DISARMED;
                alm_auth<='0'; alm_unauth<='0';
                ir_tx_start <= '0'; ir_tx_data <= (others => '0'); uart_pc_start <= '0';
            else
                ir_tx_start <= '0'; uart_pc_start <= '0';
                
                if sw_arm = '0' then
                    state <= DISARMED;
                    alm_auth <= '0';
                    alm_unauth <= '0';
                else
                    case state is
                        when DISARMED =>
                            state <= IDLE;

                        when IDLE =>
                            alm_auth<='0'; alm_unauth<='0';
                            if tamper_signal = '1' then
                                state <= TAMPER_ALARM;
                                timer <= 0;
                            elsif motion_detected='1' or sw_force_auth='1' or sw_force_intruder='1' then
                                state <= DETECTED;
                            end if;

                        when DETECTED =>
                            timer <= 0; state <= WAIT_RESPONSE;

                        when WAIT_RESPONSE =>
                            if sw_force_intruder='1' then state<=ALARM_ON;
                            elsif sw_force_auth='1' then
                                temp_id := "00000" & sw_manual_id;
                                alm_auth<='1'; 
                                lcd_user_id<=temp_id(2 downto 0); 
                                uart_pc_data<=std_logic_vector(to_unsigned(48+to_integer(unsigned(temp_id)),8));
                                uart_pc_start<='1'; state<=LOG_ID;
                            elsif timer < TIMEOUT then
                                timer <= timer + 1;
                                if ir_rx_done='1' then
                                    temp_id := ir_rx_data; 
                                    if unsigned(temp_id) < 8 then
                                        alm_auth<='1';
                                        lcd_user_id<=temp_id(2 downto 0); 
                                        uart_pc_data<=std_logic_vector(to_unsigned(48+to_integer(unsigned(temp_id)),8));
                                        uart_pc_start<='1'; state<=LOG_ID;
                                    end if;
                                end if;
                            else state <= ALARM_ON; timer <= 0; end if;

                        when LOG_ID => if uart_busy='0' then uart_pc_data<=std_logic_vector(to_unsigned(h,8)); uart_pc_start<='1'; state<=LOG_H_W; end if;
                        when LOG_H_W => if uart_busy='0' then uart_pc_data<=std_logic_vector(to_unsigned(m,8)); uart_pc_start<='1'; state<=LOG_M_W; end if;
                        when LOG_M_W => if uart_busy='0' then uart_pc_data<=std_logic_vector(to_unsigned(s,8)); uart_pc_start<='1'; state<=LOG_S_W; end if;
                        when LOG_S_W => if uart_busy='0' then state<=ALARM_OFF; end if;

                        when ALARM_ON =>
                            alm_unauth <= '1';
                            if timer < AUTO_RESET then timer <= timer + 1; else state <= IDLE; end if;

                        when TAMPER_ALARM =>
                            alm_unauth <= '1';
                            if tamper_signal = '1' then
                                timer <= 0;
                            elsif timer < AUTO_RESET then 
                                timer <= timer + 1;
                            else
                                state <= IDLE;
                            end if;

                        when ALARM_OFF =>
                            if timer < TIMEOUT then timer<=timer+1; else state<=IDLE; end if;
                        
                        when others => state <= IDLE;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;