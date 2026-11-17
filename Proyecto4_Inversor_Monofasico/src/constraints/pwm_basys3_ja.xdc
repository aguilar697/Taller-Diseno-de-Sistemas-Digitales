# Salidas PWM en JA de Basys 3. Los nombres deben coincidir con el top.
# Fuente: https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports pwm_ah]
set_property -dict {PACKAGE_PIN L2 IOSTANDARD LVCMOS33} [get_ports pwm_al]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports pwm_bh]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports pwm_bl]
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports pwm_period_start_o]
