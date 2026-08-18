function [randomWords, metadata, assignment] = generateMarginAwareWords( ...
        cycles, templateN, templateV, poolSize)
%GENERATEMARGINAWAREWORDS Allocate scarce source pools by decision sensitivity.
% Input and template pools are separate; N/V template streams share a pool
% so common template-side error largely cancels in the score difference.

arguments
    cycles (1,1) double {mustBeInteger,mustBePositive}
    templateN (1,:) {mustBeNumeric}
    templateV (1,:) {mustBeNumeric}
    poolSize (1,1) double {mustBeInteger,mustBePositive}
end

dimension = numel(templateN);
assert(numel(templateV) == dimension);
poolSize = min(poolSize, dimension);
[poolWords, ~] = generateRandomWords("independent_lfsr", cycles, 2 * poolSize);
sensitivity = abs(double(templateV) - double(templateN));
[~, order] = sort(sensitivity, 'descend');
poolForDimension = zeros(1, dimension);
for rank = 1:dimension
    poolForDimension(order(rank)) = mod(rank - 1, poolSize) + 1;
end

inputWords = poolWords(:, poolForDimension);
templateWords = poolWords(:, poolSize + poolForDimension);
randomWords = [inputWords, templateWords, templateWords];
metadata = struct('method', "margin_aware_pool", 'registerCount', 2 * poolSize, ...
    'registerBits', 20 * poolSize, 'poolSize', poolSize, 'delayStep', 0);
assignment = table((1:dimension)', sensitivity(:), poolForDimension(:), ...
    'VariableNames', {'dimension','template_margin_sensitivity','pool_index'});
end
