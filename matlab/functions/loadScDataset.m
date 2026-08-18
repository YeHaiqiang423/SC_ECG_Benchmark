function dataset = loadScDataset(config)
%LOADSCDATASET Load full paired and 100-beat hardware q8 datasets.

processedPath = fullfile(config.resultRoot, 'day03_baseline', ...
    'beats_119_processed.mat');
assert(isfile(processedPath), 'Missing processed baseline: %s', processedPath);
S = load(processedPath);
M = S.models(S.selectedModelIndex);
assert(S.selectedDimension == config.featureDimension);

pairedIndices = find(S.pairedTestMask);
dataset.full.name = "full_416";
dataset.full.features = int16(M.noisyQ8(pairedIndices, :));
dataset.full.labels = string(S.beatLabels(pairedIndices));
dataset.full.beatIndex = double(pairedIndices(:));

hardwareIndices = double(S.hardwareIndices(:));
dataset.hardware.name = "hardware_100";
dataset.hardware.features = int16(M.noisyQ8(hardwareIndices, :));
dataset.hardware.labels = string(S.beatLabels(hardwareIndices));
dataset.hardware.beatIndex = hardwareIndices;

dataset.templateN = int16(M.templateNQ8(:).');
dataset.templateV = int16(M.templateVQ8(:).');
dataset.dimension = S.selectedDimension;
dataset.sourcePath = processedPath;
end

