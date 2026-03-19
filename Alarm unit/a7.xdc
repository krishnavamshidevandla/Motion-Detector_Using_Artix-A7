## Nexys A7-100T Constraints for Alarm Unit
## LCD is mapped to JA + JB as per your specific file.
## Ultrasonic and IR are moved to JC and JD to avoid conflicts.

# ----------------------------------------------------------------------------
# Clock Signal
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK100MHZ }];

# ----------------------------------------------------------------------------
# Buttons & Reset
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { rst_btn }];
## Arming Switch (SW0)
## Arming Switch (SW0)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { sw_arm }];
## Manual User ID Selection (SW1, SW2, SW3)
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports { sw_manual_id[0] }];
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { sw_manual_id[1] }];
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { sw_manual_id[2] }];

## Force Success (SW14)
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { sw_force_auth }];

## Force Intruder (SW15)
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { sw_force_intruder }];
## Alive LED (Green LED 0)
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led_alive }];


# ============================================================================
# ACCELEROMETER (ADXL362)
# ============================================================================
## Chip Select (CS) - Pin D15
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { acl_csn }];

## SPI Clock (SCLK) - Pin F15
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { acl_sclk }];

## Master Out Slave In (MOSI) - Pin F14
set_property -dict { PACKAGE_PIN F14   IOSTANDARD LVCMOS33 } [get_ports { acl_mosi }];

## Master In Slave Out (MISO) - Pin E15
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { acl_miso }];

set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { sw_accel_en }];

## RGB LED 16 (Red Channel) -> Pin N15
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { led_red }];

## RGB LED 16 (Blue Channel) -> Pin R11
set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { led_blue }];

## RGB LED 16 (Green Channel) -> Pin M16 (Tied to 0 in VHDL)
set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports { led_green }];
#  LCD DISPLAY CONSTRAINTS (Custom Mapping from your file)
#  Uses PMOD JA (Top) and PMOD JB (Split)
# ============================================================================

## LCD Data High Nibble [7:4] -> PMOD JA Top Row
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[4] }]; # JA1
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[5] }]; # JA2
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[6] }]; # JA3
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[7] }]; # JA4

## LCD Data Low Nibble [3:0] & Controls -> PMOD JB
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[0] }]; # JB1
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[2] }]; # JB2
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[3] }]; # JB3
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { lcd_rw }];    # JB4
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { lcd_e }];     # JB7
set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { lcd_db[1] }]; # JB8
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { lcd_rs }];    # JB10

# ============================================================================
#  SENSORS & COMMS (Relocated to Free Ports)
# ============================================================================

## Ultrasonic Sensor -> Moved to PMOD JC (Top Row)
## Pin 1: Trigger, Pin 2: Echo
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { us_trigger }]; # JC1
set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { us_echo }];    # JC2

## IR Transceiver -> Moved to PMOD JD (Top Row)
## Pin 1: TX, Pin 2: RX
set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { ir_tx }];      # JD1
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { ir_rx }];      # JD2

## Audio Output (Mono Audio Out - Standard Port)
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { aud_pwm }]; 
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { aud_sd }];

## USB-UART Interface (For PC Logging)
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];


## 7-Segment Display Segments (CA to CG)
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { seg[0] }];
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { seg[1] }];
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { seg[2] }];
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { seg[3] }];
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { seg[4] }];
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { seg[5] }];
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { seg[6] }];

## 7-Segment Anodes (AN0 to AN7)
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { an[0] }];
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { an[1] }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { an[2] }];
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { an[3] }];
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { an[4] }];
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { an[5] }];
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { an[6] }];
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { an[7] }];


## DEBUG LEDs (LED 15 downto 8) - Shows Received IR Data
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[7] }]; # LED 15
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[6] }]; # LED 14
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[5] }]; # LED 13
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[4] }]; # LED 12
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[3] }]; # LED 11
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[2] }]; # LED 10
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[1] }]; # LED 9
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { led_debug_id[0] }]; # LED 8

## Temperature Sensor (I2C) - ADT7420
set_property -dict { PACKAGE_PIN C14   IOSTANDARD LVCMOS33 } [get_ports { tmp_scl }]; # I2C SCL
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { tmp_sda }]; # I2C SDA