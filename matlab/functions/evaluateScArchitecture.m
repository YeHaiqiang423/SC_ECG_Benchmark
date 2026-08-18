function result = evaluateScArchitecture(architecture, data, templateN, templateV, ...
        randomWords, streamLengths, lfsrWidth)
%EVALUATESCARCHITECTURE Evaluate one random-word architecture.

dimension = size(data.features, 2);
assert(size(randomWords, 2) == 3 * dimension);
assert(max(streamLengths) <= size(randomWords, 1));

features = int16(data.features);
truth = string(data.labels(:));
sampleCount = size(features, 1);
exactScoreN = double(features) * double(templateN(:));
exactScoreV = double(features) * double(templateV(:));
exactPrediction = repmat("N", sampleCount, 1);
exactPrediction(exactScoreV > exactScoreN) = "V";

thresholdX = bipolarThreshold(features, lfsrWidth);
thresholdN = bipolarThreshold(templateN, lfsrWidth);
thresholdV = bipolarThreshold(templateV, lfsrWidth);
randomX = randomWords(:, 1:dimension);
randomN = randomWords(:, dimension + (1:dimension));
randomV = randomWords(:, 2 * dimension + (1:dimension));
templateBitsN = randomN < thresholdN;
templateBitsV = randomV < thresholdV;

lengthCount = numel(streamLengths);
countN = zeros(sampleCount, lengthCount);
countV = zeros(sampleCount, lengthCount);
pairSccN = zeros(sampleCount, dimension);
pairSccV = zeros(sampleCount, dimension);

for sampleIndex = 1:sampleCount
    inputBits = randomX < thresholdX(sampleIndex, :);
    productsN = inputBits == templateBitsN;
    productsV = inputBits == templateBitsV;
    cumulativeN = cumsum(sum(productsN, 2));
    cumulativeV = cumsum(sum(productsV, 2));
    countN(sampleIndex, :) = cumulativeN(streamLengths);
    countV(sampleIndex, :) = cumulativeV(streamLengths);
    pairSccN(sampleIndex, :) = calculateSccColumns(inputBits, templateBitsN);
    pairSccV(sampleIndex, :) = calculateSccColumns(inputBits, templateBitsV);
end

metrics = table();
detail = table();
for lengthIndex = 1:lengthCount
    streamLength = streamLengths(lengthIndex);
    scPrediction = repmat("N", sampleCount, 1);
    scPrediction(countV(:, lengthIndex) > countN(:, lengthIndex)) = "V";
    row = classificationMetrics(architecture, data.name, streamLength, ...
        truth, exactPrediction, scPrediction);
    estimatedScoreN = 127^2 * ...
        (2 * countN(:, lengthIndex) / streamLength - dimension);
    estimatedScoreV = 127^2 * ...
        (2 * countV(:, lengthIndex) / streamLength - dimension);
    scoreError = [estimatedScoreN - exactScoreN; estimatedScoreV - exactScoreV];
    marginError = (estimatedScoreV - estimatedScoreN) - ...
        (exactScoreV - exactScoreN);
    row.score_MAE = mean(abs(scoreError));
    row.score_RMSE = sqrt(mean(scoreError.^2));
    row.score_max_abs_error = max(abs(scoreError));
    row.margin_MAE = mean(abs(marginError));
    if isempty(metrics)
        metrics = row;
    else
        metrics = [metrics; row]; %#ok<AGROW>
    end
    block = table(repmat(string(architecture), sampleCount, 1), ...
        repmat(string(data.name), sampleCount, 1), ...
        repmat(streamLength, sampleCount, 1), data.beatIndex(:), truth, ...
        exactScoreN, exactScoreV, exactPrediction, countN(:, lengthIndex), ...
        countV(:, lengthIndex), estimatedScoreN, estimatedScoreV, scPrediction, ...
        abs(countV(:, lengthIndex) - countN(:, lengthIndex)), ...
        'VariableNames', {'architecture','dataset','stream_length','beat_index', ...
        'true_label','exact_score_N_q8','exact_score_V_q8','exact_prediction_q8', ...
        'sc_count_N','sc_count_V','sc_estimated_score_N_q8', ...
        'sc_estimated_score_V_q8','sc_prediction','sc_count_margin'});
    if isempty(detail)
        detail = block;
    else
        detail = [detail; block]; %#ok<AGROW>
    end
end

absoluteScc = abs([pairSccN(:); pairSccV(:)]);
sourceMetrics = table(string(architecture), string(data.name), ...
    mean(absoluteScc), prctile(absoluteScc, 95), max(absoluteScc), ...
    mean(abs(pairSccN), 'all'), mean(abs(pairSccV), 'all'), ...
    'VariableNames', {'architecture','dataset','pair_abs_SCC_mean', ...
    'pair_abs_SCC_p95','pair_abs_SCC_max','input_N_abs_SCC_mean', ...
    'input_V_abs_SCC_mean'});

result.metrics = metrics;
result.detail = detail;
result.sourceMetrics = sourceMetrics;
end

function scc = calculateSccColumns(a, b)
pA = mean(a, 1);
pB = mean(b, 1);
pAB = mean(a & b, 1);
independentPoint = pA .* pB;
scc = zeros(size(pA));
positiveMask = pAB > independentPoint;
positiveDenominator = min(pA, pB) - independentPoint;
negativeDenominator = independentPoint - max(pA + pB - 1, 0);
validPositive = positiveMask & positiveDenominator > eps;
validNegative = ~positiveMask & negativeDenominator > eps;
scc(validPositive) = (pAB(validPositive) - independentPoint(validPositive)) ./ ...
    positiveDenominator(validPositive);
scc(validNegative) = (pAB(validNegative) - independentPoint(validNegative)) ./ ...
    negativeDenominator(validNegative);
end

