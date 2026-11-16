# Referencia: Digilent/digilent-xdc, Basys-3-Master.xdc.
# https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk_i]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports reset_i]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports UART_0_rxd]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports UART_0_txd]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {BUTTONS_tri_i[0]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {BUTTONS_tri_i[1]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {BUTTONS_tri_i[2]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {SWITCHES_tri_i[0]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {SWITCHES_tri_i[1]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {LEDS_tri_o[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {LEDS_tri_o[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {LEDS_tri_o[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {LEDS_tri_o[3]}]
# JA1 se reserva para observacion digital de ISR; JA2/3/4/7 quedan sin asignar.
set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports {ISR_DIAG_tri_o[0]}]
# VAUX6: JXADC1/JXADC7. LVCMOS33 no cambia el rango analogico del XADC.
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports vauxp6]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33} [get_ports vauxn6]
# PWM provisional en JC: exclusivamente validacion digital; no conectar potencia.
# Basys-3-Master.xdc oficial: JC1, JC2, JC3, JC4 y JC7, respectivamente.
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports pwm_ah]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports pwm_al]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports pwm_bh]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports pwm_bl]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports pwm_period_start_o]
# FIN PWM provisional
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Clocking Wizard aporta create_clock de 10 ns sobre clk_i. No duplicarlo aqui.
# Solo interfaces fisicas asincronas, no caminos internos del procesador:
# reset/boton/RX llegan a sincronizadores de sus IP (ver report_cdc).
# TX UART y LED no tienen reloj externo ni requisito de fase respecto a clk_i.
# Estas excepciones no aprueban CDC internos ni LUTAR-1/TIMING-9.
set_false_path -from [get_ports {reset_i UART_0_rxd}]
set_false_path -to [get_ports {UART_0_txd LEDS_tri_o[*] ISR_DIAG_tri_o[*]}]
# Botones/switches: revisar CDC de GPIO antes de prueba fisica; no excluir aqui.
# VAUX6 es analogico, no una entrada de datos sincronizada con el reloj AXI.
