library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_controller is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        mode       : in  std_logic_vector(1 downto 0); -- 00:Off, 01:Solid Red, 10:Blink Blue, 11:Fast Red
        led_alive  : out std_logic;
        led_red    : out std_logic;
        led_blue   : out std_logic
    );
end led_controller;

architecture Behavioral of led_controller is
    signal blink_cnt : integer range 0 to 50_000_000 := 0;
    signal alive_state : std_logic := '0';
    
    signal pattern_timer : integer range 0 to 50_000_000 := 0;
    -- FIXED: Variable name consistent
    signal blue_blink_cnt : integer range 0 to 7 := 0; 
    signal mode_prev : std_logic_vector(1 downto 0) := "00";
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                blink_cnt <= 0; alive_state <= '0';
                led_red <= '0'; led_blue <= '0';
                pattern_timer <= 0; blue_blink_cnt <= 0;
                mode_prev <= "00";
            else
                -- 1. Alive Heartbeat (1Hz)
                if blink_cnt < 50_000_000 then 
                    blink_cnt <= blink_cnt + 1;
                else 
                    blink_cnt <= 0; 
                    alive_state <= not alive_state; 
                end if;
                led_alive <= alive_state;

                -- 2. Status Pattern Logic
                if mode /= mode_prev then
                    pattern_timer <= 0;
                    blue_blink_cnt <= 0;
                    mode_prev <= mode;
                    led_red <= '0'; led_blue <= '0';
                else
                    case mode is
                        when "00" => -- DISARMED (OFF)
                            led_red <= '0'; led_blue <= '0';

                        when "01" => -- ARMED (SOLID RED)
                            led_red <= '1'; led_blue <= '0';

                        when "10" => -- SUCCESS (BLINK BLUE 3x)
                            if pattern_timer < 25_000_000 then led_blue <= '1';
                            else led_blue <= '0'; end if;

                            if pattern_timer < 50_000_000 then
                                pattern_timer <= pattern_timer + 1;
                            else
                                pattern_timer <= 0;
                                if blue_blink_cnt < 3 then blue_blink_cnt <= blue_blink_cnt + 1;
                                else led_blue <= '0'; end if; -- Stop after 3
                            end if;
                            led_red <= '0';

                        when "11" => -- INTRUDER (FAST RED BLINK)
                            if pattern_timer < 10_000_000 then led_red <= '1';
                            else led_red <= '0'; end if;

                            if pattern_timer < 20_000_000 then pattern_timer <= pattern_timer + 1;
                            else pattern_timer <= 0; end if;
                            led_blue <= '0';
                            
                        when others => led_red <= '0';
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;