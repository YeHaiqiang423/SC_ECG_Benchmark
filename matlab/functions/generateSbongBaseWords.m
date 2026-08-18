function words = generateSbongBaseWords(cycles, initialLfsr, initialState)
%GENERATESBONGBASEWORDS Generate the published SBoNG state transition.
% A 12-bit instance is used because the S-box operates on 4-bit blocks.

arguments
    cycles (1,1) double {mustBeInteger,mustBePositive}
    initialLfsr (1,1) uint16 = uint16(1)
    initialState (1,1) uint16 = uint16(hex2dec('A5B'))
end

mask = uint16(4095);
lfsrState = bitand(initialLfsr, mask);
internalState = bitand(initialState, mask);
assert(lfsrState ~= 0, 'The SBoNG LFSR seed must be nonzero.');
words = zeros(cycles, 1, 'uint16');
for cycle = 1:cycles
    mixed = bitxor(internalState, lfsrState);
    substituted = uint16(0);
    for nibbleIndex = 0:2
        nibble = bitand(bitshift(mixed, -4 * nibbleIndex), uint16(15));
        substituted = bitor(substituted, ...
            bitshift(sbongSbox4(nibble), 4 * nibbleIndex));
    end
    output = bitor(bitshift(substituted, -1), ...
        bitshift(bitand(substituted, uint16(1)), 11));
    words(cycle) = output;
    internalState = bitxor(output, lfsrState);
    lfsrState = lfsr12Next(lfsrState);
end
end
