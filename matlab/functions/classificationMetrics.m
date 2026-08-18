function row = classificationMetrics(architecture, datasetName, streamLength, ...
        truth, exactPrediction, scPrediction)
%CLASSIFICATIONMETRICS Return classification and q8-agreement metrics.

truth = string(truth(:));
exactPrediction = string(exactPrediction(:));
scPrediction = string(scPrediction(:));
TN = sum(truth == "N" & scPrediction == "N");
FP = sum(truth == "N" & scPrediction == "V");
FN = sum(truth == "V" & scPrediction == "N");
TP = sum(truth == "V" & scPrediction == "V");
accuracy = safeDivide(TN + TP, numel(truth));
precisionV = safeDivide(TP, TP + FP);
recallV = safeDivide(TP, TP + FN);
f1V = safeDivide(2 * precisionV * recallV, precisionV + recallV);
recallN = safeDivide(TN, TN + FP);
balancedAccuracy = 0.5 * (recallN + recallV);
agreement = mean(scPrediction == exactPrediction);

row = table(string(architecture), string(datasetName), streamLength, ...
    numel(truth), TN, FP, FN, TP, accuracy, precisionV, recallV, f1V, ...
    balancedAccuracy, agreement, sum(scPrediction ~= exactPrediction), ...
    'VariableNames', {'architecture','dataset','stream_length','sample_count', ...
    'TN_N','FP_N_as_V','FN_V_as_N','TP_V','accuracy','precision_V', ...
    'recall_V','F1_V','balanced_accuracy','agreement_with_q8', ...
    'disagreements_with_q8'});
end

function value = safeDivide(numerator, denominator)
if denominator == 0
    value = 0;
else
    value = numerator / denominator;
end
end

