classdef ensembleFilter < matlab.unittest.TestCase
    % ensembleFilter (readArtifacts/fun) - verify the ndi.fun.ensemble.filter
    % symmetry artifacts written by both languages.
    %
    %   Three checks, each skipping (assumption failure -> Incomplete, which
    %   the symmetry workflow's stage asserts on, so it cannot pass silently)
    %   when the required artifact is absent:
    %
    %     * testMatlabArtifactsReproduce: re-run the battery and confirm the
    %       current ndi.fun.ensemble.filter reproduces the recorded
    %       matlabArtifacts outputs (a cross-run regression guard, independent
    %       of Python).
    %     * testMatlabPythonSymmetry: assert MATLAB's per-case signature
    %       matches Python's for the same cases.
    %     * testInputsAgree: assert both languages started from the same
    %       ensemble and the same filter options, so a green comparison cannot
    %       be two different batteries agreeing with themselves.
    %
    %   WHAT THE SIGNATURE COMPARES, AND WHY shape IS IN IT
    %   status, num_neurons, the kept ids, the kept names, the surviving
    %   activity matrix rendered ROW BY ROW, and the surviving activity SHAPE.
    %   The shape is compared because the ``nothingKeptPreservesWidth`` case
    %   is 0-by-3 in both languages by design (MATLAB's isempty guard returns
    %   early, and the Python port reproduces the asymmetry), and a row-only
    %   comparison could not tell 0-by-3 from 0-by-1.
    %
    %   Error identifiers and messages are recorded in the artifact but never
    %   compared: MATLAB identifiers and Python exception names can never
    %   match, and pinning them would make this a translation table instead of
    %   a behaviour check. Only the FACT of an error is symmetric.
    %
    %   Run the matching makeArtifacts/fun test first to populate the artifact.
    %
    %   See also: ndi.symmetry.fun.ensembleFilterCases,
    %     ndi.symmetry.makeArtifacts.fun.ensembleFilter,
    %     ndi.symmetry.readArtifacts.fun.parseText

    properties (Constant)
        RelPath = fullfile('fun', 'ensembleFilter', ...
            'testEnsembleFilterArtifacts', 'ensembleFilterCases.json');
    end

    methods (Test)

        function testMatlabArtifactsReproduce(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.ensembleFilter.artifactFile('matlabArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                ['matlabArtifacts ensembleFilter artifact missing (run ' ...
                 'makeArtifacts/fun/ensembleFilter first). Skipping.']);

            recorded = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            fresh = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.ensembleFilterCases.runCases());

            testCase.verifyEqual(sort(string(recorded.keys())), sort(string(fresh.keys())), ...
                'Recorded and freshly computed MATLAB ensembleFilter cases differ.');
            ndi.symmetry.readArtifacts.fun.ensembleFilter.compareMaps(testCase, ...
                recorded, fresh, 'MATLAB recorded vs fresh');
        end

        function testMatlabPythonSymmetry(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.ensembleFilter.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.ensembleFilter.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                'matlabArtifacts ensembleFilter artifact missing. Skipping.');
            testCase.assumeTrue(isfile(pyFile), ...
                'pythonArtifacts ensembleFilter artifact missing. Skipping.');

            ml = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            py = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(pyFile));

            testCase.verifyEqual(sort(string(ml.keys())), sort(string(py.keys())), ...
                'MATLAB and Python ran different ensembleFilter cases.');
            ndi.symmetry.readArtifacts.fun.ensembleFilter.compareMaps(testCase, ...
                ml, py, 'MATLAB vs Python');
        end

        function testInputsAgree(testCase)
            % The two languages must have started from the same ensemble and
            % the same options, or the output comparison is meaningless.
            mlFile = ndi.symmetry.readArtifacts.fun.ensembleFilter.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.ensembleFilter.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile) && isfile(pyFile), ...
                'Both ensembleFilter artifacts are needed to compare inputs. Skipping.');

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
                    ndi.symmetry.fun.ensembleFilterCases.inputSignature(ml(key)), ...
                    ndi.symmetry.fun.ensembleFilterCases.inputSignature(py(key)), ...
                    sprintf('Inputs differ between languages for case ''%s''.', key));
            end
        end

    end

    methods (Static)

        function f = artifactFile(sourceType)
            f = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                ndi.symmetry.readArtifacts.fun.ensembleFilter.RelPath);
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
                sigA = ndi.symmetry.fun.ensembleFilterCases.signature(a(key));
                sigB = ndi.symmetry.fun.ensembleFilterCases.signature(b(key));
                testCase.verifyEqual(sigA, sigB, ...
                    sprintf('%s ensembleFilter mismatch for case ''%s''.', label, key));
            end
        end

    end
end
