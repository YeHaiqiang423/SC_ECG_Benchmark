function writeIterationArtifacts(outputRoot, experiment, metrics, detail, ...
        sourceMetrics, wordMetrics)
%WRITEITERATIONARTIFACTS Save reproducible tables and a concise experiment log.

if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end
writetable(metrics, fullfile(outputRoot, 'metrics.csv'));
writetable(detail, fullfile(outputRoot, 'detail.csv'));
writetable(sourceMetrics, fullfile(outputRoot, 'pair_correlation.csv'));
writetable(wordMetrics, fullfile(outputRoot, 'random_word_metrics.csv'));

configuration = table(string(experiment.architecture), ...
    string(experiment.method), experiment.poolSize, experiment.delayStep, ...
    string(experiment.hypothesis), ...
    'VariableNames', {'architecture','generator_method','pool_size', ...
    'delay_step','hypothesis'});
writetable(configuration, fullfile(outputRoot, 'config.csv'));

fullRows = metrics(metrics.dataset == "full_416", :);
hardwareRows = metrics(metrics.dataset == "hardware_100", :);
fullFinal = fullRows(fullRows.stream_length == 1023, :);
hardwareFinal = hardwareRows(hardwareRows.stream_length == 1023, :);

readmePath = fullfile(outputRoot, 'README.md');
fid = fopen(readmePath, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# %s\n\n', experiment.title);
fprintf(fid, '- 架构：`%s`\n', experiment.architecture);
fprintf(fid, '- 生成方式：`%s`\n', experiment.method);
fprintf(fid, '- 日期：2026-08-15\n\n');
fprintf(fid, '## 研究问题与假设\n\n%s\n\n', experiment.hypothesis);
fprintf(fid, '## 控制变量\n\n32维Q8特征、相同N/V模板、相同100拍和416拍数据、相同流长集合与判决规则。\n\n');
fprintf(fid, '## 1023周期结果\n\n');
fprintf(fid, '- 416拍：Accuracy %.4f%%，V类F1 %.4f%%，与Q8一致率 %.4f%%。\n', ...
    100*fullFinal.accuracy, 100*fullFinal.F1_V, 100*fullFinal.agreement_with_q8);
fprintf(fid, '- 100拍：Accuracy %.4f%%，与Q8一致率 %.4f%%，额外错误 %d。\n', ...
    100*hardwareFinal.accuracy, 100*hardwareFinal.agreement_with_q8, ...
    hardwareFinal.disagreements_with_q8);
fprintf(fid, '- 乘法对平均|SCC|：%.6f；95%%分位：%.6f；最大：%.6f。\n', ...
    sourceMetrics.pair_abs_SCC_mean(1), sourceMetrics.pair_abs_SCC_p95(1), ...
    sourceMetrics.pair_abs_SCC_max(1));
fprintf(fid, '- 随机寄存器数量估计：%g；寄存器位数估计：%g。\n\n', ...
    wordMetrics.random_register_count, wordMetrics.random_register_bits);
fprintf(fid, '## 本轮改善与不尽如人意\n\n');
if hardwareFinal.agreement_with_q8 == 1
    fprintf(fid, '1023周期完全保持Q8判决；后续重点检查资源和短流长表现。\n');
else
    fprintf(fid, '1023周期仍有%d个相对Q8判决错误，不能仅凭资源下降称为成功优化。\n', ...
        hardwareFinal.disagreements_with_q8);
end
fprintf(fid, '\n具体异常样本、流长曲线和误差见同目录CSV。\n\n');
fprintf(fid, '## 局限与下一步\n\n该结果仍来自记录119；随机寄存器数量只是结构估计，最终资源和功耗必须由统一RTL综合确认。\n');
end

