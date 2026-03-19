library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sevenseg_driver is
    Port (
        clk          : in  STD_LOGIC;
        number_in    : in  UNSIGNED(15 downto 0); -- Number to display
        cmd_mode     : in  STD_LOGIC_VECTOR(1 downto 0); -- 00=Normal/ID
        seg          : out STD_LOGIC_VECTOR(6 downto 0);
        an           : out STD_LOGIC_VECTOR(7 downto 0)
    );
end sevenseg_driver;

architecture Behavioral of sevenseg_driver is
    signal refresh_counter : unsigned(19 downto 0) := (others => '0');
    signal LED_activating_counter : std_logic_vector(2 downto 0);
    signal LED_BCD : std_logic_vector(3 downto 0);
    signal digit_0 : std_logic_vector(3 downto 0);
begin
    -- Extract lowest nibble (for ID)
    digit_0 <= std_logic_vector(number_in(3 downto 0));

    process(clk)
    begin
        if rising_edge(clk) then refresh_counter <= refresh_counter + 1; end if;
    end process;
    LED_activating_counter <= std_logic_vector(refresh_counter(19 downto 17));

    process(LED_activating_counter)
    begin
        an <= (others => '1'); -- Default off
        if LED_activating_counter = "000" then an <= "11111110"; end if; -- Turn on rightmost digit
    end process;

    process(LED_activating_counter, digit_0)
    begin
        if LED_activating_counter = "000" then LED_BCD <= digit_0; else LED_BCD <= "0000"; end if;
    end process;

    process(LED_BCD)
    begin
        case LED_BCD is
            when "0000" => seg <= "1000000"; -- 0
            when "0001" => seg <= "1111001"; -- 1
            when "0010" => seg <= "0100100"; -- 2
            when "0011" => seg <= "0110000"; -- 3
            when "0100" => seg <= "0011001"; -- 4
            when "0101" => seg <= "0010010"; -- 5
            when "0110" => seg <= "0000010"; -- 6
            when "0111" => seg <= "1111000"; -- 7
            when others => seg <= "1111111";
        end case;
    end process;
end Behavioral;