classdef parseText < matlab.unittest.TestCase
    % parseText (readArtifacts/fun) - verify the ndi.fun.parseText symmetry
    % artifacts written by both languages.
    %
    %   Three checks, each skipping (assumption failure -> Incomplete, which the
    %   symmetry workflow's stage asserts on, so it cannot pass silently) when
    %   the required artifact is absent:
    %
    %     * testMatlabArtifactsReproduce: re-run the battery and confirm the
    %       current ndi.fun.parseText reproduces the recorded matlabArtifacts
    %       outputs (a cross-run regression guard, independent of Python).
    %     * testMatlabPythonSymmetry: assert MATLAB's per-case signature
    %       matches Python's for the same cases.
    %     * testInputsAgree: assert both languages started from the same rules
    %       and the same text rows, so a green comparison cannot be two
    %       different batteries agreeing with themselves.
    %
    %   WHAT THE SIGNATURE COMPARES, AND WHY columnTypes IS IN IT
    %   status, the Clean option, the row count, the column NAMES, the column
    %   MATLAB CLASSES, and the rendered column VALUES. The classes are compared
    %   because parseText's final flattening pass is where the two languages are
    %   most likely to drift: a column of empty strings becoming a logical
    %   column of false is invisible in the values alone once Clean has removed
    %   the column, so a values-only comparison could go green over exactly the
    %   behaviour the battery was written to pin.
    %
    %   Error identifiers and messages are recorded in the artifact but never
    %   compared: MATLAB identifiers and Python exception names can never match,
    %   and pinning them would make this a translation table instead of a
    %   behaviour check. Only the FACT of an error is symmetric.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- VALIDATE BEFORE RELYING ON IT.
    %   Run the matching makeArtifacts/fun test first to populate the artifact.
    %
    %   See also: ndi.symmetry.fun.parseTextCases,
    %     ndi.symmetry.makeArtifacts.fun.parseText,
    %     ndi.symmetry.readArtifacts.fun.whatVaries

    properties (Constant)
        RelPath = fullfile('fun', 'parseText', 'testParseTextArtifacts', ...
            'parseTextCases.json');
    end

    methods (Test)

        function testMatlabArtifactsReproduce(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.parseText.artifactFile('matlabArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                ['matlabArtifacts parseText artifact missing (run ' ...
                 'makeArtifacts/fun/parseText first). Skipping.']);

            recorded = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            fresh = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.parseTextCases.runCases());

            testCase.verifyEqual(sort(string(recorded.keys())), sort(string(fresh.keys())), ...
                'Recorded and freshly computed MATLAB parseText cases differ.');
            ndi.symmetry.readArtifacts.fun.parseText.compareMaps(testCase, ...
                recorded, fresh, 'MATLAB recorded vs fresh');
        end

        function testMatlabPythonSymmetry(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.parseText.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.parseText.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                'matlabArtifacts parseText artifact missing. Skipping.');
            testCase.assumeTrue(isfile(pyFile), ...
                'pythonArtifacts parseText artifact missing. Skipping.');

            ml = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            py = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(pyFile));

            testCase.verifyEqual(sort(string(ml.keys())), sort(string(py.keys())), ...
                'MATLAB and Python ran different parseText cases.');
            ndi.symmetry.readArtifacts.fun.parseText.compareMaps(testCase, ...
                ml, py, 'MATLAB vs Python');
        end

        function testInputsAgree(testCase)
            % The two languages must have started from the same rules and the
            % same text, or the output comparison is meaningless.
            mlFile = ndi.symmetry.readArtifacts.fun.parseText.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.parseText.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile) && isfile(pyFile), ...
                'Both parseText artifacts are needed to compare inputs. Skipping.');

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
                testCase.verifyEqual( ...
                    ndi.symmetry.fun.parseTextCases.inputSignature(ml(key)), ...
                    ndi.symmetry.fun.parseTextCases.inputSignature(py(key)), ...
                    sprintf('Inputs differ between languages for case ''%s''.', key));
            end
        end

    end

    methods (Static)

        function f = artifactFile(sourceType)
            f = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                ndi.symmetry.readArtifacts.fun.parseText.RelPath);
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
                sigA = ndi.symmetry.fun.parseTextCases.signature(a(key));
                sigB = ndi.symmetry.fun.parseTextCases.signature(b(key));
                testCase.verifyEqual(sigA, sigB, ...
                    sprintf('%s parseText mismatch for case ''%s''.', label, key));
            end
        end

    end
end
