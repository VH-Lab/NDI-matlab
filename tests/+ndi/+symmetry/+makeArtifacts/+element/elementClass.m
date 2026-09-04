classdef elementClass < matlab.unittest.TestCase
    % elementClass (makeArtifacts/element) - write this language's element-class artifacts
    %
    %   Builds a session holding one element of each element class
    %   (ndi.symmetry.element.elementClassCases) and publishes it, together
    %   with a transcript of what this language's getelements makes of it,
    %   under
    %
    %     <tempdir>/NDI/symmetryTest/matlabArtifacts/element/elementClass/
    %              testElementClassArtifacts/
    %
    %   The Python readArtifacts counterpart opens that session and rebuilds
    %   the elements from it -- the direction that NDI-python issue #133 broke,
    %   where a MATLAB-written ndi.neuron could not be reconstructed at all and
    %   was silently dropped from the result.
    %
    %   Every element is read back HERE first, so a generator that writes an
    %   unreadable session fails in this test rather than looking like a
    %   cross-language divergence later.
    %
    %   See also: ndi.symmetry.element.elementClassCases,
    %     ndi.symmetry.readArtifacts.element.elementClass

    properties
        Session
        SessionPath
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            import ndi.symmetry.element.elementClassCases

            testCase.SessionPath = fullfile(tempname(), elementClassCases.SessionReference);
            mkdir(testCase.SessionPath);
            testCase.Session = ndi.session.dir(elementClassCases.SessionReference, ...
                testCase.SessionPath);

            subject = ndi.subject(elementClassCases.SubjectName, '');
            subdoc = subject.newdocument();
            testCase.Session.database_add(subdoc);
            subjectId = subdoc.id();

            % One element per case, each built by the class whose name it must
            % record. ndi.element/newdocument adds the document to the session
            % itself, so there is no separate database_add here.
            %
            % direct is 0 with no underlying element: an element that claims to
            % take its epochs directly from something it does not have is not a
            % shape worth publishing. Python's maker builds the same pair.
            c = elementClassCases.cases();
            for i = 1:numel(c)
                feval(c(i).ndi_element_class, testCase.Session, c(i).name, ...
                    c(i).reference, c(i).type, [], 0, subjectId);
            end
        end
    end

    methods (TestMethodTeardown)
        function persistArtifacts(testCase) %#ok<MANU>
            % Override the default teardown so the artifacts persist for the
            % Python suite (matches the other +makeArtifacts namespaces).
        end
    end

    methods (Test)
        function testElementClassArtifacts(testCase)
            import ndi.symmetry.element.elementClassCases

            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', ...
                'matlabArtifacts', 'element', 'elementClass', 'testElementClassArtifacts');

            % Re-open so nothing is served out of the writing session's cache:
            % the readers get a cold database, and so should the transcript.
            S = ndi.session.dir(elementClassCases.SessionReference, testCase.SessionPath);
            obs = elementClassCases.observe(S.getelements());

            problems = elementClassCases.compare(obs);
            testCase.assertEmpty(problems, sprintf(['MATLAB could not read back the ' ...
                'element classes it just wrote, so there is nothing worth publishing:' ...
                '\n  %s'], strjoin(problems, sprintf('\n  '))));

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            % Copy before creating the directory so copyfile handles the hidden
            % .ndi folder, as the other makeArtifacts tests do.
            copyfile(testCase.SessionPath, artifactDir);

            indexFile = elementClassCases.writeIndex(artifactDir, obs);

            testCase.verifyTrue(isfile(indexFile), 'The element-class index was not written.');
            testCase.verifyTrue(isfolder(fullfile(artifactDir, '.ndi')), ...
                'The session database was not published.');
        end
    end
end
