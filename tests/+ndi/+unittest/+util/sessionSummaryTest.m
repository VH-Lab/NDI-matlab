classdef sessionSummaryTest < matlab.unittest.TestCase

    methods (Test)
        function testCompareIdenticalSummaries(testCase)
            % Create an arbitrary complex struct simulating a session summary
            s1 = struct();
            s1.reference = 'test_ref';
            s1.sessionId = '12345';
            s1.files = {'a.txt', 'b.txt'};
            s1.daqSystemNames = {'daq1'};
            s1.daqSystemDetails = struct('filenavigator_class', 'ndi.file.navigator', 'epochNodes_daqsystem', []);
            s1.probes = {struct('name', 'probe1', 'type', 'n-trode')};

            s2 = s1; % Identical

            report = ndi.util.compareSessionSummary(s1, s2);
            testCase.verifyEmpty(report, 'Report should be empty for identical summaries.');
        end

        function testCompareDifferingSummaries(testCase)
            % Create two slightly differing summaries
            s1 = struct();
            s1.reference = 'test_ref';
            s1.sessionId = '12345';
            s1.files = {'a.txt'};
            s1.extraField = 1;

            s2 = struct();
            s2.reference = 'test_ref2'; % Difference 1
            s2.sessionId = '12345';
            s2.files = {'a.txt', 'b.txt'}; % Difference 2
            % Missing extraField -> Difference 3

            report = ndi.util.compareSessionSummary(s1, s2);

            testCase.verifyNotEmpty(report, 'Report should not be empty for differing summaries.');
            testCase.verifyNumElements(report, 3, 'There should be 3 differences reported.');

            % Check that specific errors are mentioned
            reportStr = strjoin(report, ' ');
            testCase.verifyTrue(contains(reportStr, 'extraField is in summary1 but not summary2'), 'Missing field not reported.');
            testCase.verifyTrue(contains(reportStr, 'reference differs'), 'String mismatch not reported.');
            testCase.verifyTrue(contains(reportStr, 'files has different lengths'), 'Cell array length mismatch not reported.');
        end

        function testSessionSummaryGeneration(testCase)
            % Use the buildSession test utility to create a real session
            builder = ndi.unittest.session.buildSession();
            builder.buildSessionSetup();
            session = builder.Session;

            % Generate summary
            summary = ndi.util.sessionSummary(session);

            % Verify key fields exist and are populated
            testCase.verifyTrue(isfield(summary, 'reference'));
            testCase.verifyTrue(isfield(summary, 'sessionId'));
            testCase.verifyTrue(isfield(summary, 'files'));
            testCase.verifyTrue(isfield(summary, 'filesInDotNDI'));
            testCase.verifyTrue(isfield(summary, 'daqSystemNames'));
            testCase.verifyTrue(isfield(summary, 'daqSystemDetails'));
            testCase.verifyTrue(isfield(summary, 'probes'));

            % Verify types
            testCase.verifyClass(summary.files, 'cell');
            testCase.verifyClass(summary.daqSystemDetails, 'struct');
            testCase.verifyClass(summary.probes, 'struct');

            % Cleanup
            builder.buildSessionTeardown();
        end
    end
end