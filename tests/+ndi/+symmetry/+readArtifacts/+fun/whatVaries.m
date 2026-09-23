classdef whatVaries < matlab.unittest.TestCase
    % whatVaries (readArtifacts/fun) - verify the whatVaries / whatIsConstant
    % symmetry artifacts written by both languages.
    %
    %   Three checks, each skipping (assumption failure -> Incomplete, not a
    %   failure) when the required artifact is absent:
    %
    %     * testMatlabArtifactsReproduce: re-run the battery and confirm the
    %       current ndi.fun.stimulus.whatVaries reproduces the recorded
    %       matlabArtifacts outputs (a cross-run regression guard, independent
    %       of Python). Every case is compared here, divergences included --
    %       MATLAB must at least agree with itself.
    %     * testMatlabPythonSymmetry: assert MATLAB's outputs match Python's for
    %       the same cases, EXCEPT the cases listed in
    %       ndi.symmetry.fun.cases.knownDivergences, which are reported rather
    %       than failed.
    %     * testKnownDivergencesAreStillReal: report, without failing, whether
    %       each listed divergence actually showed up. A listed case that now
    %       AGREES means the upstream fix landed and the entry should be deleted
    %       from knownDivergences -- a stale allow-list is how a symmetry suite
    %       goes quietly green over a bug it is supposed to be watching.
    %
    %   The comparison is on the per-case SIGNATURE built by
    %   ndi.symmetry.fun.cases.whatVariesSignature: status, excludeBlank, the
    %   rendered input, the varying and constant parameter/value pairs, and the
    %   whatIsConstant result. Error identifiers and messages are recorded in the
    %   artifact but never compared -- MATLAB identifiers
    %   ('ndi:fun:stimulus:whatVaries_parameterList:badInput') and Python
    %   exception names can never match, so only the fact of the error is
    %   symmetric. The rendered INPUT is in the signature so that a battery which
    %   has drifted apart between the two languages is caught as a mismatch
    %   instead of silently comparing two different inputs.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- VALIDATE BEFORE RELYING ON IT.
    %   Run the matching makeArtifacts/fun test first to populate the artifact.
    %
    %   See also: ndi.symmetry.fun.cases,
    %     ndi.symmetry.makeArtifacts.fun.whatVaries,
    %     ndi.symmetry.readArtifacts.time.timeConvert

    properties (Constant)
        RelPath = fullfile('fun', 'whatVaries', 'testWhatVariesArtifacts', ...
            'whatVariesCases.json');
    end

    methods (Test)

        function testMatlabArtifactsReproduce(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.whatVaries.artifactFile('matlabArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                ['matlabArtifacts whatVaries artifact missing (run ' ...
                 'makeArtifacts/fun/whatVaries first). Skipping.']);

            recorded = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            fresh = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.runWhatVariesCases());

            testCase.verifyEqual(sort(string(recorded.keys())), sort(string(fresh.keys())), ...
                'Recorded and freshly computed MATLAB whatVaries cases differ.');
            % No divergence allow-list here: MATLAB must reproduce itself.
            ndi.symmetry.readArtifacts.fun.whatVaries.compareMaps(testCase, ...
                recorded, fresh, 'MATLAB recorded vs fresh', {});
        end

        function testMatlabPythonSymmetry(testCase)
            mlFile = ndi.symmetry.readArtifacts.fun.whatVaries.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.whatVaries.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile), ...
                'matlabArtifacts whatVaries artifact missing. Skipping.');
            testCase.assumeTrue(isfile(pyFile), ...
                'pythonArtifacts whatVaries artifact missing. Skipping.');

            ml = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            py = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(pyFile));

            testCase.verifyEqual(sort(string(ml.keys())), sort(string(py.keys())), ...
                'MATLAB and Python ran different whatVaries cases.');
            ndi.symmetry.readArtifacts.fun.whatVaries.compareMaps(testCase, ...
                ml, py, 'MATLAB vs Python', ndi.symmetry.fun.cases.knownDivergences());
        end

        function testKnownDivergencesAreStillReal(testCase)
            % FAILS on a stale entry. A knownDivergences entry that now agrees
            % across the two languages means the upstream fix has landed, and
            % the entry (plus the matching divergenceExpected flag in
            % ndi.symmetry.fun.cases.whatVariesDefs) must be removed so the
            % case becomes a hard assertion again.
            %
            % This used to report and never fail, which FUN_CASES_SCHEMA.md
            % raised as an open question: a stale entry then landed as a line
            % in the CI log rather than a red build, which is the same failure
            % mode as a silently skipped test -- a suite going quietly green
            % over the bug it exists to watch. Settled in favour of failing;
            % the Python twin (audit_known_divergences) does the same.
            %
            % A case missing from either artifact still only reports: that is
            % list drift, which the key-set check in testMatlabPythonSymmetry
            % already fails on, and failing twice for one cause is noise.
            mlFile = ndi.symmetry.readArtifacts.fun.whatVaries.artifactFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.fun.whatVaries.artifactFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile) && isfile(pyFile), ...
                'Both whatVaries artifacts are needed to audit the divergence list. Skipping.');

            ml = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(mlFile));
            py = ndi.symmetry.fun.cases.indexByName( ...
                ndi.symmetry.fun.cases.loadCases(pyFile));

            known = ndi.symmetry.fun.cases.knownDivergences();
            stale = {};
            for i = 1:numel(known)
                key = known{i};
                if ~ml.isKey(key) || ~py.isKey(key)
                    fprintf(['knownDivergences entry ''%s'' is not present in both ' ...
                        'artifacts -- the case list and the divergence list have drifted.\n'], key);
                    continue;
                end
                sigML = ndi.symmetry.fun.cases.whatVariesSignature(ml(key));
                sigPY = ndi.symmetry.fun.cases.whatVariesSignature(py(key));
                if strcmp(sigML, sigPY)
                    stale{end+1} = key; %#ok<AGROW>
                    fprintf(['knownDivergences entry ''%s'' now AGREES across languages. ' ...
                        'Remove it from ndi.symmetry.fun.cases.knownDivergences and clear ' ...
                        'divergenceExpected in whatVariesDefs so the case is asserted again.\n'], key);
                else
                    fprintf('knownDivergences entry ''%s'' still diverges:\n  MATLAB: %s\n  Python: %s\n', ...
                        key, sigML, sigPY);
                end
            end

            testCase.verifyEmpty(stale, sprintf( ...
                ['%d knownDivergences entry/entries now agree across languages: %s. ' ...
                 'The upstream fix has landed -- remove them from ' ...
                 'ndi.symmetry.fun.cases.knownDivergences and clear the matching ' ...
                 'divergenceExpected flags so the cases are asserted again.'], ...
                numel(stale), strjoin(stale, ', ')));
        end

    end

    methods (Static)

        function f = artifactFile(sourceType)
            f = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                ndi.symmetry.readArtifacts.fun.whatVaries.RelPath);
        end

        function compareMaps(testCase, a, b, label, allowedDivergences)
            % COMPAREMAPS - compare every case in map A against map B.
            %
            %   A case whose name is in ALLOWEDDIVERGENCES is printed rather
            %   than failed; every other mismatch is a verification failure.
            keysA = a.keys();
            for i = 1:numel(keysA)
                key = keysA{i};
                if ~b.isKey(key)
                    testCase.verifyTrue(false, ...
                        sprintf('%s: case ''%s'' is missing from the second artifact.', label, key));
                    continue;
                end
                sigA = ndi.symmetry.fun.cases.whatVariesSignature(a(key));
                sigB = ndi.symmetry.fun.cases.whatVariesSignature(b(key));
                if any(strcmp(key, allowedDivergences))
                    if ~strcmp(sigA, sigB)
                        fprintf('%s: case ''%s'' diverges as expected.\n  A: %s\n  B: %s\n', ...
                            label, key, sigA, sigB);
                    end
                    continue;
                end
                testCase.verifyEqual(sigA, sigB, ...
                    sprintf('%s whatVaries mismatch for case ''%s''.', label, key));
            end
        end

    end
end
