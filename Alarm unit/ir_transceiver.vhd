library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ir_phys_layer is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        tx_data_in : in  std_logic; -- From UART TX (Serial Data)
        ir_tx_out  : out std_logic  -- To IR LED (Modulated at 38kHz)
    );
end ir_phys_layer;

architecture Behavioral of ir_phys_layer is
    -- 100MHz / 38kHz = ~2631 cycles. Half period ~= 1315
    constant CARRIER_PERIOD : integer := 2631;
    constant HALF_PERIOD    : integer := 1315;
    
    signal carrier_cnt : integer range 0 to CARRIER_PERIOD := 0;
    signal carrier_clk : std_logic := '0';
begin

    -- Generate 38kHz Carrier Clock
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                carrier_cnt <= 0;
                carrier_clk <= '0';
            else
                if carrier_cnt < CARRIER_PERIOD - 1 then
                    carrier_cnt <= carrier_cnt + 1;
                    if carrier_cnt < HALF_PERIOD then
                        carrier_clk <= '1';
                    else
                        carrier_clk <= '0';
                    end if;
                else
                    carrier_cnt <= 0;
                    carrier_clk <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Modulation Logic:
    -- UART '0' (Start/Data 0) -> Send 38kHz Carrier (Active)
    -- UART '1' (Idle/Data 1)  -> LED OFF (Idle)
    ir_tx_out <= carrier_clk when (tx_data_in = '0') else '0';

end Behavioral;