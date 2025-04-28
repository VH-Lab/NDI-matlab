classdef OneEpochTest < matlab.unittest.TestCase
    %ONEEPOCHTEST is a unittest for testing the functionality of the 
    %   NDI.ELEMENT.ONEPOCH function by creating temporary test files and 
    %   verifying the output.

    properties (Constant)
        SR = 20000; % Sampling rate for test files (Hz)
        NumSamples = 999; % Number of samples per channel
        NumChannels = 3; % Number of channels
        HeaderBytes = 8;  % Standard header size for WM files
        ByteOrder = 'ieee-le'; % Default byte order
        DataType = 'int16'; % Data type for samples
    end
       
    properties (SetAccess = protected)
        TempDir char % Temporary directory for test files
        DataFile char  % Store the full path to the data file
        ProbeFile char % Store the full path to the epoch probe map file
        Reader % The reader object instance
        HeaderInfo struct = struct() % Store the parsed header info
    end

    %  methods('matlab.unittest.TestCase')

    % Runs once before all tests in the class
    methods (TestClassSetup)
        function setupSession(testCase)
            disp('Setting up test session for ndi.element.onepoch...');

            % Create a temporary directory
            import matlab.unittest.fixtures.WorkingFolderFixture
            tempFolderFix = testCase.applyFixture(WorkingFolderFixture);
            disp(tempFolderFix.SetupDescription);
            testCase.TempDir = tempFolderFix.Folder;

            % Generate Filename based on white matter parameters
            dateStringForFilename = string(datetime('now'), 'yyyy_MM_dd__HH_mm_ss');
            durationSec = double(testCase.NumSamples) / testCase.SR;
            durationMin = floor(durationSec / 60);
            durationSecRem = round(rem(durationSec, 60));
            devType = ['testdev_' num2str(testCase.NumChannels) 'ch']; % Example device type
            baseFilename = sprintf('HSW_%s__%02dmin_%02dsec__%s_%dsps', ...
                dateStringForFilename,durationMin, durationSecRem, ...
                devType, testCase.SR);
            testCase.DataFile = fullfile(testCase.TempDir, strcat(baseFilename,'.bin'));

            % Initialize the reader here
            testCase.Reader = ndr.reader('whitematter');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader initialization failed.');

            % Generate Data
            data = zeros(testCase.NumSamples, testCase.NumChannels, testCase.DataType);
            for c = 1:testCase.NumChannels
                start_val = (c-1) * 1000 + 1;
                end_val = start_val + testCase.NumSamples - 1;
                data(:, c) = cast(start_val:end_val,testCase.DataType)';
            end

            % Interleave data (MATLAB stores column-major, file needs row-major samples)
            % Reshape to Samples x Channels, then transpose to Channels x Samples, then linearize
            interleavedData = reshape(data', 1, []);

            % Write file
            fid = fopen(testCase.DataFile, 'w', testCase.ByteOrder);
            testCase.addTeardown(@fclose,fid)
            testCase.assertNotEqual(fid, -1, ['Could not open test file for writing: ' testCase.DataFile]);

            % Write dummy header
            fwrite(fid, zeros(1, testCase.HeaderBytes), 'uint8');

            % Write interleaved data
            count = fwrite(fid, interleavedData, testCase.DataType);
            
            % Close file and get HeaderInfo
            fclose(fid);
            testCase.assertEqual(count, numel(interleavedData), 'Incorrect number of samples written to test file.');
            testCase.HeaderInfo = ndr.format.whitematter.header(testCase.DataFile);
            disp(['Created test file: ' testCase.DataFile ' with ' num2str(testCase.NumChannels) ' channels.']);
            disp('Setup complete.');
            
            % Create epochprobemap files
            for i = 1:testCase.NumChannels
                probemap(i) = ndi.epoch.epochprobemap_daqsystem(sprintf('channel%i',i),...
                    1,'ppg','whitematter','wmTest');
            end
            testCase.ProbeFile = fullfile(testCase.TempDir, strcat(baseFilename,'.epochprobemap.txt'));
            probemap.savetofile(testCase.ProbeFile)
            
            % Start NDI session and add White Matter DAQ system
            S = ndi.session.dir('temp',testCase.TempDir);
            wm_filenav = ndi.file.navigator(S, ...
                {'#.bin', '#.epochprobemap.txt'}, ...
                'ndi.epoch.epochprobemap_daqsystem','#.epochprobemap.txt');
            wm_rdr = ndi.daq.reader.mfdaq.ndr('whitematter');
            wm_system = ndi.daq.system.mfdaq('wm_daqsystem', wm_filenav, wm_rdr);
            if ~isempty(S.daqsystem_load)
                S.daqsystem_clear();
            end
            S.daqsystem_add(wm_system);

            % et = wm_filenav.epochtable()
            % ef = et(1).underlying_epochs.underlying
            % wm_system.getchannelsepoch(1)

            S.ingest()
            S.getprobes
            
        end

        function setupClass(testCase)
            
            testCase.ndi_session = ndi.session.dir(testCase.ndi_session_path);
            p = testCase.ndi_session.getprobes('type','ppg');
            testCase.ndi_element_timeseries_in = p{1};
            testCase.name_out = [testCase.ndi_element_timeseries_in.name,'_test'];
            testCase.ref_out = testCase.ndi_element_timeseries_in.reference;

            % Create a temporary working directory to run tests in
            % testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            % 
            % % Create an empty database with a starting branch
            % testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            % 
            % testCase.generateTree()
        end
    end

    methods (TestMethodSetup)
        % Setup for each test
    end

    methods (Test)
        % Test methods

        function oneepochTest(testCase)
            [testCase.ndi_element_timeseries_out] = ...
                ndi.element.oneepoch(testCase.ndi_session,...
                testCase.ndi_element_timeseries_in,...
                testCase.name_out,testCase.ref_out);
        end

        function unimplementedTest(testCase)
            testCase.verifyFail("Unimplemented test");
        end

        % output time and data should have the same length
        % output epoch table should only have one epoch
        % output should work even if oneepoch already existed
    end

end