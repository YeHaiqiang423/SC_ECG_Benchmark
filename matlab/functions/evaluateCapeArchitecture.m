function result = evaluateCapeArchitecture(architecture, data, templateN, templateV, ...
        streamLengths, lfsrWidth)
%EVALUATECAPEARCHITECTURE Evaluate pairwise two-input CAPE/WBG XNOR.
% One interleaved counter is shared by every dimension. At 2^(2i) cycles,
% each XNOR product is exact for the i-bit truncated probabilities.

dimension = size(data.features, 2);
maxLength = max(streamLengths);
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
templateBitsN = reshape(capeWbgBits(thresholdN, maxLength, 2, 2, lfsrWidth), ...
    maxLength, dimension);
templateBitsV = reshape(capeWbgBits(thresholdV, maxLength, 2, 2, lfsrWidth), ...
    maxLength, dimension);

lengthCount = numel(streamLengths);
countN = zeros(sampleCount, lengthCount);
countV = zeros(sampleCount, lengthCount);
for sampleIndex = 1:sampleCount
    inputBits = reshape(capeWbgBits(thresholdX(sampleIndex, :), ...
        maxLength, 1, 2, lfsrWidth), maxLength, dimension);
    cumulativeN = cumsum(sum(inputBits == templateBitsN, 2));
    cumulativeV = cumsum(sum(inputBits == templateBitsV, 2));
    countN(sampleIndex, :) = cumulativeN(streamLengths);
    countV(sampleIndex, :) = cumulativeV(streamLengths);
end

metrics = table();
detail = table();
for lengthIndex = 1:lengthCount
    streamLength = streamLengths(lengthIndex);
    scPrediction = repmat("N", sampleCount, 1);
    scPrediction(countV(:, lengthIndex) > countN(:, lengthIndex)) = "V";
    row = classificationMetrics(architecture, data.name, streamLength, ...
        truth, exactPrediction, scPrediction);
    estimatedScoreN = 127^2 * (2 * countN(:, lengthIndex) / streamLength - dimension);
    estimatedScoreV = 127^2 * (2 * countV(:, lengthIndex) / streamLength - dimension);
    scoreError = [estimatedScoreN - exactScoreN; estimatedScoreV - exactScoreV];
    marginError = (estimatedScoreV - estimatedScoreN) - (exactScoreV - exactScoreN);
    row.score_MAE = mean(abs(scoreError));
    row.score_RMSE = sqrt(mean(scoreError.^2));
    row.score_max_abs_error = max(abs(scoreError));
    row.margin_MAE = mean(abs(marginError));
    metrics = [metrics; row]; %#ok<AGROW>
    block = table(repmat(string(architecture), sampleCount, 1), ...
        repmat(string(data.name), sampleCount, 1), repmat(streamLength, sampleCount, 1), ...
        data.beatIndex(:), truth, exactScoreN, exactScoreV, exactPrediction, ...
        countN(:, lengthIndex), countV(:, lengthIndex), estimatedScoreN, estimatedScoreV, ...
        scPrediction, abs(countV(:, lengthIndex) - countN(:, lengthIndex)), ...
        'VariableNames', {'architecture','dataset','stream_length','beat_index', ...
        'true_label','exact_score_N_q8','exact_score_V_q8','exact_prediction_q8', ...
        'sc_count_N','sc_count_V','sc_estimated_score_N_q8', ...
        'sc_estimated_score_V_q8','sc_prediction','sc_count_margin'});
    detail = [detail; block]; %#ok<AGROW>
end

sourceMetrics = table(string(architecture), string(data.name), NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', {'architecture','dataset','pair_abs_SCC_mean', ...
    'pair_abs_SCC_p95','pair_abs_SCC_max','input_N_abs_SCC_mean','input_V_abs_SCC_mean'});
result.metrics = metrics;
result.detail = detail;
result.sourceMetrics = sourceMetrics;
end
