library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_driver_user_id is
    Port ( 
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        msg_sel  : in  STD_LOGIC_VECTOR(2 downto 0);
        user_id  : in  STD_LOGIC_VECTOR(2 downto 0);
        t_tens, t_ones, t_frac : in  STD_LOGIC_VECTOR(7 downto 0);
        lcd_rs   : out STD_LOGIC;
        lcd_rw   : out STD_LOGIC;
        lcd_e    : out STD_LOGIC;
        lcd_db   : out STD_LOGIC_VECTOR (7 downto 0)
    );
end lcd_driver_user_id;

architecture Behavioral of lcd_driver_user_id is
    type char_array is array (0 to 15) of std_logic_vector(7 downto 0);
    
    function str_to_slv(s : string) return char_array is
        variable temp : char_array;
    begin
        for i in 0 to 15 loop
            if i < s'length then
                temp(i) := std_logic_vector(to_unsigned(character'pos(s(s'low + i)), 8));
            else
                temp(i) := x"20"; 
            end if;
        end loop;
        return temp;
    end function;

    -- Message Table
    constant MSG_0 : char_array := str_to_slv("System Disarmed "); 
    constant MSG_1 : char_array := str_to_slv("System Armed... "); 
    constant MSG_2 : char_array := str_to_slv("INTRUDER ALERT! "); 
    constant MSG_3 : char_array := str_to_slv("User # Detected "); 
    constant MSG_4 : char_array := str_to_slv("Tampering Detect"); 
    constant MSG_TEMP_PREFIX : char_array := str_to_slv("Temp:           "); 

    signal current_msg : char_array;
    
    type state_type is (POWER_UP, INIT_CMD1, INIT_CMD2, INIT_CMD3, FUNC_SET, 
                        DISP_OFF, CLEAR_DISP, ENTRY_MODE, DISP_ON, 
                        WRITE_L1, MOV_L2, WRITE_L2, IDLE);
    signal current_state : state_type := POWER_UP;

    -- Timing
    constant DELAY_50MS  : integer := 5_000_000;
    constant DELAY_20MS  : integer := 2_000_000; 
    constant DELAY_100US : integer := 10_000;
    constant REFRESH_RATE : integer := 20_000_000; 

    signal timer         : integer range 0 to 5_000_000 := 0;
    signal refresh_timer : integer range 0 to 20_000_000 := 0;
    signal char_index    : integer range 0 to 16 := 0;
    
    -- State change detection
    signal msg_sel_prev : std_logic_vector(2 downto 0) := (others => '0');

begin
    lcd_rw <= '0';

    -- Combinational Message Selection
    process(msg_sel)
    begin
        case msg_sel is
            when "000" => current_msg <= MSG_0;
            when "001" => current_msg <= MSG_1;
            when "010" => current_msg <= MSG_2;
            when "011" => current_msg <= MSG_3;
            when "100" => current_msg <= MSG_4;
            when others => current_msg <= MSG_0;
        end case;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- CHECK FOR RESET OR IMMEDIATE STATE CHANGE
            -- If msg_sel changes, we don't want to wait for the timer.
            if reset = '1' or (msg_sel /= msg_sel_prev and current_state = IDLE) then
                if reset = '1' then 
                    current_state <= POWER_UP; 
                else 
                    -- CRITICAL FIX: Go to CLEAR_DISP to reset the cursor to Line 1
                    current_state <= CLEAR_DISP; 
                end if;
                
                timer <= 0;
                char_index <= 0;
                refresh_timer <= 0;
                lcd_e <= '0';
                msg_sel_prev <= msg_sel;
            else
                case current_state is
                    when POWER_UP => 
                        lcd_rs <= '0'; 
                        if timer < DELAY_50MS then timer <= timer + 1; else timer <= 0; current_state <= INIT_CMD1; end if;
                    when INIT_CMD1 => 
                        lcd_db <= x"30"; 
                        if timer < DELAY_20MS then timer <= timer + 1; if timer > 100 and timer < 20000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= INIT_CMD2; end if;
                    when INIT_CMD2 => 
                        lcd_db <= x"30"; 
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= INIT_CMD3; end if;
                    when INIT_CMD3 => 
                        lcd_db <= x"30"; 
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= FUNC_SET; end if;
                    when FUNC_SET => 
                        lcd_db <= x"38"; 
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= DISP_OFF; end if;
                    when DISP_OFF => 
                        lcd_db <= x"08"; 
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= CLEAR_DISP; end if;
                    when CLEAR_DISP => 
                        lcd_db <= x"01"; 
                        if timer < DELAY_20MS then timer <= timer + 1; if timer > 100 and timer < 20000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= ENTRY_MODE; end if;
                    when ENTRY_MODE => 
                        lcd_db <= x"06"; 
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= DISP_ON; end if;
                    when DISP_ON => 
                        lcd_db <= x"0C"; 
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; current_state <= WRITE_L1; char_index <= 0; end if;

                    when WRITE_L1 =>
                        lcd_rs <= '1'; 
                        if char_index >= 16 then current_state <= MOV_L2; timer <= 0;
                        else
                            if timer < DELAY_100US then timer <= timer + 1;
                                if (msg_sel = "011" and char_index = 5) then 
                                    lcd_db <= std_logic_vector(to_unsigned(48 + to_integer(unsigned(user_id)), 8));
                                else 
                                    lcd_db <= current_msg(char_index); 
                                end if;
                                if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if;
                            else timer <= 0; char_index <= char_index + 1; end if;
                        end if;

                    when MOV_L2 => 
                        lcd_rs <= '0'; lcd_db <= x"C0";
                        if timer < DELAY_100US then timer <= timer + 1; if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if; else timer <= 0; char_index <= 0; current_state <= WRITE_L2; end if;

                    when WRITE_L2 =>
                        lcd_rs <= '1'; 
                        if char_index >= 16 then current_state <= IDLE; refresh_timer <= 0;
                        else
                            if timer < DELAY_100US then timer <= timer + 1;
                                if char_index < 6 then lcd_db <= MSG_TEMP_PREFIX(char_index);
                                elsif char_index = 6 then lcd_db <= t_tens;
                                elsif char_index = 7 then lcd_db <= t_ones;
                                elsif char_index = 8 then lcd_db <= x"2E"; -- '.'
                                elsif char_index = 9 then lcd_db <= t_frac;
                                elsif char_index = 10 then lcd_db <= x"20"; -- Space
                                elsif char_index = 11 then lcd_db <= x"43"; -- 'C'
                                else lcd_db <= x"20"; end if;
                                if timer > 100 and timer < 5000 then lcd_e <= '1'; else lcd_e <= '0'; end if;
                            else timer <= 0; char_index <= char_index + 1; end if;
                        end if;

                    when IDLE =>
                        lcd_e <= '0'; lcd_rs <= '0'; lcd_db <= (others => '0');
                        
                        -- Auto-Refresh Loop
                        if refresh_timer < REFRESH_RATE then
                            refresh_timer <= refresh_timer + 1;
                        else
                            -- FIX: Jump to CLEAR_DISP, NOT WRITE_L1
                            -- This resets the cursor to the top left (0x00)
                            current_state <= CLEAR_DISP; 
                            char_index <= 0;
                            timer <= 0;
                        end if;

                    when others => current_state <= POWER_UP;
                end case;
            end if;
        end if;
    end process;
end Behavioral;