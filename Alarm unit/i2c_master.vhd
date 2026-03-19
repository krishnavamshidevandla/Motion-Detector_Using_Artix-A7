library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    generic(
        input_clk : integer := 100_000_000;
        bus_clk   : integer := 400_000
    );
    port(
        clk       : in     STD_LOGIC;
        reset_n   : in     STD_LOGIC;
        ena       : in     STD_LOGIC;
        addr      : in     STD_LOGIC_VECTOR(6 downto 0);
        rw        : in     STD_LOGIC;
        data_wr   : in     STD_LOGIC_VECTOR(7 downto 0);
        busy      : out    STD_LOGIC;
        data_rd   : out    STD_LOGIC_VECTOR(7 downto 0);
        ack_error : buffer STD_LOGIC;
        sda       : inout  STD_LOGIC;
        scl       : inout  STD_LOGIC
    );
end i2c_master;

architecture logic of i2c_master is
    constant divider  : integer := (input_clk/bus_clk)/4;
    type machine is(ready, start, command, slv_ack1, wr, rd, slv_ack2, mstr_ack, stop);
    signal state      : machine;
    signal data_clk   : STD_LOGIC;
    signal data_clk_prev : STD_LOGIC;
    signal scl_clk    : STD_LOGIC;
    signal scl_ena    : STD_LOGIC := '0';
    signal sda_int    : STD_LOGIC := '1';
    signal sda_ena_n  : STD_LOGIC;
    signal addr_rw    : STD_LOGIC_VECTOR(7 downto 0);
    signal data_tx    : STD_LOGIC_VECTOR(7 downto 0);
    signal data_rx    : STD_LOGIC_VECTOR(7 downto 0);
    signal bit_cnt    : integer range 0 to 7 := 7;
    signal stretch    : STD_LOGIC := '0';
begin
    process(clk, reset_n)
        variable count  : integer range 0 to divider*4;
    begin
        if(reset_n = '0') then
            stretch <= '0';
            count := 0;
        elsif rising_edge(clk) then
            data_clk_prev <= data_clk;
            if(count = divider*4-1) then
                count := 0;
            elsif(stretch = '0') then
                count := count + 1;
            end if;
            case count is
                when 0 to divider-1 =>
                    scl_clk <= '0'; data_clk <= '0';
                when divider to divider*2-1 =>
                    scl_clk <= '0'; data_clk <= '1';
                when divider*2 to divider*3-1 =>
                    scl_clk <= '1';
                    if(scl = '0') then stretch <= '1'; else stretch <= '0'; end if;
                    data_clk <= '1';
                when others =>
                    scl_clk <= '1'; data_clk <= '0';
            end case;
        end if;
    end process;

    process(clk, reset_n)
    begin
        if(reset_n = '0') then
            state <= ready; busy <= '1'; scl_ena <= '0'; sda_int <= '1';
            ack_error <= '0'; bit_cnt <= 7; data_rd <= "00000000";
        elsif rising_edge(clk) then
            if(data_clk = '1' and data_clk_prev = '0') then
                case state is
                    when ready =>
                        if(ena = '1') then
                            busy <= '1'; addr_rw <= addr & rw; data_tx <= data_wr; state <= start;
                        else
                            busy <= '0'; state <= ready;
                        end if;
                    when start =>
                        busy <= '1'; sda_int <= addr_rw(bit_cnt); state <= command;
                    when command =>
                        if(bit_cnt = 0) then sda_int <= '1'; bit_cnt <= 7; state <= slv_ack1;
                        else bit_cnt <= bit_cnt - 1; sda_int <= addr_rw(bit_cnt-1); state <= command; end if;
                    when slv_ack1 =>
                        if(addr_rw(0) = '0') then sda_int <= data_tx(bit_cnt); state <= wr;
                        else sda_int <= '1'; state <= rd; end if;
                    when wr =>
                        busy <= '1';
                        if(bit_cnt = 0) then sda_int <= '1'; bit_cnt <= 7; state <= slv_ack2;
                        else bit_cnt <= bit_cnt - 1; sda_int <= data_tx(bit_cnt-1); state <= wr; end if;
                    when rd =>
                        busy <= '1';
                        if(bit_cnt = 0) then
                            if(ena = '1' and addr_rw = addr & rw) then sda_int <= '0'; else sda_int <= '1'; end if;
                            bit_cnt <= 7; data_rd <= data_rx; state <= mstr_ack;
                        else bit_cnt <= bit_cnt - 1; state <= rd; end if;
                    when slv_ack2 =>
                        if(ena = '1') then busy <= '0'; addr_rw <= addr & rw; data_tx <= data_wr;
                            if(addr_rw = addr & rw) then sda_int <= data_wr(bit_cnt); state <= wr;
                            else state <= start; end if;
                        else state <= stop; end if;
                    when mstr_ack =>
                        if(ena = '1') then busy <= '0'; addr_rw <= addr & rw; data_tx <= data_wr;
                            if(addr_rw = addr & rw) then sda_int <= '1'; state <= rd;
                            else state <= start; end if;    
                        else state <= stop; end if;
                    when stop => busy <= '0'; state <= ready;
                end case;    
            elsif(data_clk = '0' and data_clk_prev = '1') then
                case state is
                    when start => if(scl_ena = '0') then scl_ena <= '1'; ack_error <= '0'; end if;
                    when slv_ack1 => if(sda /= '0' or ack_error = '1') then ack_error <= '1'; end if;
                    when rd => data_rx(bit_cnt) <= sda;
                    when slv_ack2 => if(sda /= '0' or ack_error = '1') then ack_error <= '1'; end if;
                    when stop => scl_ena <= '0';
                    when others => null;
                end case;
            end if;
        end if;
    end process;  

    with state select sda_ena_n <= data_clk_prev when start, not data_clk_prev when stop, sda_int when others;
    scl <= '0' when (scl_ena = '1' and scl_clk = '0') else 'Z';
    sda <= '0' when sda_ena_n = '0' else 'Z';
end logic;