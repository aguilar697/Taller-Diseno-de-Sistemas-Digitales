set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk_i]

create_clock -add -name sys_clk_pin \
    -period 10.00 \
    -waveform {0 5} \
    [get_ports clk_i]

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst_i]

set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports rx_i]

set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports tx_o]
