library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_level is
    Port (
        clk : in std_logic;
        echo   : in std_logic;
        trig   : out std_logic;

        Seg : out std_logic_vector(6 downto 0);
        AN  : out std_logic_vector(3 downto 0)
    );
end top_level;

architecture Behavioral of top_level is

    signal echo_cycles : unsigned(31 downto 0);
    signal distance_cm : unsigned(15 downto 0);

begin

    sensor_driver : entity work.hcsr04_driver
        port map (
            clk => clk,
            trig => trig,
            echo => echo,
            echo_cycles => echo_cycles
        );

    dist_calc : entity work.distance_calc
        port map (
            clk => clk,
            echo_cycles => echo_cycles,
            distance_cm => distance_cm
        );

    sevenseg : entity work.sevenseg_driver
        port map (
            clk => clk ,
            value => distance_cm,
            seg => seg,
            an => an
        );

end Behavioral;