function metrics = randomWordMetrics(architecture, randomWords, metadata)
%RANDOMWORDMETRICS Summarize random-word diversity and linear correlation.

normalized = double(randomWords) / 1023;
correlation = corrcoef(normalized);
upperMask = triu(true(size(correlation)), 1);
absoluteCorrelation = abs(correlation(upperMask));
absoluteCorrelation = absoluteCorrelation(isfinite(absoluteCorrelation));
uniqueSequences = size(unique(randomWords.', 'rows'), 1);

metrics = table(string(architecture), size(randomWords, 2), uniqueSequences, ...
    metadata.registerCount, metadata.registerBits, mean(absoluteCorrelation), ...
    prctile(absoluteCorrelation, 95), max(absoluteCorrelation), ...
    'VariableNames', {'architecture','channel_count','unique_word_sequences', ...
    'random_register_count','random_register_bits','word_abs_corr_mean', ...
    'word_abs_corr_p95','word_abs_corr_max'});
end

