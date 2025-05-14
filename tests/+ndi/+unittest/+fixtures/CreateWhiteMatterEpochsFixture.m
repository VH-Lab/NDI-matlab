classdef CreateWhiteMatterEpochsFixture < matlab.unittest.fixtures.Fixture
% Create white matter data and epoch probe map files and add them to the
% NDI session

    properties (SetAccess = private)
        Session % Temporary NDI session
        Probes % Store the NDI probes
        NumEpochs % Number of epochs
        NumChannels % Number of channels per subject
        NumSamples % Number of samples per epoch/channel
        SampleRate % Sampling rate (Hz)
        DataType % Data type for samples
        ByteOrder % Default byte order
        HeaderBytes % Standard header size for WM files
        DataFileNames % Cell array of temporary data files
        ProbeFileNames % Cell array of temporary epochprobemap files
    end

    methods
        function fixture = CreateWhiteMatterEpochsFixture(Session,options)
            arguments
                Session {mustBeA(Session,{'ndi.session', 'ndi.dataset'})}
                options.NumEpochs (1,1) double {mustBePositive} = 2;
                options.NumChannels (1,1) double {mustBePositive} = 1;
                options.NumSamples (1,1) double {mustBePositive} = 1000;
                options.SampleRate (1,1) double {mustBePositive} = 100;
                options.DataType char = 'int16';
                options.ByteOrder char = 'ieee-le';
                options.HeaderBytes (1,1) double {mustBePositive} = 8;
            end

            fixture.Session = Session;
            optionNames = fieldnames(options);
            for i = 1:numel(optionNames)
                fixture.(optionNames{i}) = options.(optionNames{i});
            end
        end

        function setup(fixture)

            dataFilenames = cell(fixture.NumEpochs,1);
            probeFilenames = cell(fixture.NumEpochs,1);

            S = fixture.Session;

            % Get subjects
            mysub = S.database_search(ndi.query('','isa','subject'));
            subjects = cell(numel(mysub),1);
            for s = 1:numel(mysub)
                subjects{s} =  mysub{s}.document_properties.subject.local_identifier;
            end

            % Create data for each epoch
            nowTime = datetime('now');
            durationSec = double(fixture.NumSamples) / fixture.SampleRate;
            assert(durationSec >= 1,'Duration of each epoch must be at least 1 second.');
            durationMin = floor(durationSec / 60);
            durationSecRem = round(rem(durationSec, 60));
            devType = ['testdev_' num2str(fixture.NumChannels) 'ch']; % Example device type
            for e = 1:fixture.NumEpochs

                % Generate Filename based on white matter parameters
                dateStringForFilename = string(nowTime + seconds(durationSec)*(e-1),...
                    'yyyy_MM_dd__HH_mm_ss');
                baseFilename = sprintf('HSW_%s__%02dmin_%02dsec__%s_%dsps', ...
                    dateStringForFilename,durationMin, durationSecRem, ...
                    devType, fixture.SampleRate);
                dataFilenames{e} = fullfile(S.path, strcat(baseFilename,'.bin'));

                % Generate Data
                data = zeros(fixture.NumSamples, ...
                    fixture.NumChannels*numel(subjects), fixture.DataType);
                for c = 1:fixture.NumChannels*numel(subjects)
                    start_val = (c-1) * fixture.NumSamples + 1;
                    end_val = start_val + fixture.NumSamples - 1;
                    data(:, c) = cast(start_val:end_val,fixture.DataType)';
                end

                % Interleave data (MATLAB stores column-major, file needs row-major samples)
                % Reshape to Samples x Channels, then transpose to Channels x Samples, then linearize
                interleavedData = reshape(data', 1, []);

                % Write file
                fid = fopen(dataFilenames{e}, 'w', fixture.ByteOrder);
                assert(fid ~= -1,['Could not open test file for writing: ' dataFilenames{e}]);

                % Write dummy header
                fwrite(fid, zeros(1, fixture.HeaderBytes), 'uint8');

                % Write interleaved data
                count = fwrite(fid, interleavedData, fixture.DataType);

                % Close file
                fclose(fid);
                assert(count==numel(interleavedData),...
                    'Incorrect number of samples written to test file.');

                % Create accompanying epochprobemap files
                for s = 1:numel(subjects)
                    for c = 1:fixture.NumChannels
                        probemap(c) = ndi.epoch.epochprobemap_daqsystem(sprintf('channel%i',c),...
                            1,'n-trode',sprintf('wm_daqsystem:ai%i',c),subjects{s});
                    end
                end
                probeFilenames{e} = fullfile(S.path,strcat(baseFilename,'.epochprobemap.txt'));
                probemap.savetofile(probeFilenames{e});
            end

            fixture.DataFileNames = dataFilenames;
            fixture.ProbeFileNames = probeFilenames;

            fixture.Probes = fixture.Session.getprobes;

            fixture.SetupDescription = sprintf('   Added %i test file(s) with %i channel(s) to the folder "%s".',...
                fixture.NumEpochs,fixture.NumChannels,S.path);
            fixture.TeardownDescription = sprintf('   Deleted %i test file(s) from the folder "%s".',...
                fixture.NumEpochs,S.path);
        end

        function teardown(fixture)
            % Remove files from temporary directory
            for e = 1:fixture.NumEpochs
                delete(fixture.DataFileNames{e});
                delete(fixture.ProbeFileNames{e});
            end
            disp(fixture.TeardownDescription)
        end

    end

    methods (Access=protected)
        function tf = isCompatible(fixture1,fixture2)
            tf = fixture1.Format == fixture2.Format;
        end
    end
end