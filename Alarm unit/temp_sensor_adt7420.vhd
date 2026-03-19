library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity temp_sensor is
    Port ( 
        clk       : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        scl       : inout STD_LOGIC;
        sda       : inout STD_LOGIC;
        temp_tens : out STD_LOGIC_VECTOR(7 downto 0);
        temp_ones : out STD_LOGIC_VECTOR(7 downto 0);
        temp_frac : out STD_LOGIC_VECTOR(7 downto 0);
        temp_alert : out STD_LOGIC -- NEW: Alert output
    );
end temp_sensor;

architecture Behavioral of temp_sensor is
    signal reset_n      : STD_LOGIC;
    signal i2c_ena      : STD_LOGIC;
    signal i2c_addr     : STD_LOGIC_VECTOR(6 downto 0) := "1001011"; -- 0x4B
    signal i2c_rw       : STD_LOGIC;
    signal i2c_data_wr  : STD_LOGIC_VECTOR(7 downto 0);
    signal i2c_busy     : STD_LOGIC;
    signal i2c_data_rd  : STD_LOGIC_VECTOR(7 downto 0);
    signal i2c_ack_error: STD_LOGIC;
    
    type state_type is (IDLE, START, READ_MSB, READ_LSB, PROCESS_TEMP, WAIT_CYCLE);
    signal state        : state_type := IDLE;
    signal busy_prev    : STD_LOGIC := '0';
    signal busy_cnt     : integer range 0 to 3 := 0;
    signal temp_msb, temp_lsb : STD_LOGIC_VECTOR(7 downto 0);
    signal temp_raw     : signed(15 downto 0);
    signal temp_celsius : integer range -128 to 150;
    signal temp_decimal : integer range 0 to 9;
    signal read_counter : unsigned(25 downto 0) := (others => '0');
    signal start_read   : STD_LOGIC := '0';
    signal first_read   : STD_LOGIC := '1';

begin
    reset_n <= not rst;
    
    -- Ensure i2c_master entity is compiled in your project
    i2c_master_inst : entity work.i2c_master
        generic map(input_clk => 100_000_000, bus_clk => 100_000)
        port map(
            clk => clk, reset_n => reset_n, ena => i2c_ena, addr => i2c_addr,
            rw => i2c_rw, data_wr => i2c_data_wr, busy => i2c_busy,
            data_rd => i2c_data_rd, ack_error => i2c_ack_error, sda => sda, scl => scl
        );
    
    -- Periodic Read Trigger
    process(clk, rst)
    begin
        if rst = '1' then
            read_counter <= (others => '0'); start_read <= '0'; first_read <= '1';
        elsif rising_edge(clk) then
            read_counter <= read_counter + 1;
            if (first_read = '1' and read_counter = 100000) or (read_counter = 0) then 
                start_read <= '1'; first_read <= '0';
            else start_read <= '0'; end if;
        end if;
    end process;
    
    -- Sensor Reading State Machine
    process(clk, rst)
        variable wait_cnt : integer range 0 to 255 := 0;
    begin
        if rst = '1' then
            state <= IDLE; i2c_ena <= '0'; busy_prev <= '0'; busy_cnt <= 0;
            temp_msb <= x"00"; temp_lsb <= x"00"; wait_cnt := 0;
        elsif rising_edge(clk) then
            busy_prev <= i2c_busy;
            case state is
                when IDLE =>
                    i2c_ena <= '0'; busy_cnt <= 0; wait_cnt := 0;
                    if start_read = '1' and i2c_busy = '0' then state <= START; end if;
                when START =>
                    if wait_cnt < 20 then wait_cnt := wait_cnt + 1;
                    else busy_cnt <= 0; wait_cnt := 0; state <= READ_MSB; end if;
                when READ_MSB =>
                    i2c_ena <= '1'; i2c_rw <= '1';
                    if i2c_busy = '1' and busy_prev = '0' then busy_cnt <= 1; end if;
                    if busy_cnt >= 1 and i2c_busy = '0' and busy_prev = '1' then
                        temp_msb <= i2c_data_rd; busy_cnt <= 0; state <= READ_LSB;
                    end if;
                when READ_LSB =>
                    i2c_ena <= '1'; i2c_rw <= '1';
                    if i2c_busy = '1' and busy_prev = '0' then busy_cnt <= 1; end if;
                    if busy_cnt >= 1 and i2c_busy = '0' and busy_prev = '1' then
                        temp_lsb <= i2c_data_rd; i2c_ena <= '0'; busy_cnt <= 0; state <= PROCESS_TEMP;
                    end if;
                when PROCESS_TEMP =>
                    i2c_ena <= '0'; temp_raw <= signed(temp_msb & temp_lsb); state <= WAIT_CYCLE;
                when WAIT_CYCLE =>
                    i2c_ena <= '0'; state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Conversion and Alert Logic
    process(clk)
        variable temp_fixed : signed(31 downto 0);
        variable temp_int : integer;
        variable temp_abs : integer;
    begin
        if rising_edge(clk) then
            temp_fixed := resize(temp_raw * 10, 32);
            temp_int := to_integer(temp_fixed / 128);
            temp_celsius <= temp_int / 10;
            temp_decimal <= abs(temp_int mod 10);
            
            temp_abs := abs(temp_celsius);
            temp_tens <= std_logic_vector(to_unsigned(((temp_abs / 10) mod 10) + 48, 8));
            temp_ones <= std_logic_vector(to_unsigned((temp_abs mod 10) + 48, 8));
            temp_frac <= std_logic_vector(to_unsigned(temp_decimal + 48, 8));
            if temp_celsius < 0 then temp_tens <= x"2D"; end if; 

            -- NEW: Alert Logic
            if (temp_celsius < 10 or temp_celsius > 50) then
                temp_alert <= '1';
            else
                temp_alert <= '0';
            end if;
        end if;
    end process;
end Behavioral;