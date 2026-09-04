classdef vhsbRoundTrip < matlab.unittest.TestCase
    % vhsbRoundTrip (readArtifacts/element) - read BOTH languages' VHSB files
    %
    %   This is the cross-language check that matters for VHSB: NDI-matlab and
    %   NDI-python both store an element's epoch as epoch_binary_data.vhsb, so
    %   each language must be able to read what the OTHER wrote. Every other
    %   battery here compares two JSON transcripts; this one opens the actual
    %   binaries.
    %
    %   The expected values are computed LOCALLY from the shared case list
    %   rather than read out of the artifact, so no float is ever serialized to
    %   text and parsed back. An exact equality assertion therefore means
    %   exactly what it says, and a mismatch is a real difference in the file
    %   format rather than a formatting artifact.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- validate before relying on it.
    %   Run the matching makeArtifacts/element test first to populate the
    %   artifacts.
    %
    %   See also: ndi.symmetry.element.vhsbCases,
    %     ndi.symmetry.makeArtifacts.element.vhsbRoundTrip

    methods (Test)

        function testMatlabArtifactsReadBack(testCase)
            % This language reads its own files -- a cross-run regression guard.
            ndi.symmetry.readArtifacts.element.vhsbRoundTrip.checkAll( ...
                testCase, 'matlabArtifacts');
        end

        function testPythonArtifactsReadBack(testCase)
            % THE POINT: this language reads Python's binaries.
            %
            % A failure here means the two languages do not agree on the VHSB
            % file format -- header field order, sample stride, X storage, or
            % the constant-interval flag -- rather than that one of them
            % computed a different answer.
            ndi.symmetry.readArtifacts.element.vhsbRoundTrip.checkAll( ...
                testCase, 'pythonArtifacts');
        end

        function testCaseSetsAgree(testCase)
            % Both sides must have written the same cases. Without this, each
            % language could read its own files happily while silently
            % covering a different battery.
            mlIndex = ndi.symmetry.readArtifacts.element.vhsbRoundTrip.indexFile('matlabArtifacts');
            pyIndex = ndi.symmetry.readArtifacts.element.vhsbRoundTrip.indexFile('pythonArtifacts');
            testCase.assumeTrue(isfile(mlIndex) && isfile(pyIndex), ...
                'Both VHSB indexes are needed to compare case sets. Skipping.');

            ml = ndi.symmetry.element.vhsbCases.loadIndex(mlIndex);
            py = ndi.symmetry.element.vhsbCases.loadIndex(pyIndex);
            testCase.verifyEqual(sort(string(ml.cases(:)')), sort(string(py.cases(:)')), ...
                'MATLAB and Python wrote different VHSB case sets.');
            testCase.verifyEqual(sort(string(ml.cases(:)')), ...
                sort(string(ndi.symmetry.element.vhsbCases.caseNames())), ...
                'The artifact case set does not match the battery.');
        end

    end

    methods (Static)

        function d = artifactDir(sourceType)
            d = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                'element', 'vhsbRoundTrip', 'testVhsbArtifacts');
        end

        function f = indexFile(sourceType)
            f = fullfile( ...
                ndi.symmetry.readArtifacts.element.vhsbRoundTrip.artifactDir(sourceType), ...
                ndi.symmetry.element.vhsbCases.IndexFile);
        end

        function checkAll(testCase, sourceType)
            % Read every case written by SOURCETYPE and compare against the
            % locally computed values.
            d = ndi.symmetry.readArtifacts.element.vhsbRoundTrip.artifactDir(sourceType);
            idx = ndi.symmetry.readArtifacts.element.vhsbRoundTrip.indexFile(sourceType);
            testCase.assumeTrue(isfile(idx), ...
                sprintf('%s VHSB artifacts missing. Skipping.', sourceType));

            names = ndi.symmetry.element.vhsbCases.caseNames();
            problems = {};
            for i = 1:numel(names)
                f = fullfile(d, [names{i} '.vhsb']);
                if ~isfile(f)
                    problems{end+1} = sprintf('%s: %s wrote no %s.vhsb', ...
                        names{i}, sourceType, names{i}); %#ok<AGROW>
                    continue;
                end
                p = ndi.symmetry.element.vhsbCases.compare(names{i}, f);
                for k = 1:numel(p)
                    problems{end+1} = [names{i} ': ' p{k}]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(problems, sprintf( ...
                'Reading %s VHSB files with this language''s reader:\n  %s', ...
                sourceType, strjoin(problems, sprintf('\n  '))));
        end

    end
end
