`timescale 1ns/1ps

module sc_nv_classifier #(
    parameter integer ARCH = 0,
    parameter integer ADAPTIVE = 0,
    parameter TEMPLATE_N_FILE = "fpga/memory/template_n.mem",
    parameter TEMPLATE_V_FILE = "fpga/memory/template_v.mem"
) (
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [255:0] features_q8,
    input  logic [351:0] feature_thresholds,
    output logic         busy,
    output logic         done,
    output logic         prediction_v,
    output logic [14:0]  count_n,
    output logic [14:0]  count_v,
    output logic [10:0]  cycles_used
);
    localparam integer DIM = 32;
    localparam integer STREAM_LENGTH = 1023;

    logic signed [7:0] template_n [0:DIM-1];
    logic signed [7:0] template_v [0:DIM-1];
    logic [9:0] lfsr_state [0:95];
    logic [9:0] pool_state [0:3];
    logic [9:0] base_state;
    logic [11:0] sbong_lfsr;
    logic [11:0] sbong_state;
    logic [19:0] cape_counter;
    logic delay_pipe [0:95][0:94];
    logic raw_bits [0:95];
    logic source_bits [0:95];
    logic cape_source_pipe [0:95];
    logic scoring_bits [0:95];
    logic cape_source_valid;
    logic [10:0] cycle_index;
    logic [10:0] accumulated_count;
    logic [6:0] warmup_remaining;
    logic [5:0] ones_n;
    logic [5:0] ones_v;
    logic [5:0] ones_n_pipe;
    logic [5:0] ones_v_pipe;
    logic       ones_valid_pipe;
    logic       adaptive_check_pending;
    logic signed [15:0] adaptive_margin_reg;
    logic [10:0] adaptive_cycle_reg;
    logic product_n [0:31];
    logic product_v [0:31];
    logic [1:0] pop_n_l1 [0:15];
    logic [1:0] pop_v_l1 [0:15];
    logic [2:0] pop_n_l2 [0:7];
    logic [2:0] pop_v_l2 [0:7];
    logic [3:0] pop_n_l3 [0:3];
    logic [3:0] pop_v_l3 [0:3];
    logic [4:0] pop_n_l4 [0:1];
    logic [4:0] pop_v_l4 [0:1];

    integer comb_d;
    integer comb_c;
    integer q8_d;
    integer pop_i;
    integer seq_c;
    integer seq_s;
    initial begin
        $readmemh(TEMPLATE_N_FILE, template_n);
        $readmemh(TEMPLATE_V_FILE, template_v);
    end

    function automatic [9:0] lfsr10_next(input [9:0] state);
        lfsr10_next = {state[8:0], state[9] ^ state[6]};
    endfunction

    function automatic [11:0] lfsr12_next(input [11:0] state);
        lfsr12_next = {state[10:0], state[11] ^ state[10] ^ state[9] ^ state[3]};
    endfunction

    function automatic [10:0] threshold(input logic signed [7:0] value);
        integer shifted;
        integer correction;
        begin
            shifted = $signed(value) + 127;
            if      (shifted <  16) correction = 0;
            else if (shifted <  48) correction = 1;
            else if (shifted <  80) correction = 2;
            else if (shifted < 112) correction = 3;
            else if (shifted < 143) correction = 4;
            else if (shifted < 175) correction = 5;
            else if (shifted < 207) correction = 6;
            else if (shifted < 239) correction = 7;
            else                    correction = 8;
            threshold = (shifted << 2) + correction;
        end
    endfunction

    function automatic [9:0] rotl10(input [9:0] value, input integer amount);
        integer k;
        begin
            k = amount % 10;
            if (k == 0) rotl10 = value;
            else rotl10 = (value << k) | (value >> (10-k));
        end
    endfunction

    function automatic [11:0] rotl12(input [11:0] value, input integer amount);
        integer k;
        begin
            k = amount % 12;
            if (k == 0) rotl12 = value;
            else rotl12 = (value << k) | (value >> (12-k));
        end
    endfunction

    function automatic [9:0] reverse10(input [9:0] value);
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1)
                reverse10[i] = value[9-i];
        end
    endfunction

    function automatic [3:0] sbong_sbox(input [3:0] value);
        begin
            case (value)
                4'h0: sbong_sbox=4'h6; 4'h1: sbong_sbox=4'hB;
                4'h2: sbong_sbox=4'h5; 4'h3: sbong_sbox=4'h4;
                4'h4: sbong_sbox=4'h2; 4'h5: sbong_sbox=4'hE;
                4'h6: sbong_sbox=4'h7; 4'h7: sbong_sbox=4'hA;
                4'h8: sbong_sbox=4'h9; 4'h9: sbong_sbox=4'hD;
                4'hA: sbong_sbox=4'hF; 4'hB: sbong_sbox=4'hC;
                4'hC: sbong_sbox=4'h3; 4'hD: sbong_sbox=4'h1;
                4'hE: sbong_sbox=4'h0; default: sbong_sbox=4'h8;
            endcase
        end
    endfunction

    function automatic [11:0] sbong_output(input [11:0] state, input [11:0] lfsr);
        logic [11:0] mixed;
        logic [11:0] substituted;
        begin
            mixed = state ^ lfsr;
            substituted = {sbong_sbox(mixed[11:8]), sbong_sbox(mixed[7:4]), sbong_sbox(mixed[3:0])};
            sbong_output = {substituted[0], substituted[11:1]};
        end
    endfunction

    function automatic integer pool_for_dimension(input integer dimension_index);
        begin
            case (dimension_index)
                0,2,5,7,9,10,13,15,18,19,20,21,23,24,29,30: pool_for_dimension = 1;
                default: pool_for_dimension = 0;
            endcase
        end
    endfunction

    function automatic logic cape_wbg_bit(
        input logic signed [7:0] value,
        input integer input_index,
        input [19:0] counter_value
    );
        logic [10:0] limit;
        logic previous_zero;
        logic random_bit;
        logic result_bit;
        integer j;
        begin
            limit = threshold(value);
            if (limit == 0)
                cape_wbg_bit = 1'b0;
            else if (limit == 1024)
                cape_wbg_bit = 1'b1;
            else begin
                previous_zero = 1'b1;
                result_bit = 1'b0;
                for (j = 0; j < 10; j = j + 1) begin
                    random_bit = counter_value[2*j + input_index];
                    if (previous_zero && random_bit && limit[9-j])
                        result_bit = 1'b1;
                    previous_zero = previous_zero && !random_bit;
                end
                cape_wbg_bit = result_bit;
            end
        end
    endfunction

    logic [11:0] current_sbong_output;
    logic signed [7:0] feature_value;
    logic [9:0] word_x;
    logic [9:0] word_n;
    logic [9:0] word_v;
    integer pool_index;
    integer delay_amount;

    always_comb begin
        current_sbong_output = sbong_output(sbong_state, sbong_lfsr);
        for (comb_c = 0; comb_c < 96; comb_c = comb_c + 1)
            raw_bits[comb_c] = 1'b0;

        for (comb_d = 0; comb_d < DIM; comb_d = comb_d + 1) begin
            feature_value = $signed(features_q8[comb_d*8 +: 8]);
            word_x = 10'd0;
            word_n = 10'd0;
            word_v = 10'd0;
            case (ARCH)
                0: begin
                    word_x = lfsr_state[comb_d] - 1'b1;
                    word_n = lfsr_state[32+comb_d] - 1'b1;
                    word_v = lfsr_state[64+comb_d] - 1'b1;
                end
                1: begin
                    word_x = base_state ^ ((comb_d*683) % 1024);
                    word_n = base_state ^ (((32+comb_d)*683) % 1024);
                    word_v = base_state ^ (((64+comb_d)*683) % 1024);
                end
                2,3: begin
                    word_x = rotl10(base_state - 1'b1, comb_d % 10);
                    word_n = rotl10(base_state - 1'b1, (32+comb_d) % 10);
                    word_v = rotl10(base_state - 1'b1, (64+comb_d) % 10);
                end
                4: begin
                    word_x = base_state - 1'b1;
                    word_n = reverse10(base_state - 1'b1);
                    word_v = reverse10(base_state - 1'b1);
                end
                6: begin
                    word_x = rotl12(current_sbong_output, comb_d % 12);
                    word_n = rotl12(current_sbong_output, (32+comb_d) % 12);
                    word_v = rotl12(current_sbong_output, (64+comb_d) % 12);
                end
                7: begin
                    pool_index = pool_for_dimension(comb_d);
                    word_x = pool_state[pool_index] - 1'b1;
                    word_n = pool_state[2+pool_index] - 1'b1;
                    word_v = pool_state[2+pool_index] - 1'b1;
                end
                default: begin
                    word_x = 10'd0;
                    word_n = 10'd0;
                    word_v = 10'd0;
                end
            endcase

            if (ARCH == 5) begin
                raw_bits[comb_d] = cape_wbg_bit(feature_value, 0, cape_counter);
                raw_bits[32+comb_d] = cape_wbg_bit(template_n[comb_d], 1, cape_counter);
                raw_bits[64+comb_d] = cape_wbg_bit(template_v[comb_d], 1, cape_counter);
            end else begin
                raw_bits[comb_d] = word_x < feature_thresholds[comb_d*11 +: 11];
                raw_bits[32+comb_d] = word_n < threshold(template_n[comb_d]);
                raw_bits[64+comb_d] = word_v < threshold(template_v[comb_d]);
            end
        end

        for (comb_c = 0; comb_c < 96; comb_c = comb_c + 1) begin
            source_bits[comb_c] = raw_bits[comb_c];
            if (ARCH == 3) begin
                delay_amount = comb_c;
                if (delay_amount > 0)
                    source_bits[comb_c] = delay_pipe[comb_c][delay_amount-1];
            end else if (ARCH == 6) begin
                delay_amount = comb_c / 12;
                if (delay_amount > 0)
                    source_bits[comb_c] = delay_pipe[comb_c][delay_amount-1];
            end
            scoring_bits[comb_c] = (ARCH == 5) ? cape_source_pipe[comb_c] : source_bits[comb_c];
        end

        for (comb_d = 0; comb_d < DIM; comb_d = comb_d + 1) begin
            product_n[comb_d] = scoring_bits[comb_d] == scoring_bits[32+comb_d];
            product_v[comb_d] = scoring_bits[comb_d] == scoring_bits[64+comb_d];
        end
        for (pop_i = 0; pop_i < 16; pop_i = pop_i + 1) begin
            pop_n_l1[pop_i] = product_n[2*pop_i] + product_n[2*pop_i+1];
            pop_v_l1[pop_i] = product_v[2*pop_i] + product_v[2*pop_i+1];
        end
        for (pop_i = 0; pop_i < 8; pop_i = pop_i + 1) begin
            pop_n_l2[pop_i] = pop_n_l1[2*pop_i] + pop_n_l1[2*pop_i+1];
            pop_v_l2[pop_i] = pop_v_l1[2*pop_i] + pop_v_l1[2*pop_i+1];
        end
        for (pop_i = 0; pop_i < 4; pop_i = pop_i + 1) begin
            pop_n_l3[pop_i] = pop_n_l2[2*pop_i] + pop_n_l2[2*pop_i+1];
            pop_v_l3[pop_i] = pop_v_l2[2*pop_i] + pop_v_l2[2*pop_i+1];
        end
        for (pop_i = 0; pop_i < 2; pop_i = pop_i + 1) begin
            pop_n_l4[pop_i] = pop_n_l3[2*pop_i] + pop_n_l3[2*pop_i+1];
            pop_v_l4[pop_i] = pop_v_l3[2*pop_i] + pop_v_l3[2*pop_i+1];
        end
        ones_n = pop_n_l4[0] + pop_n_l4[1];
        ones_v = pop_v_l4[0] + pop_v_l4[1];
    end

    (* use_dsp = "yes" *) logic signed [20:0] q8_acc_n;
    (* use_dsp = "yes" *) logic signed [20:0] q8_acc_v;
    logic [5:0] q8_index;
    logic signed [15:0] q8_product_n;
    logic signed [15:0] q8_product_v;
    always_comb begin
        q8_product_n = $signed(features_q8[q8_index*8 +: 8]) * $signed(template_n[q8_index]);
        q8_product_v = $signed(features_q8[q8_index*8 +: 8]) * $signed(template_v[q8_index]);
    end

    integer seed_value;
    integer next_n;
    integer next_v;
    integer signed_margin;
    integer absolute_margin;
    integer cycles_after_edge;
    logic should_stop;
    logic [11:0] sbong_word_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            prediction_v <= 1'b0;
            count_n <= 0;
            count_v <= 0;
            cycles_used <= 0;
            cycle_index <= 0;
            accumulated_count <= 0;
            ones_n_pipe <= 0;
            ones_v_pipe <= 0;
            ones_valid_pipe <= 1'b0;
            q8_acc_n <= 0;
            q8_acc_v <= 0;
            q8_index <= 0;
            adaptive_check_pending <= 1'b0;
            adaptive_margin_reg <= 0;
            adaptive_cycle_reg <= 0;
            cape_source_valid <= 1'b0;
            warmup_remaining <= 0;
            base_state <= 10'd1;
            sbong_lfsr <= 12'd1;
            sbong_state <= 12'hA5B;
            cape_counter <= 0;
            for (seq_c = 0; seq_c < 96; seq_c = seq_c + 1) begin
                lfsr_state[seq_c] <= 10'd1;
                cape_source_pipe[seq_c] <= 1'b0;
                for (seq_s = 0; seq_s < 95; seq_s = seq_s + 1)
                    delay_pipe[seq_c][seq_s] <= 1'b0;
            end
            for (seq_c = 0; seq_c < 4; seq_c = seq_c + 1)
                pool_state[seq_c] <= 10'd1;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                count_n <= 0;
                count_v <= 0;
                cycles_used <= 0;
                cycle_index <= 0;
                accumulated_count <= 0;
                ones_n_pipe <= 0;
                ones_v_pipe <= 0;
                ones_valid_pipe <= 1'b0;
                q8_acc_n <= 0;
                q8_acc_v <= 0;
                q8_index <= 0;
                adaptive_check_pending <= 1'b0;
                adaptive_margin_reg <= 0;
                adaptive_cycle_reg <= 0;
                cape_source_valid <= 1'b0;
                prediction_v <= 1'b0;
                base_state <= 10'd1;
                sbong_lfsr <= 12'd1;
                sbong_state <= 12'hA5B;
                cape_counter <= 0;
                warmup_remaining <= (ARCH == 3) ? 95 : ((ARCH == 6) ? 7 : 0);
                for (seq_c = 0; seq_c < 96; seq_c = seq_c + 1) begin
                    seed_value = ((seq_c * 73) % 1023) + 1;
                    lfsr_state[seq_c] <= seed_value[9:0];
                    cape_source_pipe[seq_c] <= 1'b0;
                    for (seq_s = 0; seq_s < 95; seq_s = seq_s + 1)
                        delay_pipe[seq_c][seq_s] <= 1'b0;
                end
                for (seq_c = 0; seq_c < 4; seq_c = seq_c + 1) begin
                    seed_value = ((seq_c * 73) % 1023) + 1;
                    pool_state[seq_c] <= seed_value[9:0];
                end
                if (ARCH == 8) begin
                    busy <= 1'b1;
                end else begin
                    busy <= 1'b1;
                end
            end else if (busy) begin
                if (adaptive_check_pending) begin
                    absolute_margin = adaptive_margin_reg < 0 ? -adaptive_margin_reg : adaptive_margin_reg;
                    should_stop = 1'b0;
                    if (adaptive_cycle_reg == 63  && absolute_margin >= 32) should_stop = 1'b1;
                    if (adaptive_cycle_reg == 127 && absolute_margin >= 46) should_stop = 1'b1;
                    if (adaptive_cycle_reg == 255 && absolute_margin >= 64) should_stop = 1'b1;
                    if (adaptive_cycle_reg == 511 && absolute_margin >= 91) should_stop = 1'b1;
                    adaptive_check_pending <= 1'b0;
                    if (should_stop) begin
                        prediction_v <= adaptive_margin_reg > 0;
                        cycles_used <= adaptive_cycle_reg;
                        done <= 1'b1;
                        busy <= 1'b0;
                    end
                end else if (ARCH == 8) begin
                    q8_acc_n <= q8_acc_n + q8_product_n;
                    q8_acc_v <= q8_acc_v + q8_product_v;
                    if (q8_index == 31) begin
                        prediction_v <= (q8_acc_v + q8_product_v) > (q8_acc_n + q8_product_n);
                        cycles_used <= 32;
                        done <= 1'b1;
                        busy <= 1'b0;
                    end else begin
                        q8_index <= q8_index + 1'b1;
                    end
                end else begin
                if (warmup_remaining != 0 || cycle_index < STREAM_LENGTH) begin
                    if (ARCH == 0)
                        for (seq_c = 0; seq_c < 96; seq_c = seq_c + 1)
                            lfsr_state[seq_c] <= lfsr10_next(lfsr_state[seq_c]);
                    if (ARCH == 1 || ARCH == 2 || ARCH == 3 || ARCH == 4)
                        base_state <= lfsr10_next(base_state);
                    if (ARCH == 7)
                        for (seq_c = 0; seq_c < 4; seq_c = seq_c + 1)
                            pool_state[seq_c] <= lfsr10_next(pool_state[seq_c]);
                    if (ARCH == 5)
                        cape_counter <= cape_counter + 1'b1;
                    if (ARCH == 6) begin
                        sbong_word_next = current_sbong_output;
                        sbong_state <= sbong_word_next ^ sbong_lfsr;
                        sbong_lfsr <= lfsr12_next(sbong_lfsr);
                    end
                    if (ARCH == 3 || ARCH == 6) begin
                        for (seq_c = 0; seq_c < 96; seq_c = seq_c + 1) begin
                            delay_pipe[seq_c][0] <= raw_bits[seq_c];
                            for (seq_s = 1; seq_s < 95; seq_s = seq_s + 1)
                                delay_pipe[seq_c][seq_s] <= delay_pipe[seq_c][seq_s-1];
                        end
                    end
                end

                if (warmup_remaining != 0) begin
                    warmup_remaining <= warmup_remaining - 1'b1;
                    ones_valid_pipe <= 1'b0;
                    cape_source_valid <= 1'b0;
                end else begin
                    if (cycle_index < STREAM_LENGTH) begin
                        if (ARCH == 5) begin
                            for (seq_c = 0; seq_c < 96; seq_c = seq_c + 1)
                                cape_source_pipe[seq_c] <= source_bits[seq_c];
                            cape_source_valid <= 1'b1;
                        end else begin
                            ones_n_pipe <= ones_n;
                            ones_v_pipe <= ones_v;
                            ones_valid_pipe <= 1'b1;
                        end
                        cycle_index <= cycle_index + 1'b1;
                    end else begin
                        cape_source_valid <= 1'b0;
                        if (ARCH != 5)
                            ones_valid_pipe <= 1'b0;
                    end

                    if (ARCH == 5) begin
                        if (cape_source_valid) begin
                            ones_n_pipe <= ones_n;
                            ones_v_pipe <= ones_v;
                            ones_valid_pipe <= 1'b1;
                        end else begin
                            ones_valid_pipe <= 1'b0;
                        end
                    end

                    if (ones_valid_pipe) begin
                        next_n = count_n + ones_n_pipe;
                        next_v = count_v + ones_v_pipe;
                        count_n <= next_n[14:0];
                        count_v <= next_v[14:0];
                        cycles_after_edge = accumulated_count + 1;
                        accumulated_count <= cycles_after_edge[10:0];
                        signed_margin = next_v - next_n;
                        absolute_margin = signed_margin < 0 ? -signed_margin : signed_margin;
                        should_stop = cycles_after_edge == STREAM_LENGTH;
                        if (ADAPTIVE != 0 && (cycles_after_edge == 63 ||
                                cycles_after_edge == 127 || cycles_after_edge == 255 ||
                                cycles_after_edge == 511)) begin
                            adaptive_margin_reg <= signed_margin;
                            adaptive_cycle_reg <= cycles_after_edge[10:0];
                            adaptive_check_pending <= 1'b1;
                        end else if (should_stop) begin
                            prediction_v <= next_v > next_n;
                            cycles_used <= cycles_after_edge[10:0];
                            done <= 1'b1;
                            busy <= 1'b0;
                        end
                    end
                end
                end
            end
        end
    end
endmodule
