classdef whatVaries < matlab.unittest.TestCase
    % whatVaries (makeArtifacts/fun) - generate the whatVaries / whatIsConstant
    % symmetry artifact for cross-language comparison with NDI-python.
    %
    %   Runs the shared ndi.symmetry.fun.cases battery through the real
    %   ndi.fun.stimulus.whatVaries and ndi.fun.stimulus.whatIsConstant and
    %   writes the inputs + computed outputs to:
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/fun/whatVaries/
    %              testWhatVariesArtifacts/whatVariesCases.json
    %
    %   The Python counterpart writes the same structure under pythonArtifacts/;
    %   the readArtifacts tests on both sides compare them. The on-disk schema is
    %   documented in tests/+ndi/+symmetry/FUN_CASES_SCHEMA.md.
    %
    %   The 18 cases mirror the 17 test methods of
    %   tests/+ndi/+unittest/+fun/+stimulus/whatVariesTest.m (see the mapping
    %   table in the schema doc), plus one all-NaN case added to pin a suspected
    %   cross-language divergence.
    %
    %   WHY THIS GENERATOR DOES NOT ASSERT THAT EVERY CASE SUCCEEDS
    %   Unlike its pathSafeName sibling, this test records a case that THROWS as
    %   {status:'error', identifier:...} instead of failing. That is deliberate:
    %   ndi.fun.stimulus.whatVaries on current MATLAB main is expected to throw
    %   on the cell-valued-constant case (local_varyingFields compares with
    %   vlt.data.eqlen, which bottoms out in a bare '=='; '==' is undefined for
    %   two cell arrays), and a generator that died there would write NO artifact
    %   at all -- costing the symmetry suite every other case's coverage to
    %   report one already-known bug.
    %
    %   The error is not swallowed. It is (a) printed by this test, (b) recorded
    %   in the artifact, and (c) compared against Python in
    %   ndi.symmetry.readArtifacts.fun.whatVaries, which FAILS on any status or
    %   value mismatch that is not in ndi.symmetry.fun.cases.knownDivergences.
    %   The assertion lives at the comparison, where the two languages can
    %   actually be held against each other, rather than here.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- the expected values, and the
    %   prediction that the cell-valued and all-NaN cases diverge, are derived by
    %   reading src/ndi/+ndi/+fun/+stimulus/whatVaries.m, not by executing
    %   MATLAB. VALIDATE BEFORE RELYING ON IT: the first real run of this test
    %   settles whether the two predicted divergences are real.
    %
    %   See also: ndi.symmetry.fun.cases,
    %     ndi.symmetry.readArtifacts.fun.whatVaries,
    %     ndi.unittest.fun.stimulus.whatVariesTest

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testWhatVariesArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'fun', 'whatVaries', 'testWhatVariesArtifacts');

            results = ndi.symmetry.fun.cases.runWhatVariesCases();

            % Check the cases whose MATLAB behaviour is NOT expected to diverge.
            % The two divergenceExpected cases are skipped here and reported
            % below; readArtifacts is where they are held against Python.
            ndi.symmetry.fun.cases.verifyWhatVariesExpected(testCase, results);

            % Make every recorded error visible in the CI log even though none
            % of them fails this test.
            defs = ndi.symmetry.fun.cases.whatVariesDefs();
            nErrors = 0;
            for i = 1:numel(results)
                c = results{i};
                if strcmp(c.status, 'error')
                    nErrors = nErrors + 1;
                    expectedNote = 'UNEXPECTED';
                    if i <= numel(defs) && defs(i).divergenceExpected
                        expectedNote = 'predicted divergence';
                    end
                    fprintf('whatVaries case ''%s'' ERRORED (%s): %s -- %s\n', ...
                        c.name, expectedNote, c.identifier, c.message);
                end
            end
            fprintf('whatVaries battery: %d of %d cases recorded status ''error''.\n', ...
                nErrors, numel(results));

            payload = struct();
            payload.schemaVersion = 1;
            payload.description = 'ndi.fun.stimulus.whatVaries / whatIsConstant symmetry cases';
            payload.language = 'matlab';
            payload.generator = 'ndi.symmetry.makeArtifacts.fun.whatVaries';
            payload.cases = results;

            ndi.symmetry.fun.cases.writeCases(testCase, artifactDir, ...
                'whatVariesCases.json', payload);

            testCase.verifyEqual(numel(results), 18, 'Expected 18 recorded cases.');
        end
    end
end
