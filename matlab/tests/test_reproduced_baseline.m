function test_reproduced_baseline(projectRoot)
%TEST_REPRODUCED_BASELINE Assert the frozen Day 2-4 metrics.

if nargin == 0
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

day2Path = fullfile(projectRoot, 'results', 'day02_beats', 'beats_119_raw.mat');
day3Path = fullfile(projectRoot, 'results', 'day03_baseline', ...
    'classification_results.csv');
day4Path = fullfile(projectRoot, 'results', 'day04_golden', 'sc_summary.csv');

assert(isfile(day2Path), 'Missing Day 2 MAT file.');
assert(isfile(day3Path), 'Missing Day 3 metrics.');
assert(isfile(day4Path), 'Missing Day 4 metrics.');

day2 = load(day2Path, 'Fs', 'beatLength', 'beatLabels');
assert(day2.Fs == 360);
assert(day2.beatLength == 252);
assert(sum(day2.beatLabels == 'N') == 1543);
assert(sum(day2.beatLabels == 'V') == 444);

day3 = readtable(day3Path, 'TextType', 'string');
row = day3(day3.method == "q8" & day3.dimension == 32 & ...
    day3.dataset == "noisy_12dB_paired", :);
assert(height(row) == 1);
assert(row.sample_count == 416);
assert(row.TN_N == 323 && row.FP_N_as_V == 10);
assert(row.FN_V_as_N == 1 && row.TP_V == 82);
assert(abs(row.accuracy - 0.973557692307692) < 1e-14);
assert(abs(row.F1_V - 0.937142857142857) < 1e-14);
assert(abs(row.balanced_accuracy - 0.978960888599443) < 1e-14);

day4 = readtable(day4Path, 'TextType', 'string');
independent = day4(day4.architecture == "independent_lfsr", :);
shared = day4(day4.architecture == "shared_xor", :);
assert(isequal(independent.stream_length(:), [63; 127; 255; 511; 1023]));
assert(isequal(independent.disagreements_with_q8(:), [49; 37; 11; 1; 0]));
assert(independent.agreement_with_q8(end) == 1);
assert(all(shared.accuracy_vs_truth == 0.5));
assert(all(shared.TP_V == 0));

referenceDay3 = readtable(fullfile(projectRoot, 'references', ...
    'frozen_parent', 'day03_baseline', 'classification_results.csv'), ...
    'TextType', 'string');
referenceDay4 = readtable(fullfile(projectRoot, 'references', ...
    'frozen_parent', 'day04_golden', 'sc_summary.csv'), ...
    'TextType', 'string');
assert(isequaln(day3, referenceDay3), 'Day 3 table differs from frozen reference.');
assert(isequaln(day4, referenceDay4), 'Day 4 table differs from frozen reference.');

fprintf('FROZEN_BASELINE_PASS day2_N=1543 day2_V=444 day3_accuracy=%.12f\n', ...
    row.accuracy);
end

