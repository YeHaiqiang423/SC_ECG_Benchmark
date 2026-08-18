function test_sc_core(projectRoot)
%TEST_SC_CORE Unit checks for thresholds, LFSR and source generators.

if nargin == 0
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(fullfile(projectRoot, 'matlab', 'functions'));

assert(bipolarThreshold(int16(-127), 10) == 0);
assert(bipolarThreshold(int16(127), 10) == 1024);

state = uint16(1);
seen = false(1023, 1);
for cycle = 1:1023
    assert(state ~= 0);
    assert(~seen(double(state)));
    seen(double(state)) = true;
    state = lfsr10Next(state);
end
assert(state == 1 && all(seen));

[independent, independentMetadata] = generateRandomWords( ...
    "independent_lfsr", 1023, 96);
assert(isequal(size(independent), [1023, 96]));
assert(all(independent(:) <= 1022));
assert(independentMetadata.registerCount == 96);

[paired, pairedMetadata] = generateRandomWords("paired_template", 63, 96);
assert(isequal(paired(:, 33:64), paired(:, 65:96)));
assert(pairedMetadata.registerCount == 64);

fprintf('SC_CORE_PASS period=1023 independent_channels=96 paired_registers=64\n');

permutations = generatePermutationSet(96, 10, 20260815);
assert(size(unique(permutations, 'rows'), 1) == 96);
[permutedWords, permutedMetadata] = generateRandomWords("optimized_permutation", 1023, 96);
assert(size(permutedWords, 2) == 96 && permutedMetadata.registerCount == 1);

assert(isequal(sbongSbox4(uint16(0:15)), ...
    uint16([6 11 5 4 2 14 7 10 9 13 15 12 3 1 0 8])));
[sbongWords, sbongMetadata] = generateRandomWords("sbong_shared", 1023, 96);
assert(size(sbongWords, 2) == 96 && sbongMetadata.registerCount == 2);

exampleBits = capeWbgBits(5, 8, 1, 1, 3);
assert(isequal(exampleBits(:)', logical([0 1 0 1 1 1 0 1])));
fprintf('SC_ADVANCED_CORE_PASS permutations=%d sbong_unique=%d cape_example=01011101\n', ...
    size(permutations, 1), numel(unique(sbongWords(:, 1))));
end
