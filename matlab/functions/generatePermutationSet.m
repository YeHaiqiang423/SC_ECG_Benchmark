function permutations = generatePermutationSet(count, width, seed)
%GENERATEPERMUTATIONSET Deterministic greedy low-similarity wiring set.
% Uses Salehi's positional-similarity idea as a fast heuristic. The first
% wiring is identity; later wirings minimize their worst normalized dot
% product against the already selected set.

arguments
    count (1,1) double {mustBeInteger,mustBePositive}
    width (1,1) double {mustBeInteger,mustBePositive}
    seed (1,1) double {mustBeInteger,mustBeNonnegative} = 20260815
end

candidateCount = max(5000, 80 * count);
previousState = rng;
cleanup = onCleanup(@() rng(previousState)); %#ok<NASGU>
rng(seed, 'twister');
candidates = zeros(candidateCount + 2, width);
candidates(1, :) = 1:width;
candidates(2, :) = width:-1:1;
for index = 3:size(candidates, 1)
    candidates(index, :) = randperm(width);
end
candidates = unique(candidates, 'rows', 'stable');

permutations = zeros(count, width);
permutations(1, :) = candidates(1, :);
isAvailable = true(size(candidates, 1), 1);
isAvailable(1) = false;
normalizer = sum((1:width).^2);
for selectedIndex = 2:count
    availableIndices = find(isAvailable);
    worstSimilarity = zeros(numel(availableIndices), 1);
    meanSimilarity = zeros(numel(availableIndices), 1);
    for candidateIndex = 1:numel(availableIndices)
        candidate = candidates(availableIndices(candidateIndex), :);
        similarities = permutations(1:selectedIndex-1, :) * candidate' / normalizer;
        worstSimilarity(candidateIndex) = max(similarities);
        meanSimilarity(candidateIndex) = mean(similarities);
    end
    ranking = table(worstSimilarity, meanSimilarity, availableIndices);
    ranking = sortrows(ranking, {'worstSimilarity','meanSimilarity','availableIndices'});
    chosen = ranking.availableIndices(1);
    permutations(selectedIndex, :) = candidates(chosen, :);
    isAvailable(chosen) = false;
end
end
