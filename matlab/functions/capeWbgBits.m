function bits = capeWbgBits(thresholds, cycles, inputIndex, inputCount, precision)
%CAPEWBGBITS Generate CAPE counter/WBG stochastic bit streams.
% thresholds may be a vector or matrix in [0, 2^precision]. Output is
% cycles-by-numel(thresholds), in MATLAB column-major threshold order.

arguments
    thresholds {mustBeNumeric}
    cycles (1,1) double {mustBeInteger,mustBePositive}
    inputIndex (1,1) double {mustBeInteger,mustBePositive}
    inputCount (1,1) double {mustBeInteger,mustBePositive}
    precision (1,1) double {mustBeInteger,mustBePositive}
end

assert(inputIndex <= inputCount);
assert(cycles <= 2^(inputCount * precision));
thresholdVector = double(thresholds(:));
assert(all(thresholdVector >= 0 & thresholdVector <= 2^precision));

counter = uint64((0:cycles-1)');
weights = false(cycles, precision);
previousAllZero = true(cycles, 1);
for precisionIndex = 1:precision
    counterBitPosition = (precisionIndex - 1) * inputCount + inputIndex;
    randomBit = logical(bitget(counter, counterBitPosition));
    weights(:, precisionIndex) = previousAllZero & randomBit;
    previousAllZero = previousAllZero & ~randomBit;
end

binaryDigits = false(numel(thresholdVector), precision);
endpointMask = thresholdVector == 2^precision;
boundedThreshold = min(thresholdVector, 2^precision - 1);
for precisionIndex = 1:precision
    binaryPosition = precision - precisionIndex + 1;
    binaryDigits(:, precisionIndex) = logical(bitget(uint16(boundedThreshold), binaryPosition));
end
bits = (double(weights) * double(binaryDigits')) > 0;
bits(:, endpointMask) = true;
end
