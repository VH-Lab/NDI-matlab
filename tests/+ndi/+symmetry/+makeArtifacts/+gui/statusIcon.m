classdef statusIcon < matlab.unittest.TestCase
    % statusIcon (makeArtifacts/gui) - write this language's badge artifacts
    %
    %   Renders every case in ndi.symmetry.gui.statusIconCases under
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/gui/statusIcon/
    %              testStatusIconArtifacts/
    %
    %   as <name>.png, plus an index recording which cases produced a badge at
    %   all. The Python counterpart writes the same case names under
    %   pythonArtifacts/. Like the VHSB battery, what crosses the language
    %   boundary is the binary itself -- but it is compared by PIXEL rather
    %   than by byte, because the two ports use different PNG encoders. See
    %   ndi.symmetry.gui.statusIconCases.
    %
    %   Each badge is decoded straight back and checked against the battery's
    %   own reference rendering before being published, so a generator that
    %   draws the wrong picture fails HERE rather than looking like a
    %   cross-language divergence later.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- validate before relying on it.
    %
    %   See also: ndi.symmetry.gui.statusIconCases,
    %     ndi.symmetry.readArtifacts.gui.statusIcon

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)

        function testStatusIconArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'gui', 'statusIcon', 'testStatusIconArtifacts');

            % Eight cases draw something; three deliberately do not.
            expectedCaseCount  = 11;
            expectedBadgeCount = 8;

            badges = ndi.symmetry.gui.statusIconCases.writeCases(artifactDir);

            names = ndi.symmetry.gui.statusIconCases.caseNames();
            testCase.assertEqual(numel(names), expectedCaseCount, ...
                'Unexpected number of statusIcon cases.');

            drawn = names(cellfun(@(n) badges.(n), names));
            testCase.verifyEqual(numel(drawn), expectedBadgeCount, sprintf( ...
                'Expected %d cases to draw a badge, got: %s', ...
                expectedBadgeCount, strjoin(drawn, ', ')));

            % The three no-badge cases are the point of statusIcon returning
            % '': a case that quietly started drawing something would
            % otherwise just look like an extra file nobody compares.
            for i = 1:numel(names)
                f = fullfile(artifactDir, [names{i} '.png']);
                if ndi.symmetry.gui.statusIconCases.drawsBadge(names{i})
                    testCase.verifyTrue(badges.(names{i}), sprintf( ...
                        '%s: statusIcon returned '''' but a badge was expected.', names{i}));
                    testCase.verifyTrue(isfile(f), sprintf( ...
                        '%s.png was not written.', names{i}));
                else
                    testCase.verifyFalse(badges.(names{i}), sprintf( ...
                        '%s: statusIcon drew a badge where none was expected.', names{i}));
                    testCase.verifyFalse(isfile(f), sprintf( ...
                        '%s.png was written for a no-badge case.', names{i}));
                end
            end

            % Decode each one back with this language's reader before
            % publishing it.
            problems = {};
            for i = 1:numel(names)
                if ~badges.(names{i})
                    continue;
                end
                f = fullfile(artifactDir, [names{i} '.png']);
                if ~isfile(f)
                    continue;   % already reported above
                end
                p = ndi.symmetry.gui.statusIconCases.compareToExpectation(names{i}, f);
                for k = 1:numel(p)
                    problems{end+1} = [names{i} ': ' p{k}]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(problems, sprintf( ...
                'MATLAB did not draw what the battery expects:\n  %s', ...
                strjoin(problems, sprintf('\n  '))));

            testCase.verifyTrue(isfile(fullfile(artifactDir, ...
                ndi.symmetry.gui.statusIconCases.IndexFile)), ...
                'The statusIcon index file was not written.');
        end

        function testBadgeVersionIsLevelWithPython(testCase)
            % A one-sided BADGEVERSION bump means one cache key, two pictures.
            %
            %   Caught here as a named failure rather than as a pixel mismatch
            %   on every case, which is what it would otherwise look like.
            %   statusIcon keeps BADGEVERSION as a local, so the handle is the
            %   version it stamps into the cache filename -- which is the
            %   thing the two ports can actually collide on anyway. The read
            %   side additionally compares the version each language wrote.
            ndi.symmetry.gui.statusIconCases.clearBadgeCache();
            p = ndi.gui.nav.statusIcon(struct('ingestion', 'ingested'));
            testCase.assertNotEmpty(p, 'statusIcon drew nothing for an ingested status.');

            testCase.verifyEqual( ...
                ndi.symmetry.gui.statusIconCases.badgeVersionFromPath(p), ...
                ndi.symmetry.gui.statusIconCases.ExpectedBadgeVersion, ...
                'statusIcon''s BADGEVERSION is not the one the battery expects. Both ports must bump together.');
        end

    end
end
