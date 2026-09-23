classdef pathSafeName < matlab.unittest.TestCase
    % pathSafeName (makeArtifacts/fun) - generate the pathSafeName symmetry
    % artifact for cross-language comparison with NDI-python.
    %
    %   Runs the shared ndi.symmetry.fun.cases battery through the real
    %   ndi.fun.file.pathSafeName and ndi.fun.file.elementDirectoryName and
    %   writes the inputs + computed outputs to:
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/fun/pathSafeName/
    %              testPathSafeNameArtifacts/pathSafeNameCases.json
    %
    %   The Python counterpart writes the same structure under pythonArtifacts/;
    %   the readArtifacts tests on both sides compare them. The on-disk schema is
    %   documented in tests/+ndi/+symmetry/FUN_CASES_SCHEMA.md.
    %
    %   MATLAB is the reference side: this test ASSERTS that every case produces
    %   the expected reference output (ndi.symmetry.fun.cases.pathSafeNameDefs)
    %   before writing the artifact, so a pathSafeName regression fails here
    %   loudly rather than being quietly recorded and shipped to Python as the
    %   new truth. This follows makeArtifacts/time/timeConvert, whose earlier
    %   assumeTrue-based skip silently masked a real time_convert bug.
    %
    %   WHY THE BATTERY CARRIES ASTRAL (above U+FFFF) CASES
    %   MATLAB char arrays hold UTF-16 code units, so one astral character is a
    %   surrogate PAIR and pathSafeName emits TWO '-' for it; a naive Python port
    %   emits one. For a FILENAME contract that divergence means the two
    %   languages disagree about which folder an element's data lives in --
    %   exactly the class of bug pathSafeName was added to fix. Each case records
    %   both counts (inputUtf16Units and inputCodepointCount) so the artifact
    %   shows the difference even when the sanitized names agree.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- the expected values are derived
    %   by reading src/ndi/+ndi/+fun/+file/pathSafeName.m branch by branch, not
    %   by executing MATLAB. VALIDATE BEFORE RELYING ON IT.
    %
    %   See also: ndi.symmetry.fun.cases,
    %     ndi.symmetry.readArtifacts.fun.pathSafeName,
    %     ndi.symmetry.makeArtifacts.time.timeConvert

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testPathSafeNameArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'fun', 'pathSafeName', 'testPathSafeNameArtifacts');

            results = ndi.symmetry.fun.cases.runPathSafeNameCases();

            % MATLAB is the reference: assert every case ran and produced the
            % expected value before the artifact is written.
            ndi.symmetry.fun.cases.verifyPathSafeNameExpected(testCase, results);

            payload = struct();
            payload.schemaVersion = 1;
            payload.description = 'ndi.fun.file.pathSafeName / elementDirectoryName symmetry cases';
            payload.language = 'matlab';
            payload.generator = 'ndi.symmetry.makeArtifacts.fun.pathSafeName';
            payload.cases = results;

            ndi.symmetry.fun.cases.writeCases(testCase, artifactDir, ...
                'pathSafeNameCases.json', payload);

            testCase.verifyEqual(numel(results), 22, 'Expected 22 recorded cases.');
        end
    end
end
