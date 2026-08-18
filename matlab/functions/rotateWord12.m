function rotated = rotateWord12(values, amount)
%ROTATEWORD12 Circularly rotate 12-bit words to the left.

values = bitand(uint16(values), uint16(4095));
amount = mod(double(amount), 12);
if amount == 0
    rotated = values;
else
    rotated = bitor(bitand(bitshift(values, amount), uint16(4095)), ...
        bitshift(values, amount - 12));
end
end
