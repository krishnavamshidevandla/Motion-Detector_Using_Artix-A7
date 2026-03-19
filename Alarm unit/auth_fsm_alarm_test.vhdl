library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity auth_fsm_alarm_test is
  port (
    clk             : in std_logic;
    rst             : in std_logic; -- synchronous reset
    alm_auth        : out std_logic; -- sound ON (success)
    alm_unauth      : out std_logic; -- sound ON (fail)
    person_detected : in std_logic; -- from ultrasonic
    auth_ok         : in std_logic -- from IR
  );
end auth_fsm_alarm_test;

architecture Behavioral of auth_fsm_alarm_test is

  type state_type is (IDLE, DETECTED, AUTH_OK_STATE, AUTH_FAIL);
  signal state, next_state : state_type := IDLE;

  constant CLK_FREQ     : integer := 100_000_000;
  constant WAIT_TIME_MS : integer := 3000; -- 3s
  constant WAIT_CYCLES  : integer := (CLK_FREQ / 1000) * WAIT_TIME_MS;

  signal wait_counter : integer range 0 to WAIT_CYCLES := 0;

begin
  -- state register
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state        <= IDLE;
        wait_counter <= 0;
      else
        state <= next_state;
        if state = DETECTED then
          if wait_counter < WAIT_CYCLES then
            wait_counter <= wait_counter + 1;
          end if;
        else
          wait_counter <= 0;
        end if;
      end if;
    end if;
  end process;

  -- next-state
  process (state, person_detected, auth_ok, wait_counter)
  begin
    next_state <= state;
    case state is
      when IDLE =>
        if person_detected = '1' then
          next_state <= DETECTED;
        else
          next_state <= IDLE;
        end if;

      when DETECTED =>
        if auth_ok = '1' then
          next_state <= AUTH_OK_STATE;
        elsif wait_counter >= WAIT_CYCLES then
          next_state <= AUTH_FAIL;
        else
          next_state <= DETECTED;
        end if;

      when AUTH_OK_STATE =>
        next_state <= IDLE;

      when AUTH_FAIL =>
        next_state <= IDLE;

    end case;
  end process;

  alm_auth <= '1' when state = AUTH_OK_STATE else
    '0';
  alm_unauth <= '1' when state = AUTH_FAIL else
    '0';

end architecture;