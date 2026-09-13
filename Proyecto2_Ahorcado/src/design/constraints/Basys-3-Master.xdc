## Restricciones para top.sv -- Sistema Ahorcado completo
## Pines verificados contra Digilent/digilent-xdc/Basys-3-Master.xdc
## y contra el PmodCLP Reference Manual (Tabla 1).

## Reloj
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk_i]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk_i]

## Botones
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btn_rst_i]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports btn_sel_i]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports btn_ok_i]

## UART (puente USB-UART integrado, mismo puerto que la programacion)
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports uart_rx_i]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o]

## Display de 7 segmentos
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports {seg_o[0]}]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {seg_o[1]}]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports {seg_o[2]}]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports {seg_o[3]}]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {seg_o[4]}]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {seg_o[5]}]
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports {seg_o[6]}]
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {an_o[0]}]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {an_o[1]}]
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {an_o[2]}]
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {an_o[3]}]

## LEDs de estado (solo se usan led_estado_o[1:0])
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led_estado_o[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led_estado_o[1]}]

## Buzzer -- Pmod libre, ejemplo con JA[0]. Ajustar segun tu circuito
## real (transistor/resistencia si tu buzzer lo requiere).
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports buzzer_o]

## ============================================================
## LCD PmodCLP -- mapeo confirmado contra el PmodCLP Reference Manual
## (Tabla 1: J1 = bus de datos de 8 bits; J2 pines 1/2/3 = RS/R-W/E).
## Conectar el cable J1 del modulo al puerto JB de la Basys 3, y el
## cable J2 al puerto JC.
## ============================================================
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[0]}]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[1]}]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[2]}]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[3]}]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[4]}]
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[5]}]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[6]}]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports {lcd_db_o[7]}]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports lcd_rs_o]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports lcd_rw_o]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports lcd_e_o]
## Nota: si el texto sale desordenado (caracteres correctos pero en
## posiciones/valores raros), el bus de datos puede estar invertido;
## probar intercambiando lcd_db_o[0]<->[7], [1]<->[6], etc.

## Configuracion general (recomendada por Digilent para todos los diseños)
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
