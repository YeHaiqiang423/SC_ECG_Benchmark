function [randomWords, metadata] = generateRandomWords(method, cycles, channels, options)
%GENERATERANDOMWORDS Generate deterministic random-word matrices for SC.
% Rows are cycles and columns are SNG channels.

arguments
    method (1,1) string
    cycles (1,1) double {mustBeInteger,mustBePositive}
    channels (1,1) double {mustBeInteger,mustBePositive}
    options.PoolSize (1,1) double {mustBeInteger,mustBeNonnegative} = 1
    options.DelayStep (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end

assert(cycles <= 1023, 'The frozen 10-bit LFSR supports at most 1023 cycles.');
channel = (0:channels-1)';
metadata = struct('method', method, 'registerCount', NaN, ...
    'registerBits', NaN, 'poolSize', options.PoolSize, ...
    'delayStep', options.DelayStep);

switch method
    case "independent_lfsr"
        initial = uint16(mod(double(channel) * 73, 1023) + 1);
        randomWords = generateFromSeeds(initial, cycles);
        randomWords = randomWords - uint16(1);
        metadata.registerCount = channels;
        metadata.registerBits = 10 * channels;

    case "shared_xor"
        masks = uint16(mod(double(channel) * 683, 1024));
        state = generateBaseStates(cycles);
        randomWords = zeros(cycles, channels, 'uint16');
        for c = 1:channels
            randomWords(:, c) = bitxor(state, masks(c));
        end
        metadata.registerCount = 1;
        metadata.registerBits = 10;

    case "circular_shift"
        baseWords = generateBaseStates(cycles) - uint16(1);
        randomWords = zeros(cycles, channels, 'uint16');
        for c = 1:channels
            randomWords(:, c) = rotateWord10(baseWords, mod(c-1, 10));
        end
        metadata.registerCount = 1;
        metadata.registerBits = 10;

    case "optimized_permutation"
        baseWords = generateBaseStates(cycles) - uint16(1);
        permutations = generatePermutationSet(channels, 10, 20260815);
        randomWords = zeros(cycles, channels, 'uint16');
        for c = 1:channels
            randomWords(:, c) = permuteWordBits(baseWords, permutations(c, :), 10);
        end
        metadata.registerCount = 1;
        metadata.registerBits = 10;
        metadata.permutations = permutations;

    case "optimized_pair_permutation"
        assert(channels == 96, 'Pair-optimized mapping is defined for 96 channels.');
        baseWords = generateBaseStates(cycles) - uint16(1);
        reversedWords = permuteWordBits(baseWords, 10:-1:1, 10);
        % Every input uses the direct wiring. Both N/V template channels use
        % the minimum-similarity reverse wiring, so their common residual
        % error cancels in the N-versus-V score margin.
        randomWords = [repmat(baseWords, 1, 32), ...
            repmat(reversedWords, 1, 32), repmat(reversedWords, 1, 32)];
        metadata.registerCount = 1;
        metadata.registerBits = 10;
        metadata.permutations = [1:10; 10:-1:1];

    case "circular_ibd"
        baseWords = generateBaseStates(cycles) - uint16(1);
        randomWords = zeros(cycles, channels, 'uint16');
        for c = 1:channels
            words = rotateWord10(baseWords, mod(c-1, 10));
            delay = mod((c-1) * options.DelayStep, cycles);
            randomWords(:, c) = circshift(words, delay);
        end
        metadata.registerCount = 1;
        metadata.registerBits = 10 + sum(mod(channel * options.DelayStep, cycles));

    case "grouped_rotated"
        assert(options.PoolSize >= 1, 'Grouped sources require PoolSize >= 1.');
        poolSize = min(options.PoolSize, channels);
        poolSeeds = uint16(mod((0:poolSize-1)' * 73, 1023) + 1);
        poolWords = generateFromSeeds(poolSeeds, cycles) - uint16(1);
        randomWords = zeros(cycles, channels, 'uint16');
        for c = 1:channels
            poolIndex = mod(c-1, poolSize) + 1;
            localIndex = floor((c-1) / poolSize);
            words = rotateWord10(poolWords(:, poolIndex), mod(localIndex, 10));
            delay = mod(localIndex * options.DelayStep, cycles);
            randomWords(:, c) = circshift(words, delay);
        end
        metadata.registerCount = poolSize;
        metadata.registerBits = 10 * poolSize;

    case "paired_template"
        assert(channels == 96, 'Paired-template mode is defined for 96 channels.');
        seeds = uint16(mod((0:63)' * 73, 1023) + 1);
        words = generateFromSeeds(seeds, cycles) - uint16(1);
        randomWords = [words(:, 1:32), words(:, 33:64), words(:, 33:64)];
        metadata.registerCount = 64;
        metadata.registerBits = 640;

    case "sbong_shared"
        baseWords12 = generateSbongBaseWords(cycles);
        randomWords = zeros(cycles, channels, 'uint16');
        for c = 1:channels
            rotated = bitand(rotateWord12(baseWords12, mod(c-1, 12)), uint16(1023));
            delay = floor((c-1) / 12);
            randomWords(:, c) = circshift(rotated, delay);
        end
        metadata.registerCount = 2;
        metadata.registerBits = 24 + sum(floor(channel / 12));
        metadata.sourceWidth = 12;

    case "sobol"
        sequence = sobolset(channels, 'Skip', 1, 'Leap', 0);
        points = net(sequence, cycles);
        randomWords = uint16(floor(points * 1024));
        metadata.registerCount = 0;
        metadata.registerBits = NaN;

    otherwise
        error('Unknown random-word method: %s', method);
end
end

function states = generateFromSeeds(initial, cycles)
initial = reshape(uint16(initial), 1, []);
states = zeros(cycles, numel(initial), 'uint16');
state = initial;
for cycle = 1:cycles
    states(cycle, :) = state;
    state = lfsr10Next(state);
end
end

function states = generateBaseStates(cycles)
states = generateFromSeeds(uint16(1), cycles);
states = states(:, 1);
end

function rotated = rotateWord12(words, amount)
amount = mod(amount, 12);
mask = uint16(4095);
if amount == 0
    rotated = bitand(words, mask);
else
    rotated = bitor(bitand(bitshift(words, amount), mask), ...
        bitshift(words, amount - 12));
end
end
