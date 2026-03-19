library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity accelerometer_driver is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        miso        : in  STD_LOGIC;
        mosi        : out STD_LOGIC;
        sclk        : out STD_LOGIC;
        cs_n        : out STD_LOGIC;
        movement_flag : out STD_LOGIC
    );
end accelerometer_driver;

architecture Behavioral of accelerometer_driver is
    type state_type is (INIT_START, LOAD_CMD, SPI_TX_RX, PROCESS_DATA, COOLDOWN);
    signal state : state_type := INIT_START;
    
    -- SPI Signals
    signal bit_cnt : integer range 0 to 23 := 0;
    signal shift_reg_tx : std_logic_vector(23 downto 0); 
    signal shift_reg_rx : std_logic_vector(7 downto 0);
    
    -- Clock Generation
    constant CLK_DIV_MAX : integer := 50; 
    signal clk_cnt : integer range 0 to CLK_DIV_MAX := 0;
    signal sclk_internal : std_logic := '0';
    
    -- Data Processing
    signal x_axis_reg : std_logic_vector(7 downto 0);
    signal x_prev     : std_logic_vector(7 downto 0);
    
    -- SENSITIVITY: Back to 15 (High Sensitivity)
    signal threshold  : integer := 15; 
    
    signal init_done  : std_logic := '0';
    signal cooldown_cnt : integer := 0;

begin
    sclk <= sclk_internal;

    process(clk, rst)
    begin
        if rst = '1' then
            state <= INIT_START;
            cs_n <= '1';
            mosi <= '0';
            sclk_internal <= '0';
            init_done <= '0';
            movement_flag <= '0';
            clk_cnt <= 0;
            cooldown_cnt <= 0;
        elsif rising_edge(clk) then
            case state is
                when INIT_START =>
                    sclk_internal <= '0';
                    cs_n <= '1';
                    if init_done = '0' then
                        shift_reg_tx <= x"0A2D02"; -- Enable Measurement
                    else
                        shift_reg_tx <= x"0B0800"; -- Read X-Data
                    end if;
                    state <= LOAD_CMD;

                when LOAD_CMD =>
                    bit_cnt <= 23;
                    cs_n <= '0'; 
                    clk_cnt <= 0;
                    sclk_internal <= '0';
                    mosi <= shift_reg_tx(23); 
                    state <= SPI_TX_RX;

                when SPI_TX_RX =>
                    if clk_cnt < CLK_DIV_MAX - 1 then
                        clk_cnt <= clk_cnt + 1;
                    else
                        clk_cnt <= 0;
                        if sclk_internal = '0' then
                            sclk_internal <= '1';
                            if bit_cnt < 8 then
                                shift_reg_rx <= shift_reg_rx(6 downto 0) & miso;
                            end if;
                        else
                            sclk_internal <= '0';
                            if bit_cnt > 0 then
                                bit_cnt <= bit_cnt - 1;
                                mosi <= shift_reg_tx(bit_cnt - 1);
                            else
                                state <= PROCESS_DATA;
                            end if;
                        end if;
                    end if;

                when PROCESS_DATA =>
                    cs_n <= '1'; 
                    if init_done = '0' then
                        init_done <= '1';
                    else
                        x_axis_reg <= shift_reg_rx;
                        -- Direct comparison (No sustain counter) = Instant Trigger
                        if abs(to_integer(unsigned(shift_reg_rx)) - to_integer(unsigned(x_prev))) > threshold then
                            movement_flag <= '1';
                        else
                            movement_flag <= '0';
                        end if;
                        x_prev <= shift_reg_rx;
                    end if;
                    state <= COOLDOWN;

                when COOLDOWN =>
                    if cooldown_cnt < 1000000 then -- 10ms sampling
                        cooldown_cnt <= cooldown_cnt + 1;
                    else
                        cooldown_cnt <= 0;
                        state <= INIT_START;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;