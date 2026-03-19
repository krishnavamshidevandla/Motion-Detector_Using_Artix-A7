library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pulse_stretcher is
    Port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        sig_in  : in  std_logic; -- Raw IR Input (Active Low)
        sig_out : out std_logic  -- Stretched Output (Active Low)
    );
end pulse_stretcher;

architecture Behavioral of pulse_stretcher is
    -- Stretch for 50us (5000 cycles @ 100MHz)
    -- This is safe for 9600 baud (104us bit width)
    constant STRETCH_CYCLES : integer := 5000;
    signal timer : integer range 0 to STRETCH_CYCLES := 0;
    signal stretching : std_logic := '0';
    signal in_sync : std_logic_vector(1 downto 0) := "11";
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Sync input to avoid metastability
            in_sync <= in_sync(0) & sig_in;

            if rst = '1' then
                stretching <= '0';
                timer <= 0;
                sig_out <= '1'; -- Idle High
            else
                if stretching = '0' then
                    -- Detect Falling Edge (Start of IR Pulse)
                    if in_sync = "10" or in_sync = "00" then 
                        stretching <= '1';
                        timer <= STRETCH_CYCLES;
                        sig_out <= '0'; -- Drive Output Low
                    else
                        sig_out <= '1'; -- Idle High
                    end if;
                else
                    -- Hold Low
                    if timer > 0 then
                        timer <= timer - 1;
                        sig_out <= '0';
                    else
                        stretching <= '0';
                        sig_out <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;