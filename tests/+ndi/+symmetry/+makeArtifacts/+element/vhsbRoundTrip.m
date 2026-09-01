classdef vhsbRoundTrip < matlab.unittest.TestCase
    % vhsbRoundTrip (makeArtifacts/element) - write this language's VHSB artifacts
    %
    %   Writes every case in ndi.symmetry.element.vhsbCases as a real .vhsb
    %   file under
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/element/vhsbRoundTrip/
    %              testVhsbArtifacts/
    %
    %   The Python counterpart writes the same case names under
    %   pythonArtifacts/. Unlike the other batteries here, what crosses the
    %   language boundary is the BINARY itself rather than a JSON transcript
    %   of results -- the readArtifacts tests on both sides open the other
    %   language's files. See ndi.symmetry.element.vhsbCases for why.
    %
    %   Each file is read straight back and checked before being published, so
    %   a generator that writes something unreadable fails HERE rather than
    %   looking like a cross-language divergence later.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- validate before relying on it.
    %
    %   See also: ndi.symmetry.element.vhsbCases,
    %     ndi.symmetry.readArtifacts.element.vhsbRoundTrip

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testVhsbArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'element', 'vhsbRoundTrip', 'testVhsbArtifacts');

            names = ndi.symmetry.element.vhsbCases.writeCases(artifactDir);
            testCase.verifyEqual(numel(names), 8, 'Expected 8 recorded cases.');

            for i = 1:numel(names)
                f = fullfile(artifactDir, [names{i} '.vhsb']);
                testCase.assertTrue(isfile(f), ...
                    sprintf('%s.vhsb was not written.', names{i}));
            end

            % Read each one back with this language's reader before publishing.
            problems = {};
            for i = 1:numel(names)
                f = fullfile(artifactDir, [names{i} '.vhsb']);
                p = ndi.symmetry.element.vhsbCases.compare(names{i}, f);
                for k = 1:numel(p)
                    problems{end+1} = [names{i} ': ' p{k}]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(problems, sprintf( ...
                'MATLAB could not read back what it just wrote:\n  %s', ...
                strjoin(problems, sprintf('\n  '))));

            testCase.verifyTrue(isfile(fullfile(artifactDir, ...
                ndi.symmetry.element.vhsbCases.IndexFile)), ...
                'The VHSB index file was not written.');
        end
    end
end
