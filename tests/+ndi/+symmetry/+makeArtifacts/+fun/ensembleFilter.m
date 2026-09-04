classdef ensembleFilter < matlab.unittest.TestCase
    % ensembleFilter (makeArtifacts/fun) - generate the ndi.fun.ensemble.filter
    % symmetry artifact for cross-language comparison with NDI-python.
    %
    %   Runs the shared ndi.symmetry.fun.ensembleFilterCases battery through
    %   the real ndi.fun.ensemble.filter and writes the inputs + computed
    %   outputs to:
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/fun/ensembleFilter/
    %              testEnsembleFilterArtifacts/ensembleFilterCases.json
    %
    %   The Python counterpart writes the same structure under pythonArtifacts/;
    %   the readArtifacts tests on both sides compare them. The on-disk schema
    %   is documented in tests/+ndi/+symmetry/FUN_CASES_SCHEMA.md, section 10.
    %
    %   WHY ensemble.filter GETS SYMMETRY COVERAGE AND ITS SIBLINGS DO NOT
    %   The +ensemble package has nine functions but filter is the only one
    %   that is pure and in-memory: the other eight (allElement, allNTrodes,
    %   create, findExisting, load, neuronQuality, plot, read) all need a
    %   session, a clock, epoch resolution, or a display, and none of that can
    %   be compared through a JSON artifact without turning the battery into a
    %   fixture-management exercise. filter is where a pure symmetry check
    %   fits, and that is what this battery is for.
    %
    %   WHY THIS GENERATOR DOES NOT ASSERT THAT EVERY CASE SUCCEEDS
    %   Like its parseText sibling, a case that THROWS is recorded as
    %   {status:'error', identifier:...} rather than failing the test. A
    %   generator that died on one case would write no artifact at all and cost
    %   the suite every other case's coverage. The error is still printed
    %   here, recorded in the artifact, and asserted against Python in
    %   ndi.symmetry.readArtifacts.fun.ensembleFilter.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- the expected values are
    %   derived by reading src/ndi/+ndi/+fun/+ensemble/filter.m branch by
    %   branch, not by executing MATLAB. VALIDATE BEFORE RELYING ON IT.
    %
    %   See also: ndi.symmetry.fun.ensembleFilterCases,
    %     ndi.symmetry.readArtifacts.fun.ensembleFilter,
    %     ndi.symmetry.makeArtifacts.fun.parseText

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testEnsembleFilterArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'fun', 'ensembleFilter', ...
                'testEnsembleFilterArtifacts');

            results = ndi.symmetry.fun.ensembleFilterCases.runCases();
            defs = ndi.symmetry.fun.ensembleFilterCases.definitions();

            testCase.assertEqual(numel(results), numel(defs), ...
                'Every definition must produce exactly one recorded case.');

            % Make every recorded error visible in the CI log, and check the
            % cases that carry a predicted expectation. There are no deferred
            % expectations in this battery: every rule of ensemble.filter is
            % stated in the MATLAB help, so there is no source-read prediction
            % that needs a "settled by first real run" cycle. If one is added
            % later, mirror the parseText battery's expectationDeferred flag.
            nErrors = 0;
            for i = 1:numel(results)
                c = results{i};
                if strcmp(c.status, 'error')
                    nErrors = nErrors + 1;
                    fprintf('ensembleFilter case ''%s'' recorded status ''error'': %s -- %s\n', ...
                        c.name, c.identifier, c.message);
                end
                [ok, detail] = ndi.symmetry.fun.ensembleFilterCases.checkExpected(defs(i), c);
                testCase.verifyTrue(ok, sprintf( ...
                    'ensembleFilter case ''%s'' did not match its expected output: %s', ...
                    c.name, detail));
            end
            fprintf('ensembleFilter battery: %d of %d cases recorded status ''error''.\n', ...
                nErrors, numel(results));

            payload = struct();
            payload.schemaVersion = 1;
            payload.description = 'ndi.fun.ensemble.filter symmetry cases';
            payload.language = 'matlab';
            payload.generator = 'ndi.symmetry.makeArtifacts.fun.ensembleFilter';
            payload.cases = results;

            ndi.symmetry.fun.cases.writeCases(testCase, artifactDir, ...
                'ensembleFilterCases.json', payload);

            testCase.verifyEqual(numel(results), 15, 'Expected 15 recorded cases.');
        end
    end
end
