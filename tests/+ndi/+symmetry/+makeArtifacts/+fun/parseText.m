classdef parseText < matlab.unittest.TestCase
    % parseText (makeArtifacts/fun) - generate the ndi.fun.parseText symmetry
    % artifact for cross-language comparison with NDI-python.
    %
    %   Runs the shared ndi.symmetry.fun.parseTextCases battery through the real
    %   ndi.fun.parseText and writes the inputs + computed outputs to:
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/fun/parseText/
    %              testParseTextArtifacts/parseTextCases.json
    %
    %   The Python counterpart writes the same structure under pythonArtifacts/;
    %   the readArtifacts tests on both sides compare them. The on-disk schema is
    %   documented in tests/+ndi/+symmetry/FUN_CASES_SCHEMA.md, section 9.
    %
    %   WHY parseText IS THE ndi.fun ITEM THAT MOST NEEDS THIS
    %   It is a pure deterministic function from text plus a JSON rules file to a
    %   table, with no session, database or file layout involved -- so it can be
    %   compared exactly. And almost none of its behaviour is stated anywhere: a
    %   rule becomes a logical column or a token column depending on a scan for
    %   '(' in the PATTERN TEXT; a token becomes a number or a string depending
    %   on a digit scan and then str2double; and the final column CLASS is
    %   decided by a flattening pass that can silently turn a column of empty
    %   strings into a logical column of false. A port has nothing to aim at
    %   except the source, which is exactly the situation this battery exists
    %   for.
    %
    %   WHY THIS GENERATOR DOES NOT ASSERT THAT EVERY CASE SUCCEEDS
    %   Like its whatVaries sibling, and unlike pathSafeName, a case that THROWS
    %   is recorded as {status:'error', identifier:...} rather than failing the
    %   test. A generator that died on one case would write no artifact at all
    %   and cost the suite every other case's coverage. The error is still
    %   printed here, recorded in the artifact, and asserted against Python in
    %   ndi.symmetry.readArtifacts.fun.parseText.
    %
    %   Cases whose expectation is DEFERRED (multipleGroupsFirstGroupWins and
    %   escapedParenTreatedAsToken) are not checked against a predicted value
    %   here -- see parseTextCases for why -- but they are still recorded and
    %   still compared against Python.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- the expected values are derived
    %   by reading src/ndi/+ndi/+fun/parseText.m branch by branch, not by
    %   executing MATLAB. VALIDATE BEFORE RELYING ON IT.
    %
    %   See also: ndi.symmetry.fun.parseTextCases,
    %     ndi.symmetry.readArtifacts.fun.parseText,
    %     ndi.symmetry.makeArtifacts.fun.whatVaries

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testParseTextArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'fun', 'parseText', 'testParseTextArtifacts');

            results = ndi.symmetry.fun.parseTextCases.runCases();
            defs = ndi.symmetry.fun.parseTextCases.definitions();

            testCase.assertEqual(numel(results), numel(defs), ...
                'Every definition must produce exactly one recorded case.');

            % Make every recorded error visible in the CI log, and check the
            % cases that carry a predicted expectation.
            nErrors = 0;
            nDeferred = 0;
            for i = 1:numel(results)
                c = results{i};
                if strcmp(c.status, 'error')
                    nErrors = nErrors + 1;
                    fprintf('parseText case ''%s'' ERRORED: %s -- %s\n', ...
                        c.name, c.identifier, c.message);
                end
                if defs(i).expectationDeferred
                    nDeferred = nDeferred + 1;
                    fprintf('parseText case ''%s'' expectation DEFERRED; recorded: %s\n', ...
                        c.name, ndi.symmetry.fun.parseTextCases.signature(c));
                else
                    [ok, detail] = ndi.symmetry.fun.parseTextCases.checkExpected(defs(i), c);
                    testCase.verifyTrue(ok, sprintf( ...
                        'parseText case ''%s'' did not match its expected table: %s', ...
                        c.name, detail));
                end
            end
            fprintf(['parseText battery: %d of %d cases recorded status ''error''; ' ...
                '%d expectations deferred.\n'], nErrors, numel(results), nDeferred);

            payload = struct();
            payload.schemaVersion = 1;
            payload.description = 'ndi.fun.parseText symmetry cases';
            payload.language = 'matlab';
            payload.generator = 'ndi.symmetry.makeArtifacts.fun.parseText';
            payload.cases = results;

            ndi.symmetry.fun.cases.writeCases(testCase, artifactDir, ...
                'parseTextCases.json', payload);

            testCase.verifyEqual(numel(results), 18, 'Expected 18 recorded cases.');
        end
    end
end
