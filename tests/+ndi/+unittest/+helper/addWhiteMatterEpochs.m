function [S,dataFileNames,probeFileNames] = addWhiteMatterEpochs(S,options)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
% Create data for each epoch

arguments
    S {mustBeA(S, ["ndi.session", "ndi.dataset"])}
    options.NumEpochs (1,1) double {mustBePositive} = 2; % Number of epochs
    options.NumChannels (1,1) double {mustBePositive} = 1; % Number of channels per subject
    options.NumSamples (1,1) double {mustBePositive} = 1000; % Number of samples per epoch/channel
    options.SampleRate (1,1) double {mustBePositive} = 100; % Sampling rate (Hz)
    options.DataType char = 'int16'; % Data type for samples
    options.ByteOrder char = 'ieee-le'; % Default byte order
    options.HeaderBytes (1,1) double {mustBePositive} = 8;  % Standard header size for WM files
end

dataFilenames = cell(options.NumEpochs,1);
probeFilenames = cell(options.NumEpochs,1);

% Get subjects
mysub = S.database_search(ndi.query('','isa','subject'));
subjects = cell(numel(mysub),1);
for s = 1:numel(mysub)
    subjects{s} =  mysub{s}.document_properties.subject.local_identifier;
end

% Create data for each epoch
nowTime = datetime('now');
durationSec = double(options.NumSamples) / options.SampleRate;
assert(durationSec >= 1,'Duration of each epoch must be at least 1 second.');
durationMin = floor(durationSec / 60);
durationSecRem = round(rem(durationSec, 60));
devType = ['testdev_' num2str(options.NumChannels) 'ch']; % Example device type
for e = 1:options.NumEpochs

    % Generate Filename based on white matter parameters
    dateStringForFilename = string(nowTime + seconds(durationSec)*(e-1),...
        'yyyy_MM_dd__HH_mm_ss');
    baseFilename = sprintf('HSW_%s__%02dmin_%02dsec__%s_%dsps', ...
        dateStringForFilename,durationMin, durationSecRem, ...
        devType, options.SampleRate);
    dataFilenames{e} = fullfile(S.path, strcat(baseFilename,'.bin'));

    % Generate Data
    data = zeros(options.NumSamples, ...
        options.NumChannels*numel(subjects), options.DataType);
    for c = 1:options.NumChannels*numel(subjects)
        start_val = (c-1) * options.NumSamples + 1;
        end_val = start_val + options.NumSamples - 1;
        data(:, c) = cast(start_val:end_val,options.DataType)';
    end

    % Interleave data (MATLAB stores column-major, file needs row-major samples)
    % Reshape to Samples x Channels, then transpose to Channels x Samples, then linearize
    interleavedData = reshape(data', 1, []);

    % Write file
    fid = fopen(dataFilenames{e}, 'w', options.ByteOrder);
    assert(fid ~= -1,['Could not open test file for writing: ' dataFilenames{e}]);

    % Write dummy header
    fwrite(fid, zeros(1, options.HeaderBytes), 'uint8');

    % Write interleaved data
    count = fwrite(fid, interleavedData, options.DataType);

    % Close file
    fclose(fid);
    assert(count==numel(interleavedData),...
        'Incorrect number of samples written to test file.');
    disp(['Created test file ' num2str(e) ': ' dataFilenames{e} ' with ' ...
        num2str(options.NumChannels) ' channels.']);

    % Create accompanying epochprobemap files
    for s = 1:numel(subjects)
        for c = 1:options.NumChannels
            probemap(c) = ndi.epoch.epochprobemap_daqsystem(sprintf('channel%i',c),...
                1,'n-trode',sprintf('wm_daqsystem:ai%i',c),subjects{s});
        end
    end
    probeFilenames{e} = fullfile(S.path,strcat(baseFilename,'.epochprobemap.txt'));
    probemap.savetofile(probeFilenames{e});
end

end