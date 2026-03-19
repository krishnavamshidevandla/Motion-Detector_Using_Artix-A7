library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sevenseg_driver is
    Port (
        clk     : in std_logic;
        value   : in unsigned(15 downto 0);       -- Distance Value
        command : in std_logic_vector(1 downto 0); -- State Command
        seg     : out std_logic_vector(6 downto 0);
        an      : out std_logic_vector(7 downto 0) -- UPDATED to 8 Anodes
    );
end sevenseg_driver;

architecture Behavioral of sevenseg_driver is
    -- 20-bit counter. We use the top 3 bits for 8-digit selection.
    signal refresh_cnt : unsigned(19 downto 0) := (others => '0'); 
    signal digit_sel   : std_logic_vector(2 downto 0); -- 3 bits for 0-7
    
    signal hex_char    : std_logic_vector(4 downto 0); 
    
    -- Distance Digits
    signal dist0, dist1, dist2, dist3 : std_logic_vector(4 downto 0);
    
begin

    -- Break distance into BCD digits (0-9)
    dist0 <= std_logic_vector(resize(value mod 10, 5));          -- Ones
    dist1 <= std_logic_vector(resize((value/10) mod 10, 5));     -- Tens
    dist2 <= std_logic_vector(resize((value/100) mod 10, 5));    -- Hundreds
    dist3 <= std_logic_vector(resize((value/1000) mod 10, 5));   -- Thousands

    -- Refresh Counter
    process(clk)
    begin
        if rising_edge(clk) then
            refresh_cnt <= refresh_cnt + 1;
        end if;
    end process;
    
    -- Select current anode (bits 19 down to 17 gives good refresh rate for 8 digits)
    digit_sel <= std_logic_vector(refresh_cnt(19 downto 17));

    -- =========================================================================
    -- DIGIT MUX LOGIC
    -- Anodes 7-4: Show Distance
    -- Anodes 3-0: Show Command Text
    -- =========================================================================
    process(digit_sel, command, dist0, dist1, dist2, dist3)
    begin
        case digit_sel is
            -- === LEFT SIDE: DISTANCE ===
            when "111" => hex_char <= dist3; -- Anode 7 (Thousands)
            when "110" => hex_char <= dist2; -- Anode 6 (Hundreds)
            when "101" => hex_char <= dist1; -- Anode 5 (Tens)
            when "100" => hex_char <= dist0; -- Anode 4 (Ones)

            -- === RIGHT SIDE: STATUS TEXT ===
            -- We map the text based on the 'command' input
            when "011" => -- Anode 3 (Char 1)
                case command is
                    when "00" => hex_char <= "11111"; -- (Space)
                    when "01" => hex_char <= "10001"; -- I (IdLE)
                    when "10" => hex_char <= "01010"; -- A (AL-r)
                    when "11" => hex_char <= "10000"; -- P (PASS)
                    when others => hex_char <= "11111";
                end case;

            when "010" => -- Anode 2 (Char 2)
                case command is
                    when "00" => hex_char <= "11111"; -- (Space)
                    when "01" => hex_char <= "10011"; -- d (IdLE)
                    when "10" => hex_char <= "10101"; -- L (AL-r)
                    when "11" => hex_char <= "01010"; -- A (PASS)
                    when others => hex_char <= "11111";
                end case;

            when "001" => -- Anode 1 (Char 3)
                case command is
                    when "00" => hex_char <= "01101"; -- c (cm) -> Optional, or blank
                    when "01" => hex_char <= "10101"; -- L (IdLE)
                    when "10" => hex_char <= "11110"; -- - (AL-r)
                    when "11" => hex_char <= "00101"; -- S (PASS)
                    when others => hex_char <= "11111";
                end case;

            when "000" => -- Anode 0 (Char 4 - Rightmost)
                case command is
                    when "00" => hex_char <= "10000"; -- m (looks like inverted U/n mixed) or use 'n'
                    when "01" => hex_char <= "01110"; -- E (IdLE)
                    when "10" => hex_char <= "10100"; -- r (AL-r)
                    when "11" => hex_char <= "00101"; -- S (PASS)
                    when others => hex_char <= "11111";
                end case;
                
            when others => hex_char <= "11111";
        end case;
    end process;

    -- Anode Driver (Active Low)
    process(digit_sel)
    begin
        case digit_sel is
            when "000" => an <= "11111110"; -- Anode 0
            when "001" => an <= "11111101";
            when "010" => an <= "11111011";
            when "011" => an <= "11110111";
            when "100" => an <= "11101111";
            when "101" => an <= "11011111";
            when "110" => an <= "10111111";
            when "111" => an <= "01111111"; -- Anode 7
            when others => an <= "11111111";
        end case;
    end process;

    -- Character Decoder
    process(hex_char)
    begin
        case hex_char is
            -- Numbers 0-9
            when "00000" => seg <= "1000000"; -- 0
            when "00001" => seg <= "1111001"; -- 1
            when "00010" => seg <= "0100100"; -- 2
            when "00011" => seg <= "0110000"; -- 3
            when "00100" => seg <= "0011001"; -- 4
            when "00101" => seg <= "0010010"; -- 5 (S)
            when "00110" => seg <= "0000010"; -- 6
            when "00111" => seg <= "1111000"; -- 7
            when "01000" => seg <= "0000000"; -- 8
            when "01001" => seg <= "0010000"; -- 9
            
            -- Letters
            when "01010" => seg <= "0001000"; -- A
            when "01011" => seg <= "0000011"; -- b
            when "01100" => seg <= "1000110"; -- C
            when "01101" => seg <= "1011000"; -- c (cm)
            when "10011" => seg <= "0100001"; -- d
            when "01110" => seg <= "0000110"; -- E
            when "01111" => seg <= "0001110"; -- F
            when "10000" => seg <= "0001100"; -- P
            when "10001" => seg <= "1111001"; -- I (same as 1)
            when "10100" => seg <= "0101111"; -- r
            when "10101" => seg <= "1000111"; -- L
            when "11110" => seg <= "0111111"; -- - (Dash)
            when others   => seg <= "1111111"; -- Blank
        end case;
    end process;

end Behavioral;