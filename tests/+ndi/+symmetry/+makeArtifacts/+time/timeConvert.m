classdef timeConvert < matlab.unittest.TestCase
    % timeConvert (makeArtifacts/time) - generate the time_convert symmetry
    % artifact for cross-language comparison with NDI-python.
    %
    %   Runs the shared ndi.symmetry.time.scenario battery through the real
    %   ndi.time.syncgraph/time_convert and writes the scenario + computed
    %   outputs to:
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/time/timeConvert/
    %              testTimeConvertArtifacts/timeConvertCases.json
    %
    %   The Python counterpart writes the same structure under pythonArtifacts/;
    %   the readArtifacts tests on both sides compare them.
    %
    %   MATLAB is the reference side: this test ASSERTS that every scenario
    %   case converts without error and equals the expected reference output
    %   (ndi.symmetry.time.scenario.expected), then writes the artifact for the
    %   Python suite to match. A time_convert regression fails here loudly
    %   rather than skipping. (The earlier version used assumeTrue to mark
    %   itself Incomplete and write nothing on any conversion error, which
    %   silently masked a real time_convert bug; that skip has been removed.)

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testTimeConvertArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'time', 'timeConvert', 'testTimeConvertArtifacts');

            % time_convert builds an ndi.time.timereference, which requires the
            % referent to carry a real ndi.session; create a throwaway one.
            sessionPath = [tempname() '_ndi_sym_time'];
            mkdir(sessionPath);
            session = ndi.session.dir('symref', sessionPath);

            results = ndi.symmetry.time.scenario.runCases(session);

            % MATLAB is the reference: assert every case converted without error
            % AND produced the expected (reference) value, rather than skipping
            % via assumeTrue (which silently masked time_convert failures).
            msgs = string({results.msg});
            testCase.verifyTrue(all(msgs == ""), ...
                "time_convert produced error rows: " + strjoin(msgs(msgs ~= ""), "; "));
            ndi.symmetry.time.scenario.verifyExpected(testCase, results);

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            payload = struct();
            payload.description = "syncgraph time_convert symmetry cases";
            payload.scenario    = ndi.symmetry.time.scenario.scenarioStruct();
            payload.cases       = results;

            jsonStr = jsonencode(payload, 'PrettyPrint', true);
            outFile = fullfile(artifactDir, 'timeConvertCases.json');
            fid = fopen(outFile, 'w');
            testCase.assertGreaterThan(fid, 0, 'Could not open timeConvertCases.json for writing.');
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, jsonStr, 'char');
            clear cleaner;

            testCase.verifyTrue(isfile(outFile), 'Artifact file was not written.');
            testCase.verifyEqual(numel(results), 7, 'Expected 7 recorded cases.');
        end
    end
end
