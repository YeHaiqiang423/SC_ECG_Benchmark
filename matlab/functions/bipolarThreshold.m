function threshold = bipolarThreshold(q8, width)
%BIPOLARTHRESHOLD Map signed q8 values to comparator thresholds.

q8 = double(q8);
assert(all(q8(:) >= -127 & q8(:) <= 127), ...
    'Bipolar q8 input must be in [-127,127].');
levels = 2^width;
threshold = uint16(round((q8 + 127) * levels / 254));
end

