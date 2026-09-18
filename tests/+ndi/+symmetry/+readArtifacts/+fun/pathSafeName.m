classdef pathSafeName < matlab.unittest.TestCase
    % pathSafeName (readArtifacts/fun) - verify the pathSafeName symmetry
    % artifacts written by both languages.
    %
    %   Two checks, each skipping (assumption failure -> Incomplete, not a
    %   failure) when the required artifact is absent:
    %
    %     * testMatlabArtifactsReproduce: re-run the battery and confirm the
    %       current ndi.fun.file.pathSafeName / elementDirectoryName reproduce
    %       the recorded matlabArtifacts outputs (a cross-run regression guard,
    %       independent of Python).
    %     * testMatlabPythonSymmetry: assert MATLAB's sanitized names match
    %       Python's pythonArtifacts for the same cases.
    %
    %   The comparison is on the per-case SIGNATURE built by
    %   ndi.symmetry.fun.cases.pathSafeSignature -- status, sanitized name,
    %   element directory name, the legacy directory name as CODEPOINTS (so no
    %   JSON text-encoding difference can masquerade as a behaviour difference),
    %   and both length counts. Error identifiers and messages are recorded in
    %   the artifact but never compared: MATLAB identifiers and Python exception
    %   names can never match, and pinning them would make this a translation
    %   table instead of a behaviour check.
    %
    %   THE ASTRAL CASES ARE THE POINT. MATLAB counts UTF-16 code units, so a
    %   character above U+FFFF is a surrogate pair and sanitizes to TWO '-'.
    %   Python counts code points. inputUtf16Units and inputCodepointCount are
    %   both in the signature, so if the two languages ever stop agreeing about
    %   the folder name for an element, this test says so.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- VALIDATE BEFORE RELYING ON IT.
    %   Run the matching makeArtifacts/fun test first to populate the artifact.
    %
    %   See also: ndi.symmetry.fun.cases,
    %     ndi.symmetry.makeArtifacts.fun.pathSafeName,
    %     ndi.symmetry.readArtifacts.time.timeConvert

    properties (Constant)
        RelPath = fullfile('fun', 'pathSafeName', 'testPathSafeNameArtifacts', ...
            'pathSafeNameCases.json');
    end

    methods (Test)

        function testMatlabArtifactsReproduce(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.pathSafeName.artifactFile('matlabArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                ['matlabArtifacts pathSafeName artifact missing (run ' ...
                 'makeArtifacts/fun/pathSafeName first). Skipping.']);

            recorded = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            fresh = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.runPathSafeNameCases());

            testCase.verifyEqual(sort(string(recorded.keys())), sort(string(fresh.keys())), ...
                'Recorded and freshly computed MATLAB pathSafeName cases differ.');
            ndi.symmetry.readArtifacts.fun.pathSafeName.compareMaps(testCase, ...
                recorded, fresh, 'MATLAB recorded vs fresh');
        end

        function testMatlabPythonSymmetry(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.pathSafeName.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.pathSafeName.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                'matlabArtifacts pathSafeName artifact missing. Skipping.');
            testCase.assumeTrue(isfile(pyFile), ...
                'pythonArtifacts pathSafeName artifact missing. Skipping.');

            ml = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            py = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(pyFile));

            testCase.verifyEqual(sort(string(ml.keys())), sort(string(py.keys())), ...
                'MATLAB and Python ran different pathSafeName cases.');
            ndi.symmetry.readArtifacts.fun.pathSafeName.compareMaps(testCase, ...
                ml, py, 'MATLAB vs Python');
        end

        function testInputsAgree(testCase)
            % The two languages must have started from the same inputs, or the
            % output comparison is meaningless. The input is specified as
            % Unicode scalar values precisely so this check is exact.
            mlFile = ndi.symmetry.readArtifacts.fun.pathSafeName.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.pathSafeName.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile) && isfile(pyFile), ...
                'Both pathSafeName artifacts are needed to compare inputs. Skipping.');

            ml = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            py = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(pyFile));

            keysML = ml.keys();
            for i = 1:numel(keysML)
                key = keysML{i};
                if ~py.isKey(key)
                    continue;   % key-set mismatch is reported by testMatlabPythonSymmetry
                end
                a = ml(key);
                b = py(key);
                testCase.verifyEqual( ...
                    ndi.symmetry.fun.cases.asRow(a.inputCodepoints), ...
                    ndi.symmetry.fun.cases.asRow(b.inputCodepoints), ...
                    sprintf('Input codepoints differ between languages for case ''%s''.', key));
            end
        end

    end

    methods (Static)

        function f = artifactFile(sourceType)
            f = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                ndi.symmetry.readArtifacts.fun.pathSafeName.RelPath);
        end

        function compareMaps(testCase, a, b, label)
            keysA = a.keys();
            for i = 1:numel(keysA)
                key = keysA{i};
                if ~b.isKey(key)
                    testCase.verifyTrue(false, ...
                        sprintf('%s: case ''%s'' is missing from the second artifact.', label, key));
                    continue;
                end
                sigA = ndi.symmetry.fun.cases.pathSafeSignature(a(key));
                sigB = ndi.symmetry.fun.cases.pathSafeSignature(b(key));
                testCase.verifyEqual(sigA, sigB, ...
                    sprintf('%s pathSafeName mismatch for case ''%s''.', label, key));
            end
        end

    end
end
