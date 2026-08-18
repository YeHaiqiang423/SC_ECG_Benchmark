function next = lfsr10Next(state)
%LFSR10NEXT Advance x^10+x^7+1 using the frozen left-shift convention.

state = uint16(state);
feedback = bitxor(bitget(state, 10), bitget(state, 7));
next = bitor(bitand(bitshift(state, 1), uint16(1023)), uint16(feedback));
end

