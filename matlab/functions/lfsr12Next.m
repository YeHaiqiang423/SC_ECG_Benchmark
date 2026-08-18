function nextState = lfsr12Next(state)
%LFSR12NEXT Fibonacci LFSR for x^12 + x^11 + x^10 + x^4 + 1.
% State follows the project's left-shift convention; feedback enters bit 1.

state = uint16(state);
feedback = bitxor(bitxor(bitget(state, 12), bitget(state, 11)), ...
    bitxor(bitget(state, 10), bitget(state, 4)));
nextState = bitor(bitand(bitshift(state, 1), uint16(4095)), uint16(feedback));
end
