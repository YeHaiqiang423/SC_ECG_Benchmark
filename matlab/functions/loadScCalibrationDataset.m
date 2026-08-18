function calibration = loadScCalibrationDataset(config)
%LOADSCCALIBRATIONDATASET Load clean training beats for architecture search.
% These samples are not part of the noisy paired test set used for reporting.

sourcePath = fullfile(config.resultRoot, 'day03_baseline', 'beats_119_processed.mat');
source = load(sourcePath, 'models', 'trainMask', 'beatLabels', 'beatPositions');
modelIndex = find([source.models.dimension] == config.featureDimension, 1);
model = source.models(modelIndex);
mask = logical(source.trainMask(:));
calibration.name = "calibration_clean_train";
calibration.features = int8(model.cleanQ8(mask, :));
calibration.labels = string(source.beatLabels(mask));
calibration.beatIndex = source.beatPositions(mask);
end
