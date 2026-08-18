function calibration = loadScNoisyCalibrationDataset(config)
%LOADSCNOISYCALIBRATIONDATASET Load injected-noise beats from training time.
% The time split keeps these beats disjoint from the paired test set.

sourcePath = fullfile(config.resultRoot, 'day03_baseline', 'beats_119_processed.mat');
source = load(sourcePath, 'models', 'trainMask', 'inInjectedNoiseBlock', ...
    'beatLabels', 'beatPositions');
modelIndex = find([source.models.dimension] == config.featureDimension, 1);
model = source.models(modelIndex);
mask = logical(source.trainMask(:)) & logical(source.inInjectedNoiseBlock(:));
calibration.name = "calibration_noisy_train";
calibration.features = int8(model.noisyQ8(mask, :));
calibration.labels = string(source.beatLabels(mask));
calibration.beatIndex = source.beatPositions(mask);
assert(~isempty(calibration.features), 'No injected-noise training beats were found.');
end
