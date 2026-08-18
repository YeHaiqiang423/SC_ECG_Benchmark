function result = applyAdaptiveStopping(detail, lambda)
%APPLYADAPTIVESTOPPING Stop when |countV-countN| >= lambda*sqrt(cycles).
% The last available checkpoint always terminates to bound latency.

arguments
    detail table
    lambda (1,1) double {mustBeNonnegative}
end

streamLengths = unique(detail.stream_length, 'sorted')';
firstRows = detail(detail.stream_length == streamLengths(1), :);
beatIndices = firstRows.beat_index;
sampleCount = height(firstRows);
trueLabel = string(firstRows.true_label);
exactPrediction = string(firstRows.exact_prediction_q8);
marginMatrix = zeros(sampleCount, numel(streamLengths));
for checkpointIndex = 1:numel(streamLengths)
    rows = detail(detail.stream_length == streamLengths(checkpointIndex), :);
    [isFound, location] = ismember(beatIndices, rows.beat_index);
    assert(all(isFound));
    marginMatrix(:, checkpointIndex) = rows.sc_count_V(location) - rows.sc_count_N(location);
end

stopIndex = repmat(numel(streamLengths), sampleCount, 1);
isStopped = false(sampleCount, 1);
for checkpointIndex = 1:numel(streamLengths)-1
    shouldStop = ~isStopped & abs(marginMatrix(:, checkpointIndex)) >= ...
        lambda * sqrt(streamLengths(checkpointIndex));
    stopIndex(shouldStop) = checkpointIndex;
    isStopped(shouldStop) = true;
end
linearIndex = sub2ind(size(marginMatrix), (1:sampleCount)', stopIndex);
signedMargin = marginMatrix(linearIndex);
stopCycle = streamLengths(stopIndex)';
prediction = repmat("N", sampleCount, 1);
prediction(signedMargin > 0) = "V";

result = table(beatIndices, trueLabel, exactPrediction, prediction, ...
    stopCycle, signedMargin, 'VariableNames', {'beat_index','true_label', ...
    'exact_prediction_q8','adaptive_prediction','stop_cycle','signed_count_margin'});
end
