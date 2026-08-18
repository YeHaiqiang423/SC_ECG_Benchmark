function rotated = rotateWord10(values, amount)
%ROTATEWORD10 Circularly rotate 10-bit words to the left.

values = bitand(uint16(values), uint16(1023));
amount = mod(double(amount), 10);
if amount == 0
    rotated = values;
    return;
end
rotated = bitor(bitand(bitshift(values, amount), uint16(1023)), ...
    bitshift(values, amount - 10));
end

