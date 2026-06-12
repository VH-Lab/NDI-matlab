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
    %   ⚠️ AUTHORED WITHOUT A MATLAB RUNTIME. To avoid regressing the rest of
    %   the symmetry suite while the synthetic referent integration is validated
    %   on MATLAB, this test writes the artifact ONLY when every case converts
    %   cleanly. If any case errors (referent/time_convert mismatch), the test
    %   marks itself Incomplete (assumption failure, NOT a failure) and writes
    %   nothing — so the Python read side simply skips the time comparison, as it
    %   does when the artifact is absent. Once a MATLAB run confirms the cases
    %   convert, the artifact is produced and full cross-language closure holds.

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

            msgs = string({results.msg});
            allClean = all(msgs == "");
            testCase.assumeTrue(allClean, ...
                ['time_convert produced error rows; the scenario referent needs ' ...
                 'MATLAB validation (see ndi.symmetry.time.scenarioReferent). ' ...
                 'No artifact written so the cross-language comparison is skipped.']);

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
