## ============================================================
## Proyecto 3 - Batalla Naval
## Subsistema 2 - VGA + Entradas Jugador 1


## ============================================================
## CLOCK 100 MHz
## ============================================================

set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

create_clock -add -name sys_clk_pin \
    -period 10.00 \
    -waveform {0 5} \
    [get_ports clk]


## ============================================================
## SWITCHES
##
## SW0  -> SEL
## SW1  -> OK
## SW15 -> RUN / habilitacion del Subsistema 2
##
## SW15 = 0:
##     reset interno aplicado
##     Subsistema 2 inactivo
##     LED15 apagado
##
## SW15 = 1:
##     reset interno liberado
##     Subsistema 2 funcionando
##     LED15 encendido
##
## El reset interno sigue siendo activo en alto.
## La inversion se realiza en el top:
##
##     rst = ~sw[15] sincronizado mediante dos flip-flops a 100 MHz
##
## ============================================================

set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]

set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]

set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]

set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]

set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]

set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]

set_property PACKAGE_PIN W13 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]

set_property PACKAGE_PIN V2 [get_ports {sw[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[8]}]

set_property PACKAGE_PIN T3 [get_ports {sw[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[9]}]

set_property PACKAGE_PIN T2 [get_ports {sw[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[10]}]

set_property PACKAGE_PIN R3 [get_ports {sw[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[11]}]

set_property PACKAGE_PIN W2 [get_ports {sw[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[12]}]

set_property PACKAGE_PIN U1 [get_ports {sw[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[13]}]

set_property PACKAGE_PIN T1 [get_ports {sw[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[14]}]

set_property PACKAGE_PIN R2 [get_ports {sw[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[15]}]


## ============================================================
## LEDs
##
## LED0  -> UP       = BTNU
## LED1  -> DOWN     = BTND
## LED2  -> LEFT     = BTNL
## LED3  -> RIGHT    = BTNR
## LED4  -> SEL      = SW0
## LED5  -> OK       = SW1
## LED6  -> GAME_RST = BTNC
##
## LED7 ... LED13 -> reservados / apagados
##
## LED14 -> inicializacion de VRAM terminada
## LED15 -> Subsistema 2 habilitado / RUN
##
## ============================================================

set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]

set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]

set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

set_property PACKAGE_PIN V13 [get_ports {led[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[8]}]

set_property PACKAGE_PIN V3 [get_ports {led[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[9]}]

set_property PACKAGE_PIN W3 [get_ports {led[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[10]}]

set_property PACKAGE_PIN U3 [get_ports {led[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[11]}]

set_property PACKAGE_PIN P3 [get_ports {led[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[12]}]

set_property PACKAGE_PIN N3 [get_ports {led[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[13]}]

set_property PACKAGE_PIN P1 [get_ports {led[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[14]}]

set_property PACKAGE_PIN L1 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[15]}]


## ============================================================
## PUSH BUTTONS
##
## BTNU -> UP
## BTND -> DOWN
## BTNL -> LEFT
## BTNR -> RIGHT
## BTNC -> GAME_RST
## ============================================================

## BTNC -> GAME_RST
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## BTNU -> UP
set_property PACKAGE_PIN T18 [get_ports btnU]
set_property IOSTANDARD LVCMOS33 [get_ports btnU]

## BTNL -> LEFT
set_property PACKAGE_PIN W19 [get_ports btnL]
set_property IOSTANDARD LVCMOS33 [get_ports btnL]

## BTNR -> RIGHT
set_property PACKAGE_PIN T17 [get_ports btnR]
set_property IOSTANDARD LVCMOS33 [get_ports btnR]

## BTND -> DOWN
set_property PACKAGE_PIN U17 [get_ports btnD]
set_property IOSTANDARD LVCMOS33 [get_ports btnD]


## ============================================================
## VGA CONNECTOR
##
## RGB de 12 bits:
## 4 bits rojo
## 4 bits verde
## 4 bits azul
## ============================================================


## ------------------------------------------------------------
## RED
## ------------------------------------------------------------

set_property PACKAGE_PIN G19 [get_ports {vgaRed[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[0]}]

set_property PACKAGE_PIN H19 [get_ports {vgaRed[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[1]}]

set_property PACKAGE_PIN J19 [get_ports {vgaRed[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[2]}]

set_property PACKAGE_PIN N19 [get_ports {vgaRed[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[3]}]


## ------------------------------------------------------------
## BLUE
## ------------------------------------------------------------

set_property PACKAGE_PIN N18 [get_ports {vgaBlue[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[0]}]

set_property PACKAGE_PIN L18 [get_ports {vgaBlue[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[1]}]

set_property PACKAGE_PIN K18 [get_ports {vgaBlue[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[2]}]

set_property PACKAGE_PIN J18 [get_ports {vgaBlue[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[3]}]


## ------------------------------------------------------------
## GREEN
## ------------------------------------------------------------

set_property PACKAGE_PIN J17 [get_ports {vgaGreen[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[0]}]

set_property PACKAGE_PIN H17 [get_ports {vgaGreen[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[1]}]

set_property PACKAGE_PIN G17 [get_ports {vgaGreen[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[2]}]

set_property PACKAGE_PIN D17 [get_ports {vgaGreen[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[3]}]


## ------------------------------------------------------------
## VGA SYNC
## ------------------------------------------------------------

set_property PACKAGE_PIN P19 [get_ports Hsync]
set_property IOSTANDARD LVCMOS33 [get_ports Hsync]

set_property PACKAGE_PIN R19 [get_ports Vsync]
set_property IOSTANDARD LVCMOS33 [get_ports Vsync]


## ============================================================
## PERIFERICOS NO UTILIZADOS EN ESTA PRUEBA
##
## Permanecen deshabilitados para evitar restricciones sobre
## puertos que no existen en subsystem2_basys3_test_top.
## ============================================================


## ------------------------------------------------------------
## 7-SEGMENT DISPLAY - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]

#set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]

#set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]

#set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]

#set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]

#set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]

#set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

#set_property PACKAGE_PIN V7 [get_ports dp]
#set_property IOSTANDARD LVCMOS33 [get_ports dp]

#set_property PACKAGE_PIN U2 [get_ports {an[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]

#set_property PACKAGE_PIN U4 [get_ports {an[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]

#set_property PACKAGE_PIN V4 [get_ports {an[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]

#set_property PACKAGE_PIN W4 [get_ports {an[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]


## ------------------------------------------------------------
## PMOD JA - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN J1 [get_ports {JA[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[0]}]

#set_property PACKAGE_PIN L2 [get_ports {JA[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[1]}]

#set_property PACKAGE_PIN J2 [get_ports {JA[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[2]}]

#set_property PACKAGE_PIN G2 [get_ports {JA[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[3]}]

#set_property PACKAGE_PIN H1 [get_ports {JA[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[4]}]

#set_property PACKAGE_PIN K2 [get_ports {JA[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[5]}]

#set_property PACKAGE_PIN H2 [get_ports {JA[6]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[6]}]

#set_property PACKAGE_PIN G3 [get_ports {JA[7]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JA[7]}]


## ------------------------------------------------------------
## PMOD JB - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN A14 [get_ports {JB[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[0]}]

#set_property PACKAGE_PIN A16 [get_ports {JB[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[1]}]

#set_property PACKAGE_PIN B15 [get_ports {JB[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[2]}]

#set_property PACKAGE_PIN B16 [get_ports {JB[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[3]}]

#set_property PACKAGE_PIN A15 [get_ports {JB[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[4]}]

#set_property PACKAGE_PIN A17 [get_ports {JB[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[5]}]

#set_property PACKAGE_PIN C15 [get_ports {JB[6]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[6]}]

#set_property PACKAGE_PIN C16 [get_ports {JB[7]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JB[7]}]


## ------------------------------------------------------------
## PMOD JC - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN K17 [get_ports {JC[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[0]}]

#set_property PACKAGE_PIN M18 [get_ports {JC[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[1]}]

#set_property PACKAGE_PIN N17 [get_ports {JC[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[2]}]

#set_property PACKAGE_PIN P18 [get_ports {JC[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[3]}]

#set_property PACKAGE_PIN L17 [get_ports {JC[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[4]}]

#set_property PACKAGE_PIN M19 [get_ports {JC[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[5]}]

#set_property PACKAGE_PIN P17 [get_ports {JC[6]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[6]}]

#set_property PACKAGE_PIN R18 [get_ports {JC[7]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JC[7]}]


## ------------------------------------------------------------
## JXADC - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN J3 [get_ports {JXADC[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[0]}]

#set_property PACKAGE_PIN L3 [get_ports {JXADC[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[1]}]

#set_property PACKAGE_PIN M2 [get_ports {JXADC[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[2]}]

#set_property PACKAGE_PIN N2 [get_ports {JXADC[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[3]}]

#set_property PACKAGE_PIN K3 [get_ports {JXADC[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[4]}]

#set_property PACKAGE_PIN M3 [get_ports {JXADC[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[5]}]

#set_property PACKAGE_PIN M1 [get_ports {JXADC[6]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[6]}]

#set_property PACKAGE_PIN N1 [get_ports {JXADC[7]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {JXADC[7]}]


## ------------------------------------------------------------
## USB UART - NO UTILIZADO EN ESTA PRUEBA
## ------------------------------------------------------------

#set_property PACKAGE_PIN B18 [get_ports RsRx]
#set_property IOSTANDARD LVCMOS33 [get_ports RsRx]

#set_property PACKAGE_PIN A18 [get_ports RsTx]
#set_property IOSTANDARD LVCMOS33 [get_ports RsTx]


## ------------------------------------------------------------
## USB HID / PS2 - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN C17 [get_ports PS2Clk]
#set_property IOSTANDARD LVCMOS33 [get_ports PS2Clk]
#set_property PULLUP true [get_ports PS2Clk]

#set_property PACKAGE_PIN B17 [get_ports PS2Data]
#set_property IOSTANDARD LVCMOS33 [get_ports PS2Data]
#set_property PULLUP true [get_ports PS2Data]


## ------------------------------------------------------------
## QUAD SPI FLASH - NO UTILIZADO
## ------------------------------------------------------------

#set_property PACKAGE_PIN D18 [get_ports {QspiDB[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {QspiDB[0]}]

#set_property PACKAGE_PIN D19 [get_ports {QspiDB[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {QspiDB[1]}]

#set_property PACKAGE_PIN G18 [get_ports {QspiDB[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {QspiDB[2]}]

#set_property PACKAGE_PIN F18 [get_ports {QspiDB[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {QspiDB[3]}]

#set_property PACKAGE_PIN K19 [get_ports QspiCSn]
#set_property IOSTANDARD LVCMOS33 [get_ports QspiCSn]
