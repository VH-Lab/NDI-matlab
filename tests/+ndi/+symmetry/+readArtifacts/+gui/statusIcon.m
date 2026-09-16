classdef statusIcon < matlab.unittest.TestCase
    % statusIcon (readArtifacts/gui) - decode BOTH languages' badges
    %
    %   This is the cross-language check for the one piece of the navigator
    %   GUI that produces a comparable artifact. A pane layout diffs against
    %   nothing, so the rest of the port is held to unit tests plus a human
    %   eye; statusIcon is pure, deterministic, headless, and turns a status
    %   struct into a picture, so it can be held to the same standard as VHSB.
    %
    %   Three things are checked, and they fail for different reasons:
    %
    %     * Each language's badges are compared against a reference this
    %       battery renders LOCALLY from the case list. Two ports that agreed
    %       with each other on the wrong glyph or the wrong palette entry
    %       still go red here.
    %     * The two languages' badges are compared to each other, pixel for
    %       pixel. That is the direct statement of the contract, and it gives
    %       the clearest failure message when the pictures genuinely differ.
    %     * The two indexes are compared, so the languages must agree on the
    %       case set AND on which cases drew no badge at all. Without that
    %       second half, a silently-missing file and a deliberately-absent
    %       badge look identical on disk -- and telling those apart is exactly
    %       what statusIcon returning '' is for.
    %
    %   PIXELS, NOT BYTES. This side writes with imwrite; the Python port
    %   encodes the PNG itself with its standard library. Both are valid
    %   8-bit RGBA PNGs of the same picture and both are free to differ in
    %   compression level, scanline filter choice and chunk layout. See
    %   ndi.symmetry.gui.statusIconCases.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- validate before relying on it.
    %   Run the matching makeArtifacts/gui test first to populate the
    %   artifacts.
    %
    %   See also: ndi.symmetry.gui.statusIconCases,
    %     ndi.symmetry.makeArtifacts.gui.statusIcon

    methods (Test)

        function testMatlabArtifactsMatchExpectation(testCase)
            % This language checks its own badges -- a cross-run regression guard.
            ndi.symmetry.readArtifacts.gui.statusIcon.checkAgainstExpectation( ...
                testCase, 'matlabArtifacts');
        end

        function testPythonArtifactsMatchExpectation(testCase)
            % THE POINT: this language decodes Python's PNGs.
            %
            % A failure here means the two ports draw different pictures for
            % the same status -- a different glyph, a different palette entry,
            % a different composite geometry -- rather than that they merely
            % encoded the same picture differently.
            ndi.symmetry.readArtifacts.gui.statusIcon.checkAgainstExpectation( ...
                testCase, 'pythonArtifacts');
        end

        function testPixelsAgreeAcrossLanguages(testCase)
            % Compare the two languages' badges directly, pixel for pixel.
            %
            % Redundant with the two checks above only while this battery's
            % reference rendering is itself correct; as a direct statement of
            % the contract it is the check that says what actually broke.
            mlDir = ndi.symmetry.readArtifacts.gui.statusIcon.artifactDir('matlabArtifacts');
            pyDir = ndi.symmetry.readArtifacts.gui.statusIcon.artifactDir('pythonArtifacts');
            testCase.assumeTrue( ...
                isfile(ndi.symmetry.readArtifacts.gui.statusIcon.indexFile('matlabArtifacts')) && ...
                isfile(ndi.symmetry.readArtifacts.gui.statusIcon.indexFile('pythonArtifacts')), ...
                'Both statusIcon artifact sets are needed to compare pixels. Skipping.');

            names = ndi.symmetry.gui.statusIconCases.caseNames();
            problems = {};
            for i = 1:numel(names)
                if ~ndi.symmetry.gui.statusIconCases.drawsBadge(names{i})
                    continue;
                end
                a = fullfile(mlDir, [names{i} '.png']);
                b = fullfile(pyDir, [names{i} '.png']);
                if ~isfile(a) || ~isfile(b)
                    problems{end+1} = sprintf( ...
                        '%s: missing on one side (matlab=%d, python=%d)', ...
                        names{i}, isfile(a), isfile(b)); %#ok<AGROW>
                    continue;
                end
                p = ndi.symmetry.gui.statusIconCases.compareFiles(a, b);
                for k = 1:numel(p)
                    problems{end+1} = [names{i} ': matlab vs python: ' p{k}]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(problems, sprintf( ...
                'The two ports drew different badges:\n  %s', ...
                strjoin(problems, sprintf('\n  '))));
        end

        function testCaseSetsAgree(testCase)
            % Both sides must have written the same cases. Without this, each
            % language could check its own files happily while silently
            % covering a different battery.
            [ml, py] = ndi.symmetry.readArtifacts.gui.statusIcon.bothIndexes(testCase);

            testCase.verifyEqual(sort(string(ml.cases(:)')), sort(string(py.cases(:)')), ...
                'MATLAB and Python wrote different statusIcon case sets.');
            testCase.verifyEqual(sort(string(ml.cases(:)')), ...
                sort(string(ndi.symmetry.gui.statusIconCases.caseNames())), ...
                'The artifact case set does not match the battery.');
        end

        function testNoBadgeCasesAgree(testCase)
            % The two languages must agree on which cases drew nothing.
            %
            % A missing file and an absent badge are the same thing on disk,
            % so without the index a port that silently stopped rendering a
            % case would read as a port that correctly declined to.
            [ml, py] = ndi.symmetry.readArtifacts.gui.statusIcon.bothIndexes(testCase);

            names = ndi.symmetry.gui.statusIconCases.caseNames();
            sources = {'matlab', ml; 'python', py};
            for s = 1:size(sources, 1)
                label = sources{s, 1};
                badges = sources{s, 2}.badges;
                disagreed = {};
                for i = 1:numel(names)
                    want = ndi.symmetry.gui.statusIconCases.drawsBadge(names{i});
                    got = isfield(badges, names{i}) && logical(badges.(names{i}));
                    if got ~= want
                        disagreed{end+1} = names{i}; %#ok<AGROW>
                    end
                end
                testCase.verifyEmpty(disagreed, sprintf( ...
                    '%s disagrees with the battery about which cases draw a badge: %s', ...
                    label, strjoin(disagreed, ', ')));
            end
        end

        function testBadgeVersionsAgree(testCase)
            % A one-sided BADGEVERSION bump means one cache key, two pictures.
            [ml, py] = ndi.symmetry.readArtifacts.gui.statusIcon.bothIndexes(testCase);

            expected = ndi.symmetry.gui.statusIconCases.ExpectedBadgeVersion;
            testCase.verifyEqual(char(ml.badgeVersion), expected, ...
                'MATLAB wrote badges under an unexpected BADGEVERSION.');
            testCase.verifyEqual(char(py.badgeVersion), expected, ...
                'Python wrote badges under an unexpected BADGEVERSION.');
        end

    end

    methods (Static)

        function d = artifactDir(sourceType)
            d = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                'gui', 'statusIcon', 'testStatusIconArtifacts');
        end

        function f = indexFile(sourceType)
            f = fullfile( ...
                ndi.symmetry.readArtifacts.gui.statusIcon.artifactDir(sourceType), ...
                ndi.symmetry.gui.statusIconCases.IndexFile);
        end

        function [ml, py] = bothIndexes(testCase)
            mlFile = ndi.symmetry.readArtifacts.gui.statusIcon.indexFile('matlabArtifacts');
            pyFile = ndi.symmetry.readArtifacts.gui.statusIcon.indexFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlFile) && isfile(pyFile), ...
                'Both statusIcon indexes are needed for this comparison. Skipping.');
            ml = ndi.symmetry.gui.statusIconCases.loadIndex(mlFile);
            py = ndi.symmetry.gui.statusIconCases.loadIndex(pyFile);
        end

        function checkAgainstExpectation(testCase, sourceType)
            % Decode every badge SOURCETYPE wrote and check it against the
            % locally rendered reference.
            d = ndi.symmetry.readArtifacts.gui.statusIcon.artifactDir(sourceType);
            idxFile = ndi.symmetry.readArtifacts.gui.statusIcon.indexFile(sourceType);
            testCase.assumeTrue(isfile(idxFile), sprintf( ...
                '%s statusIcon artifacts missing. Skipping.', sourceType));

            idx = ndi.symmetry.gui.statusIconCases.loadIndex(idxFile);
            badges = idx.badges;

            names = ndi.symmetry.gui.statusIconCases.caseNames();
            problems = {};
            for i = 1:numel(names)
                name = names{i};
                f = fullfile(d, [name '.png']);

                if ~ndi.symmetry.gui.statusIconCases.drawsBadge(name)
                    % A no-badge case must have no file, in either language.
                    if isfile(f)
                        problems{end+1} = sprintf( ...
                            '%s: %s wrote a badge where none is expected', ...
                            name, sourceType); %#ok<AGROW>
                    end
                    continue;
                end

                if ~isfield(badges, name) || ~badges.(name)
                    problems{end+1} = sprintf('%s: %s''s index says it drew no badge', ...
                        name, sourceType); %#ok<AGROW>
                    continue;
                end
                if ~isfile(f)
                    problems{end+1} = sprintf('%s: %s wrote no %s.png', ...
                        name, sourceType, name); %#ok<AGROW>
                    continue;
                end

                p = ndi.symmetry.gui.statusIconCases.compareToExpectation(name, f);
                for k = 1:numel(p)
                    problems{end+1} = [name ': ' p{k}]; %#ok<AGROW>
                end
            end

            testCase.verifyEmpty(problems, sprintf( ...
                ['Decoding %s badges and comparing against this language''s ' ...
                'reference rendering:\n  %s'], ...
                sourceType, strjoin(problems, sprintf('\n  '))));
        end

    end
end
