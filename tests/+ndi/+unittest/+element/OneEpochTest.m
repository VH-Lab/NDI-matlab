classdef OneEpochTest < matlab.unittest.TestCase
    %ONEEPOCHTEST is a unittest for testing the functionality of the 
    %   NDI.ELEMENT.ONEPOCH function by creating temporary test files and 
    %   verifying the output.

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
            disp('Class Setup complete.');
        end
    end

    methods (TestMethodSetup)
        function addTestData(testCase)
            % Add epochs to NDI session
            testCase.Session = ndi.unittest.helper.addWhiteMatterEpochs(testCase.Session);

            % Ingest data and get probes
            testCase.Session.ingest();
            testCase.Probes = testCase.Session.getprobes();
        end
        
        function runOneEpoch(testCase)
            % Run onepoch to concatenate epochs
            for i = 1:numel(testCase.Probes)
                testCase.OneEpoch{i} = ndi.element.oneepoch(testCase.Session,...
                    testCase.Probes{i},...
                    [testCase.Probes{i}.name '_oneepoch'],...
                    testCase.Probes{i}.reference);
            end
        end
    end

    methods(TestMethodTeardown)
        function removeTestData(testCase)
            disp('need to remove epochs and clear cache')
        end
    end

    methods (Test)
        % Test methods
        function testClass(testCase)
             for i = 1:numel(testCase.Probes)
                 testCase.assertClass(testCase.OneEpoch{i},'ndi.element.timeseries',...
                    'OneEpoch is not an NDI element timeseries.');
             end
             disp('test1')
        end

        function testClass2(testCase)
             for i = 1:numel(testCase.Probes)
                 testCase.assertClass(testCase.OneEpoch{i},'ndi.element.timeseries',...
                    'OneEpoch is not an NDI element timeseries.');
             end
             disp('test2')
        end
        
        % output time and data should have the same length
        % output epoch table should only have one epoch
        % output should work even if oneepoch already existed
    end

end