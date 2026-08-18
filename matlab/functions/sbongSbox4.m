function output = sbongSbox4(input)
%SBONGSBOX4 Mini-AES substitution used by the published SBoNG design.
% Hex mapping: 0..F -> 6 B 5 4 2 E 7 A 9 D F C 3 1 0 8.

lookup = uint16([6, 11, 5, 4, 2, 14, 7, 10, 9, 13, 15, 12, 3, 1, 0, 8]);
output = lookup(double(input) + 1);
end
