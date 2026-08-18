create_clock -name clk -period 10.000 [get_ports clk]
set_input_delay -clock clk 1.000 [get_ports {start features_q8[*]}]
set_output_delay -clock clk 1.000 [get_ports {busy done prediction_v count_n[*] count_v[*] cycles_used[*]}]
