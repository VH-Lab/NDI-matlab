classdef elementClass < matlab.unittest.TestCase
    % elementClass (readArtifacts/element) - rebuild BOTH languages' elements
    %
    %   The cross-language check that matters here is not that the two
    %   languages spell the class names the same way -- it is that each one can
    %   rebuild what the other wrote. NDI-python issue #133 is the proof:
    %   Python could not reconstruct a MATLAB-written ndi.neuron at all, and
    %   because its getelements swallowed the failure, the symptom was an empty
    %   list rather than an error.
    %
    %   So each test opens a session directory produced by one language's
    %   makeArtifacts suite, calls getelements, and checks the class of every
    %   object that comes back against the shared case list -- computed
    %   LOCALLY, not read out of the artifact.
    %
    %   Run the matching makeArtifacts/element test first to populate the
    %   artifacts.
    %
    %   See also: ndi.symmetry.element.elementClassCases,
    %     ndi.symmetry.makeArtifacts.element.elementClass

    methods (Test)

        function testMatlabArtifactsRebuild(testCase)
            % This language reads its own session -- a cross-run regression guard.
            ndi.symmetry.readArtifacts.element.elementClass.checkRebuild( ...
                testCase, 'matlabArtifacts');
        end

        function testPythonArtifactsRebuild(testCase)
            % THE POINT: this language rebuilds Python's elements.
            %
            % A failure here means the two languages disagree about what class
            % wrote a document, rather than that one of them computed a
            % different answer.
            ndi.symmetry.readArtifacts.element.elementClass.checkRebuild( ...
                testCase, 'pythonArtifacts');
        end

        function testMatlabTranscriptAgrees(testCase)
            ndi.symmetry.readArtifacts.element.elementClass.checkTranscript( ...
                testCase, 'matlabArtifacts');
        end

        function testPythonTranscriptAgrees(testCase)
            ndi.symmetry.readArtifacts.element.elementClass.checkTranscript( ...
                testCase, 'pythonArtifacts');
        end

    end

    methods (Static)

        function d = artifactDir(sourceType)
            d = fullfile(tempdir(), 'NDI', 'symmetryTest', sourceType, ...
                'element', 'elementClass', 'testElementClassArtifacts');
        end

        function [d, S] = requireSession(testCase, sourceType)
            import ndi.symmetry.element.elementClassCases
            d = ndi.symmetry.readArtifacts.element.elementClass.artifactDir(sourceType);
            testCase.assumeTrue(isfile(fullfile(d, elementClassCases.IndexFile)), sprintf( ...
                ['%s element-class artifacts missing. Run the corresponding ' ...
                 'makeArtifacts suite first. Skipping.'], sourceType));
            S = ndi.session.dir(elementClassCases.SessionReference, d);
        end

        function checkRebuild(testCase, sourceType)
            % Every element must come back as its own class, not the base one.
            import ndi.symmetry.element.elementClassCases
            [~, S] = ndi.symmetry.readArtifacts.element.elementClass.requireSession( ...
                testCase, sourceType);

            problems = elementClassCases.compare(elementClassCases.observe(S.getelements()));
            testCase.verifyEmpty(problems, sprintf( ...
                'Rebuilding %s elements with this language''s reader:\n  %s', ...
                sourceType, strjoin(problems, sprintf('\n  '))));
        end

        function checkTranscript(testCase, sourceType)
            % The writer's own reading of the session must match this reader's.
            %
            % A difference here means the two languages disagree about the same
            % database, which is narrower information than checkRebuild and
            % worth separating from it.
            import ndi.symmetry.element.elementClassCases
            [d, S] = ndi.symmetry.readArtifacts.element.elementClass.requireSession( ...
                testCase, sourceType);

            stored = elementClassCases.loadIndex(fullfile(d, elementClassCases.IndexFile));
            testCase.verifyEqual(char(stored.sessionReference), ...
                char(elementClassCases.SessionReference), ...
                'The artifact was written under a different session reference.');

            problems = elementClassCases.compareLists( ...
                elementClassCases.observe(S.getelements()), stored.elements);
            testCase.verifyEmpty(problems, sprintf( ...
                'This reader and the %s writer disagree about the same session:\n  %s', ...
                sourceType, strjoin(problems, sprintf('\n  '))));
        end

    end
end
