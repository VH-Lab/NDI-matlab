classdef OneEpochTest < matlab.unittest.TestCase
%ONEEPOCHTEST is a unittest for testing the functionality of the 
%   NDI.ELEMENT.ONEPOCH function by creating temporary test files and 
%   verifying the output.
%
%   TestClassSetup
%       - setup - Create temporary directory and NDI session and add subjects
%
%   TestMethodTeardown
%       - teardown - Remove all elements from database
%
%   Test
%       1. testNewDataset - test oneepoch on new dataset
%       2. testAdditionalData - test one epoch when additional data is 
%           added to existing dataset
%       3. testDuplicateAction - test one epoch when existing data set is 
%           unchanged
%
%   Methods
%       - addTestData - add epochs to the directory and getprobes
%       - addOneEpochElements - run oneepoch
%       - testOneEpoch - run tests comparing oneepoch to expected output
%
% See also: NDI.UNITTEST.FIXTURES.CREATEWHITEMATTERSESSIONFIXTURE,
%   NDI.UNITTEST.FIXTURES.CREATEWHITEMATTERSUBJECTSFIXTURE,
%   NDI.UNITTEST.FIXTURES.CREATEWHITEMATTEREPOCHSFIXTURE
       
    properties (SetAccess = protected)
        TempDir char % Temporary directory for test files
        Session % Store the NDI session
        Probes cell % Cell array that stores the NDI probes
        OneEpoch cell % Cell array that stores the OneEpoch elements
    end

    properties (ClassSetupParameter)
        NumSubjects = {1,2} % Number of subjects
    end

    properties (TestParameter)
        NumEpochs = {1,2} % Number of epochs
    end

    % Runs once before all tests in the class
    methods (TestClassSetup)
        function setupSession(testCase,NumSubjects)

            % Create temporary directory and NDI session
            import ndi.unittest.fixtures.CreateWhiteMatterSessionFixture
            whiteMatterSession = testCase.applyFixture(CreateWhiteMatterSessionFixture);
            testCase.TempDir = whiteMatterSession.TempDir;
            testCase.Session = whiteMatterSession.Session;
            disp(whiteMatterSession.SetupDescription)
            
            % Add subjects to NDI session
            import ndi.unittest.fixtures.CreateWhiteMatterSubjectsFixture
            whiteMatterSubjects = CreateWhiteMatterSubjectsFixture(testCase.Session,...
                'NumSubjects',NumSubjects);
            testCase.applyFixture(whiteMatterSubjects);
            testCase.Session = whiteMatterSubjects.Session;
            disp(whiteMatterSubjects.SetupDescription)
            
            % Ingest
            testCase.Session.ingest();
        end
    end

    methods(TestMethodTeardown)
        function teardown(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture( ...
                SuppressedWarningsFixture('NDISESSION:deletingDependents'))
            
            % Remove all elements from database
            for i = 1:numel(testCase.Probes)
                testCase.Session.database_rm(testCase.Probes{i}.id);
            end
            testCase.Probes = testCase.Session.getprobes;
            testCase.Session.cache.clear;
        end
    end

    methods (Test)
        % Test methods
        function testNewDataset(testCase,NumEpochs)
            % Add test data to temp dir
            testCase.addTestData(testCase,NumEpochs);

            % Add oneepoch elements to database
            testCase.addOneEpochElements(testCase);

            % Test output
            disp('   Checking oneepoch for test data.')
            testCase.testOneEpoch(testCase);
        end

        function testAdditionalData(testCase,NumEpochs)
            % Add test data to temp dir
            testCase.addTestData(testCase,NumEpochs);

            % Add oneepoch elements to database
            testCase.addOneEpochElements(testCase);

            % Add more test data (simulate new acquistion)
            testCase.addTestData(testCase,NumEpochs);

            % Add new oneepoch elements to database
            testCase.addOneEpochElements(testCase);

            % Test output
            disp('   Checking oneepoch for additional data.')
            testCase.testOneEpoch(testCase);
        end

        function testDuplicateAction(testCase,NumEpochs)
            % Add test data to temp dir
            testCase.addTestData(testCase,NumEpochs);

            % Add new oneepoch elements to database
            testCase.addOneEpochElements(testCase);
            
            % Try adding running oneepoch again
            testCase.addOneEpochElements(testCase);

            % Test output
            disp('   Checking oneepoch run again.')
            testCase.testOneEpoch(testCase);
        end
    end

    methods (Static)
        function addTestData(testCase,NumEpochs)
            % Add epochs to NDI session
            import ndi.unittest.fixtures.CreateWhiteMatterEpochsFixture
            whiteMatterEpochs = CreateWhiteMatterEpochsFixture(testCase.Session,...
                'NumEpochs',NumEpochs);
            testCase.applyFixture(whiteMatterEpochs);
            testCase.Probes = testCase.Session.getprobes();
            disp(whiteMatterEpochs.SetupDescription)
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
                testCase.verifyEqual(oneepoch_data,double((probe_data)),...
                    'OneEpoch data points do not match the original timeseries.')
            end
        end
    end

end