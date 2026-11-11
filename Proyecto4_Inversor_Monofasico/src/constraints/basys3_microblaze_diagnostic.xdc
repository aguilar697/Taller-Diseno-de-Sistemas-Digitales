# Referencia: Digilent/digilent-xdc, Basys-3-Master.xdc.
# https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk_i]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports reset_i]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports UART_0_rxd]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports UART_0_txd]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_tri_i[0]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {GPIO2_0_tri_o[0]}]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Clocking Wizard aporta create_clock de 10 ns sobre clk_i. No duplicarlo aqui.
# Solo interfaces fisicas asincronas, no caminos internos del procesador:
# reset/boton/RX llegan a sincronizadores de sus IP (ver report_cdc).
# TX UART y LED no tienen reloj externo ni requisito de fase respecto a clk_i.
# Estas excepciones no aprueban CDC internos ni LUTAR-1/TIMING-9.
set_false_path -from [get_ports {reset_i UART_0_rxd GPIO_0_tri_i[0]}]
set_false_path -to [get_ports {UART_0_txd GPIO2_0_tri_o[0]}]
