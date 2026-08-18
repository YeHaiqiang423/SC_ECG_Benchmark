`timescale 1ns/1ps

module sc_nv_serial_top #(
    parameter integer ARCH = 0,
    parameter integer ADAPTIVE = 0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        feature_we,
    input  logic [4:0]  feature_index,
    input  logic [7:0]  feature_data,
    input  logic        start,
    output logic        busy,
    output logic        done,
    output logic        prediction_v,
    output logic [14:0] count_n,
    output logic [14:0] count_v,
    output logic [10:0] cycles_used
);
    logic [255:0] feature_register;
    logic [351:0] threshold_register;

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

    always_ff @(posedge clk) begin
        if (rst) begin
            feature_register <= '0;
            threshold_register <= '0;
        end else if (feature_we && !busy) begin
            feature_register[feature_index*8 +: 8] <= feature_data;
            threshold_register[feature_index*11 +: 11] <= threshold($signed(feature_data));
        end
    end

    sc_nv_classifier #(.ARCH(ARCH), .ADAPTIVE(ADAPTIVE)) core (
        .clk,
        .rst,
        .start,
        .features_q8(feature_register),
        .feature_thresholds(threshold_register),
        .busy,
        .done,
        .prediction_v,
        .count_n,
        .count_v,
        .cycles_used
    );
endmodule
