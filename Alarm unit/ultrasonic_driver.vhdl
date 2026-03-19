library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hcsr04_driver is
    Port (
        clk     : in  std_logic;  -- 100 MHz clock
        trig    : out std_logic;
        echo    : in  std_logic;
        echo_cycles : out unsigned(31 downto 0)
    );
end hcsr04_driver;

architecture Behavioral of hcsr04_driver is

    type state_type is (IDLE, TRIG_PULSE, WAIT_ECHO_HIGH, MEASURE_ECHO, WAIT_60MS);
    signal state : state_type := IDLE;

    signal trig_cnt       : unsigned(15 downto 0) := (others => '0');
    signal measure_cnt    : unsigned(31 downto 0) := (others => '0');
    signal wait_cnt       : unsigned(31 downto 0) := (others => '0');

    signal echo_s1, echo_s2 : std_logic := '0';

    signal echo_cycles_reg : unsigned(31 downto 0) := (others => '0');

begin
    echo_cycles <= echo_cycles_reg;

    -- Sync echo
    process(clk)
    begin
        if rising_edge(clk) then
            echo_s1 <= echo;
            echo_s2 <= echo_s1;
        end if;
    end process;

    -- Main FSM
    process(clk)
    begin
        if rising_edge(clk) then

            case state is

                -- Wait 60ms between measurements
                when IDLE =>
                    trig <= '0';
                    wait_cnt <= (others => '0');
                    state <= WAIT_60MS;

                when WAIT_60MS =>
                    wait_cnt <= wait_cnt + 1;
                    if wait_cnt = 6000000 then   -- 60 ms
                        trig_cnt <= (others => '0');
                        state <= TRIG_PULSE;
                    end if;

                when TRIG_PULSE =>
                    trig <= '1';
                    trig_cnt <= trig_cnt + 1;
                    if trig_cnt = 999 then  -- 10 µs pulse
                        trig <= '0';
                        state <= WAIT_ECHO_HIGH;
                    end if;

                when WAIT_ECHO_HIGH =>
                    if echo_s2 = '1' then
                        measure_cnt <= (others => '0');
                        state <= MEASURE_ECHO;
                    end if;

                when MEASURE_ECHO =>
                    if echo_s2 = '1' then
                        measure_cnt <= measure_cnt + 1;
                    else
                        echo_cycles_reg <= measure_cnt; -- Latch result
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

end Behavioral;