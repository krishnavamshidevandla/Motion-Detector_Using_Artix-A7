library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity distance_calc is
    Port (
        clk         : in std_logic;
        echo_cycles : in unsigned(31 downto 0);
        distance_cm : out unsigned(15 downto 0)
    );
end distance_calc;

architecture Behavioral of distance_calc is
    -- Multiplier for 100MHz clock. 
    -- 5800 cycles = 1cm. 
    -- We use (Cycles * 11305) / 2^26 approximation for better precision than simple division.
    constant MULTIPLIER : unsigned(15 downto 0) := to_unsigned(11305, 16);
    
    signal full_product : unsigned(47 downto 0);
    signal calc_cm      : unsigned(15 downto 0); 
    
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- High Precision Multiplication
            full_product <= echo_cycles * MULTIPLIER;
            
            -- Bit slice to perform the division by 2^26
            calc_cm <= resize(full_product(41 downto 26), 16);

            -- SIMPLIFIED FILTERING (More Sensitive)
            if calc_cm > 400 then
                distance_cm <= to_unsigned(400, 16); -- Max Range
            else
                -- Pass EVERYTHING else through. 
                -- Even 0cm or 1cm. Do not filter "noise" at the cost of sensitivity.
                distance_cm <= calc_cm;
            end if;
        end if;
    end process;
end Behavioral;