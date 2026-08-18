function config = project_config()
%PROJECT_CONFIG Return the frozen configuration for the prepublish project.

config.projectRoot = fileparts(fileparts(mfilename('fullpath')));
config.sampleRateHz = 360;
config.preSamples = 90;
config.postSamples = 162;
config.beatLength = 252;
config.featureDimension = 32;
config.qScale = 127;
config.lfsrWidth = 10;
config.lfsrPeriod = 1023;
config.streamLengths = [63, 127, 255, 511, 1023];
config.finalStreamLength = 1023;
config.fpgaPart = "xc7a35tcsg324-1";
config.clockPeriodNs = 10.0;
config.randomSeed = 20260815;

config.dataRoot = fullfile(config.projectRoot, 'data', 'raw');
config.resultRoot = fullfile(config.projectRoot, 'results');
config.interfaceRoot = fullfile(config.projectRoot, 'interface');
config.referenceRoot = fullfile(config.projectRoot, 'references');
config.wfdbMcodeRoot = fullfile(config.projectRoot, 'third_party', 'wfdb', 'mcode');
end

