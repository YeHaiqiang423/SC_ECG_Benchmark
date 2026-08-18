`timescale 1ns/1ps
module tb_sc_nv_classifier;
`ifdef ARCH_1
    localparam integer ARCH = 1;
`elsif ARCH_2
    localparam integer ARCH = 2;
`elsif ARCH_3
    localparam integer ARCH = 3;
`elsif ARCH_4
    localparam integer ARCH = 4;
`elsif ARCH_5
    localparam integer ARCH = 5;
`elsif ARCH_6
    localparam integer ARCH = 6;
`elsif ARCH_7
    localparam integer ARCH = 7;
`elsif ARCH_8
    localparam integer ARCH = 8;
`else
    localparam integer ARCH = 0;
`endif
`ifdef ADAPTIVE_ON
    localparam integer ADAPTIVE = 1;
`else
    localparam integer ADAPTIVE = 0;
`endif
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start = 1'b0;
    logic [255:0] features_q8;
    logic [351:0] feature_thresholds;
    logic busy;
    logic done;
    logic prediction_v;
    logic [14:0] count_n;
    logic [14:0] count_v;
    logic [10:0] cycles_used;

    logic [255:0] feature_memory [0:99];
    logic expected_prediction [0:99];
    logic [14:0] expected_count_n [0:99];
    logic [14:0] expected_count_v [0:99];
    logic [10:0] expected_stop_cycle [0:99];
    integer sample_index;
    integer timeout_cycles;
    integer errors;

    always #5 clk = ~clk;

    sc_nv_classifier #(.ARCH(ARCH), .ADAPTIVE(ADAPTIVE)) dut (
        .clk, .rst, .start, .features_q8, .feature_thresholds, .busy, .done,
        .prediction_v, .count_n, .count_v, .cycles_used
    );

    initial begin
        $readmemh("fpga/memory/features_100.mem", feature_memory);
        if (ADAPTIVE != 0) begin
            $readmemh("fpga/memory/o11_adaptive_prediction.mem", expected_prediction);
            $readmemh("fpga/memory/o11_adaptive_stop_cycle.mem", expected_stop_cycle);
        end else begin
            case (ARCH)
                0: begin
                    $readmemh("fpga/memory/b1_independent_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/b1_independent_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/b1_independent_count_v.mem", expected_count_v);
                end
                1: begin
                    $readmemh("fpga/memory/b2_shared_xor_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/b2_shared_xor_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/b2_shared_xor_count_v.mem", expected_count_v);
                end
                2: begin
                    $readmemh("fpga/memory/o1_circular_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/o1_circular_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/o1_circular_count_v.mem", expected_count_v);
                end
                3: begin
                    $readmemh("fpga/memory/o3_ibd_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/o3_ibd_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/o3_ibd_count_v.mem", expected_count_v);
                end
                4: begin
                    $readmemh("fpga/memory/o2_pair_permutation_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/o2_pair_permutation_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/o2_pair_permutation_count_v.mem", expected_count_v);
                end
                5: begin
                    $readmemh("fpga/memory/o4_cape_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/o4_cape_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/o4_cape_count_v.mem", expected_count_v);
                end
                6: begin
                    $readmemh("fpga/memory/o5_sbong_hw_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/o5_sbong_hw_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/o5_sbong_hw_count_v.mem", expected_count_v);
                end
                7: begin
                    $readmemh("fpga/memory/o8_margin_pool2_prediction.mem", expected_prediction);
                    $readmemh("fpga/memory/o8_margin_pool2_count_n.mem", expected_count_n);
                    $readmemh("fpga/memory/o8_margin_pool2_count_v.mem", expected_count_v);
                end
                default: $readmemh("fpga/memory/q8_prediction_100.mem", expected_prediction);
            endcase
        end

        repeat (4) @(posedge clk);
        rst <= 1'b0;
        errors = 0;
        for (sample_index = 0; sample_index < 100; sample_index = sample_index + 1) begin
            @(negedge clk);
            features_q8 <= feature_memory[sample_index];
            for (integer threshold_index = 0; threshold_index < 32; threshold_index = threshold_index + 1)
                feature_thresholds[threshold_index*11 +: 11] <= calculate_threshold(
                    $signed(feature_memory[sample_index][threshold_index*8 +: 8]));
            start <= 1'b1;
            @(negedge clk);
            start <= 1'b0;
            timeout_cycles = 0;
            while (!done && timeout_cycles < 1300) begin
                @(posedge clk);
                timeout_cycles = timeout_cycles + 1;
            end
            if (!done) begin
                $display("TIMEOUT sample=%0d arch=%0d", sample_index, ARCH);
                errors = errors + 1;
            end else begin
                if (prediction_v !== expected_prediction[sample_index]) begin
                    $display("PRED_MISMATCH sample=%0d got=%0d expected=%0d", sample_index,
                        prediction_v, expected_prediction[sample_index]);
                    errors = errors + 1;
                end
                if (ADAPTIVE != 0) begin
                    if (cycles_used !== expected_stop_cycle[sample_index]) begin
                        $display("STOP_MISMATCH sample=%0d got=%0d expected=%0d", sample_index,
                            cycles_used, expected_stop_cycle[sample_index]);
                        errors = errors + 1;
                    end
                end else if (ARCH < 8) begin
                    if (count_n !== expected_count_n[sample_index] ||
                        count_v !== expected_count_v[sample_index]) begin
                        $display("COUNT_MISMATCH sample=%0d N=%0d/%0d V=%0d/%0d", sample_index,
                            count_n, expected_count_n[sample_index], count_v, expected_count_v[sample_index]);
                        errors = errors + 1;
                    end
                end
            end
        end
        if (errors == 0)
            $display("RTL_100_BEAT_PASS arch=%0d adaptive=%0d", ARCH, ADAPTIVE);
        else
            $fatal(1, "RTL_100_BEAT_FAIL arch=%0d adaptive=%0d errors=%0d", ARCH, ADAPTIVE, errors);
        $finish;
    end

    function automatic [10:0] calculate_threshold(input logic signed [7:0] value);
        integer shifted;
        integer numerator;
        begin
            shifted = $signed(value) + 127;
            numerator = shifted * 1024 + 127;
            calculate_threshold = numerator / 254;
        end
    endfunction
endmodule
