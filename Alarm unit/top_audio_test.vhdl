library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity top_audio_test is
  port (
    CLK100MHZ : in std_logic;
    rst       : in std_logic; -- synchronous reset

    person_detected : in std_logic; -- from ultrasonic
    auth_ok         : in std_logic; -- from IR

    AUD_PWM : out std_logic; -- audio speaker output
    AUD_SD  : out std_logic -- audio amplifier ON/OFF
  );
end top_audio_test;

architecture Structural of top_audio_test is

  signal alm_auth   : std_logic := '0';
  signal alm_unauth : std_logic := '0';

begin

  u_auth : entity work.auth_fsm_alarm_test
    port map
    (
      clk             => CLK100MHZ,
      rst             => rst,
      alm_auth        => alm_auth,
      alm_unauth      => alm_unauth,
      person_detected => person_detected,
      auth_ok         => auth_ok
    );

  u_audio : entity work.audio
    port map
    (
      clk        => CLK100MHZ,
      rst        => rst,
      alm_auth   => alm_auth,
      alm_unauth => alm_unauth,
      aud_pwm    => AUD_PWM,
      aud_sd     => AUD_SD
    );

end architecture;
