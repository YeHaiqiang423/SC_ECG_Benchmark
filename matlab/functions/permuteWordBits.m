function outputWords = permuteWordBits(inputWords, permutation, width)
%PERMUTEWORDBITS Rewire word bits without logic or state overhead.
% permutation(output position) gives the source bit position, both LSB-first.

arguments
    inputWords
    permutation (1,:) double {mustBeInteger,mustBePositive}
    width (1,1) double {mustBeInteger,mustBePositive}
end

assert(numel(permutation) == width);
assert(isequal(sort(permutation), 1:width));
outputWords = zeros(size(inputWords), 'uint16');
for outputPosition = 1:width
    outputWords = bitset(outputWords, outputPosition, ...
        bitget(inputWords, permutation(outputPosition)));
end
end
