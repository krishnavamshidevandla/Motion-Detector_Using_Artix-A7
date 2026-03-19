library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ultrasonic_ctrl is
    Port (
        clk         : in  std_logic;
        echo_pulse  : in  std_logic;
        trigger_out : out std_logic;
        motion_det  : out std_logic
    );
end ultrasonic_ctrl;

architecture Behavioral of ultrasonic_ctrl is
    constant CLK_FREQ     : integer := 100_000_000;
    -- Send trigger every 60ms
    constant TRIG_PERIOD  : integer := 6_000_000; 
    -- 10us trigger pulse
    constant TRIG_WIDTH   : integer := 1_000;     
    -- Threshold for "Motion" (e.g., < 50cm). ~2900 cycles per cm. 
    -- 50cm * 58us/cm * 100MHz = ~290,000 cycles
    constant DIST_THRESH  : integer := 290_000; 

    signal counter : integer range 0 to TRIG_PERIOD := 0;
    signal echo_cnt : integer := 0;
    signal measuring : boolean := false;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Trigger Generation
            if counter < TRIG_PERIOD then
                counter <= counter + 1;
            else
                counter <= 0;
            end if;

            if counter < TRIG_WIDTH then
                trigger_out <= '1';
            else
                trigger_out <= '0';
            end if;

            -- Echo Measurement
            if echo_pulse = '1' then
                echo_cnt <= echo_cnt + 1;
                measuring <= true;
            elsif measuring = true and echo_pulse = '0' then
                -- Echo finished, check distance
                if echo_cnt > 1000 and echo_cnt < DIST_THRESH then
                    motion_det <= '1'; -- Object is close
                else
                    motion_det <= '0';
                end if;
                echo_cnt <= 0;
                measuring <= false;
            else
                -- Idle or waiting for echo
                if counter = 0 then motion_det <= '0'; end if; -- Reset trigger
            end if;
        end if;
    end process;
end Behavioral;