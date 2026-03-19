library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity audio is
  port (
    clk        : in std_logic;
    rst        : in std_logic;
    alm_auth   : in std_logic; -- success
    alm_unauth : in std_logic; -- failure
    aud_pwm    : out std_logic;
    aud_sd     : out std_logic
  );
end entity;

architecture Behavioral of audio is

  constant CLK_FREQ : integer := 100_000_000;

  -- success tones
  constant FREQ_DING : integer := 1500;
  constant FREQ_DONG : integer := 2000;
  constant DING_MS   : integer := 120;
  constant DONG_MS   : integer := 160;

  -- fail tone
  constant FREQ_BEEP : integer := 2000;
  constant BEEP_MS   : integer := 3000;

  -- period counters
  signal half_period : integer   := 0;
  signal pwm_cnt     : integer   := 0;
  signal pwm_out     : std_logic := '0';

  -- duration counter
  signal dur_target : integer := 0;
  signal dur_cnt    : integer := 0;

  type sound_state_type is (
    IDLE,
    PLAY_DING,
    PLAY_DONG,
    PLAY_BEEP
  );
  signal sound_state : sound_state_type := IDLE;

  signal auth_prev   : std_logic := '0';
  signal unauth_prev : std_logic := '0';

begin
  aud_sd <= '1'; -- audio ON

  -- PWM generator
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pwm_cnt <= 0;
        pwm_out <= '0';
      else
        if pwm_cnt >= half_period then
          pwm_cnt <= 0;
          pwm_out <= not pwm_out;
        else
          pwm_cnt <= pwm_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  -- sound controller
  process (clk)
  begin
    if rising_edge(clk) then

      if rst = '1' then
        sound_state <= IDLE;
        dur_cnt     <= 0;
        auth_prev   <= '0';
        unauth_prev <= '0';

      else
        -- rising edge detect
        auth_prev   <= alm_auth;
        unauth_prev <= alm_unauth;

        case sound_state is

          when IDLE =>
            dur_cnt <= 0;

            -- priority: unauth > auth
            if (unauth_prev = '0' and alm_unauth = '1') then
              half_period <= CLK_FREQ / (FREQ_BEEP * 2);
              dur_target  <= (CLK_FREQ / 1000) * BEEP_MS;
              sound_state <= PLAY_BEEP;

            elsif (auth_prev = '0' and alm_auth = '1') then
              half_period <= CLK_FREQ / (FREQ_DING * 2);
              dur_target  <= (CLK_FREQ / 1000) * DING_MS;
              sound_state <= PLAY_DING;
            end if;

          when PLAY_DING =>
            if dur_cnt >= dur_target then
              dur_cnt     <= 0;
              half_period <= CLK_FREQ / (FREQ_DONG * 2);
              dur_target  <= (CLK_FREQ / 1000) * DONG_MS;
              sound_state <= PLAY_DONG;
            else
              dur_cnt <= dur_cnt + 1;
            end if;

          when PLAY_DONG =>
            if dur_cnt >= dur_target then
              sound_state <= IDLE;
              dur_cnt     <= 0;
            else
              dur_cnt <= dur_cnt + 1;
            end if;

          when PLAY_BEEP =>
            if dur_cnt >= dur_target then
              sound_state <= IDLE;
              dur_cnt     <= 0;
            else
              dur_cnt <= dur_cnt + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  aud_pwm <= pwm_out when sound_state /= IDLE else
    '0';

end architecture;
