classdef OneEpochTest < matlab.unittest.TestCase
    %ONEEPOCHTEST is a unittest for testing the functionality of the 
    %   NDI.ELEMENT.ONEPOCH function by creating temporary test files and 
    %   verifying the output.
    %
    %   TestClassSetup
    %       1. Create temporary directory and NDI session
    %       2. Add subjects to NDI session
    %
    %   TestMethodTeardown
    %       1. 
    %
    %   Tests


    properties (Constant)
        NumSubjects = 2; % Number of subjects
        NumSamples = 100; % Number of samples per channel
        NumChannels = 3; % Number of channels per subject
        NumEpochs = 3; % Number of epochs
        SampleRate = 100; % Sampling rate (Hz)
    end
       
    properties (SetAccess = protected)
        TempDir char % Temporary directory for test files
        Session % Store the NDI session
        DataFile char  % Store the full path to the data file
        ProbeFile char % Store the full path to the epoch probe map file
        Reader % The reader object instance
        HeaderInfo struct = struct() % Store the parsed header info
        Probes % Store the NDI probes
        OneEpoch % Store the OneEpoch elements
        
    end

    % Runs once before all tests in the class
    methods (TestClassSetup)
        function setupSession(testCase)
            disp('Setting up test session for ndi.element.onepoch...');

            % Create temporary directory and NDI session
            import ndi.unittest.fixtures.CreateWhiteMatterSessionFixture
            whiteMatterSession = testCase.applyFixture(CreateWhiteMatterSessionFixture);
            testCase.TempDir = whiteMatterSession.TempDir;
            testCase.Session = whiteMatterSession.Session;
            
            % Add subjects to NDI session
            import ndi.unittest.fixtures.AddWhiteMatterSubjectsFixture
            f = AddWhiteMatterSubjectsFixture(testCase.Session,testCase.NumSubjects);
            whiteMatterSubjects = testCase.applyFixture(f);
            testCase.Session = whiteMatterSubjects.Session;
            
            % Ingest
            testCase.Session.ingest();
            disp('Class Setup complete.');
        end
    end

    methods(TestMethodTeardown)
        function teardown(testCase)
            testCase.clearAllElements(testCase);
            testCase.clearTestData(testCase);
        end
    end

    methods (Test)
        % Test methods
        function testNewDataset(testCase)
            testCase.addTestData(testCase);
            testCase.addOneEpochElements(testCase);
            testCase.testOneEpoch(testCase);
        end

        function testAdditionalData(testCase)
            testCase.addTestData(testCase);
            testCase.addOneEpochElements(testCase);
            for i = 1:numel(testCase.Probes)
                testCase.assertClass(testCase.OneEpoch{i},'ndi.element.timeseries',...
                    'OneEpoch is not an NDI element timeseries.');
            end
            testCase.addTestData(testCase);
            testCase.addOneEpochElements(testCase);
            testCase.testOneEpoch(testCase);
        end

        function testDuplicateAction(testCase)
            testCase.addTestData(testCase);
            testCase.addOneEpochElements(testCase);
            testCase.addOneEpochElements(testCase);
            testCase.testOneEpoch(testCase);
        end
    end

    methods (Static)
        function addTestData(testCase)
            % Add epochs to NDI session
            ndi.unittest.helper.createWhiteMatterEpochs(testCase.Session);

            % Get probes
            testCase.Probes = testCase.Session.getprobes();
        end

        function clearTestData(testCase)
            % Remove all epochs from temporary directory
            filenames = dir(testCase.TempDir);
            for i = find(~[filenames.isdir])
                delete(filenames(i).name);
            end
        end

        function clearAllElements(testCase)
            % Remove all elements from database
            for i = 1:numel(testCase.Probes)
                testCase.Session.database_rm(testCase.Probes{i}.id);
            end
            testCase.Probes = testCase.Session.getprobes;
            testCase.Session.cache.clear;
        end

        
        function addOneEpochElements(testCase)
            % Run onepoch to concatenate epochs
            for i = 1:numel(testCase.Probes)
                testCase.OneEpoch{i} = ndi.element.oneepoch(testCase.Session,...
                    testCase.Probes{i},...
                    [testCase.Probes{i}.name '_oneepoch'],...
                    testCase.Probes{i}.reference);
            end
        end
        
        function removeOneEpochElements(testCase)
            for i = 1:numel(testCase.Probes)
                e = testCase.Session.getelements('element.name',...
                    [testCase.Probes{i}.name '_oneepoch'],...
                    'element.reference',testCase.Probes{i}.reference);
                testCase.Session.database_rm(e{1}.id);
            end
            testCase.OneEpoch = [];
        end

        function testOneEpoch(testCase)

            for i = numel(testCase.Probes)
                % Get elements
                probe = testCase.Probes{i};
                oneepoch = testCase.OneEpoch{i};
                testCase.assertClass(oneepoch,'ndi.element.timeseries',...
                    'OneEpoch is not an NDI element timeseries.');

                % Get epoch tables
                probe_et = probe.epochtable;
                oneepoch_et = oneepoch.epochtable;
                testCase.verifyEqual(oneepoch_et.epoch_clock,probe_et(1).epoch_clock,...
                    'OneEpoch clock type(s) do not match those of the original timeseries.')
                testCase.verifySize(oneepoch_et,[1,1],...
                    'OneEpoch epoch table does not contain a single epoch.')

                % Get data
                probe_data = [];
                for j = 1:numel(probe_et)
                    probe_data = cat(1,probe_data,probe.readtimeseries(j,-Inf,Inf));
                end
                oneepoch_data = oneepoch.readtimeseries(1,-Inf,Inf);
                testCase.verifySize(oneepoch_data,size(probe_data),...
                    'OneEpoch does not return the expected number of samples.')
                testCase.verifyClass(oneepoch_data,class(probe_data),...
                    'OneEpoch is of a different class than the original timeseries.')

            end
        end
    end

end