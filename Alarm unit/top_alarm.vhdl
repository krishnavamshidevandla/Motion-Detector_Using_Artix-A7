library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity alarm_unit_top is
    Port (
        CLK100MHZ : in std_logic;
        rst_btn   : in std_logic;
        
        sw_arm            : in std_logic; -- SW0
        sw_manual_id      : in std_logic_vector(2 downto 0); -- SW1-3
        sw_accel_en       : in std_logic; -- SW13
        sw_force_auth     : in std_logic; -- SW14
        sw_force_intruder : in std_logic; -- SW15
        
        -- RGB LED Outputs
        led_alive : out std_logic;
        led_red, led_blue, led_green : out std_logic;
        
        -- Ultrasonic
        us_trigger : out std_logic; 
        us_echo    : in std_logic;
        
        -- Seven Segment & Audio
        seg : out std_logic_vector(6 downto 0);
        an  : out std_logic_vector(7 downto 0);
        aud_pwm, aud_sd : out std_logic;
        
        -- IR & UART
        ir_tx : out std_logic; ir_rx : in std_logic;
        uart_tx : out std_logic;
        
        -- LCD Controls
        lcd_rs, lcd_rw, lcd_e : out std_logic;
        lcd_db : out std_logic_vector(7 downto 0);
        
        -- DEBUG LEDs
        led_debug_id : out std_logic_vector(7 downto 0);

        -- TEMP SENSOR PORTS
        tmp_scl, tmp_sda : inout std_logic;
        
        -- ACCELEROMETER PORTS
        acl_miso : in std_logic;
        acl_mosi : out std_logic;
        acl_sclk : out std_logic;
        acl_csn  : out std_logic
    );
end alarm_unit_top;

architecture Structural of alarm_unit_top is

    signal sys_reset, motion_detected : std_logic;
    signal acl_motion, temp_alert_signal, combined_tamper : std_logic;
    signal lcd_sel, lcd_uid : std_logic_vector(2 downto 0);
    signal t_tens, t_ones, t_frac : std_logic_vector(7 downto 0);
    
    signal echo_cycles_raw : unsigned(31 downto 0);
    signal dist_cm_uns : unsigned(15 downto 0);
    signal seg_cmd, led_mode : std_logic_vector(1 downto 0);
    signal alm_auth, alm_unauth : std_logic;
    signal uart_pc_d : std_logic_vector(7 downto 0);
    signal uart_pc_s, uart_busy : std_logic;
    signal ir_auth_success, ir_auth_fail : std_logic;
    signal ir_personal_id_8bit, ir_id_to_ctrl : std_logic_vector(7 downto 0); 
    signal led_red_state, led_blue_state, ir_tx_internal, ir_auth_triggered : std_logic;

begin
    sys_reset <= NOT rst_btn; 

    -- ACCELEROMETER
    u_accel: entity work.accelerometer_driver port map (
        clk => CLK100MHZ, rst => sys_reset,
        miso => acl_miso, mosi => acl_mosi, sclk => acl_sclk, cs_n => acl_csn,
        movement_flag => acl_motion
    );

    -- TEMP SENSOR
    u_temp: entity work.temp_sensor port map (
        clk => CLK100MHZ, rst => sys_reset,
        scl => tmp_scl, sda => tmp_sda,
        temp_tens => t_tens, temp_ones => t_ones, temp_frac => t_frac,
        temp_alert => temp_alert_signal
    );

    -- COMBINE TAMPER SIGNALS
    combined_tamper <= (acl_motion AND sw_accel_en);

    -- CONTROL LOGIC
    u_ctrl: entity work.alarm_control port map(
        clk => CLK100MHZ, rst => sys_reset,
        sw_arm => sw_arm, sw_manual_id => sw_manual_id,
        sw_force_auth => sw_force_auth, sw_force_intruder => sw_force_intruder,
        motion_detected => motion_detected,
        tamper_signal => combined_tamper, 
        ir_rx_done => ir_auth_success, ir_rx_data => ir_id_to_ctrl, 
        uart_busy => uart_busy, alm_auth => alm_auth, alm_unauth => alm_unauth,
        uart_pc_start => uart_pc_s, uart_pc_data => uart_pc_d,
        lcd_msg_sel => lcd_sel, lcd_user_id => lcd_uid, led_mode => led_mode,
        ir_tx_start => open, ir_tx_data => open
    );

    -- LCD DRIVER
    u_lcd: entity work.lcd_driver_user_id port map(
        clk => CLK100MHZ, reset => sys_reset, 
        msg_sel => lcd_sel, user_id => lcd_uid, 
        t_tens => t_tens, t_ones => t_ones, t_frac => t_frac,
        lcd_rs => lcd_rs, lcd_rw => lcd_rw, lcd_e => lcd_e, lcd_db => lcd_db
    );

    -- REMAINING DRIVERS
    u_hcsr04: entity work.hcsr04_driver port map (CLK100MHZ, us_trigger, us_echo, echo_cycles_raw);
    u_calc: entity work.distance_calc port map (CLK100MHZ, echo_cycles_raw, dist_cm_uns);
    motion_detected <= '1' when (dist_cm_uns < 100 AND dist_cm_uns > 5) else '0';
    
    process(led_mode) begin
        case led_mode is
            when "00" => seg_cmd <= "01"; when "01" => seg_cmd <= "00"; 
            when "10" => seg_cmd <= "11"; when "11" => seg_cmd <= "10"; 
            when others => seg_cmd <= "00";
        end case;
    end process;
    U_SEVENSEG : entity work.sevenseg_driver port map (CLK100MHZ, dist_cm_uns, seg_cmd, seg, an);

    ir_auth_triggered <= motion_detected and sw_arm;
    u_ir_auth: entity work.top_ir_alarm port map (
        CLK100MHZ => CLK100MHZ, reset => sys_reset, triggered => ir_auth_triggered, 
        tx => ir_tx_internal, rx => ir_rx, personal_id => ir_personal_id_8bit,
        auth_success => ir_auth_success, auth_fail => ir_auth_fail
    );
    ir_tx <= ir_tx_internal;
    ir_id_to_ctrl <= "00000" & ir_personal_id_8bit(2 downto 0);

    u_leds: entity work.led_controller port map(CLK100MHZ, sys_reset, led_mode, led_alive, led_red_state, led_blue_state);
    u_aud: entity work.audio port map(CLK100MHZ, sys_reset, alm_auth, alm_unauth, aud_pwm, aud_sd);
    u_uart: entity work.uart_transceiver port map(CLK100MHZ, sys_reset, uart_pc_s, uart_pc_d, uart_busy, uart_tx, '1', open, open);

    led_red   <= led_red_state;
    led_green <= ir_tx_internal;
    led_blue  <= led_blue_state OR (NOT ir_rx);
    led_debug_id <= ir_personal_id_8bit;

end Structural;