classdef objectTypeMarker < matlab.unittest.TestCase
    % objectTypeMarker (readArtifacts/session) - verify that a session artifact
    % directory identifies itself as a session, and a dataset artifact directory
    % as a dataset, to ndi.session.dir.directorytype.
    %
    %   Reads the artifact directories that the buildSession / buildDataset
    %   make-side tests produce in BOTH languages:
    %
    %     <tempdir>/NDI/symmetryTest/<SourceType>/session/buildSession/
    %              testBuildSessionArtifacts
    %     <tempdir>/NDI/symmetryTest/<SourceType>/dataset/buildDataset/
    %              testBuildDatasetArtifacts
    %
    %   and asserts that ndi.session.dir.directorytype returns 'session' and
    %   'dataset' respectively. directorytype is the cheap, open-nothing type
    %   probe used by the file-open dialogs, so it is the one place where a
    %   Python-written directory has to speak MATLAB's on-disk vocabulary
    %   (.ndi/ndi_object_type.txt) without any object being instantiated.
    %
    %   This class only READS; it adds no new artifact and no new makeArtifacts
    %   counterpart, so it stays in the +session namespace next to buildSession
    %   and follows that namespace's skip convention (print and return, so an
    %   absent artifact passes silently rather than showing up as Incomplete).
    %
    %   /!\ ORDERING HAZARD -- READ BEFORE TRUSTING A PASS
    %   The ndi.session.dir CONSTRUCTOR calls updateObjectTypeMarker (see
    %   src/ndi/+ndi/+session/dir.m), so any MATLAB test that merely OPENS a
    %   Python-generated artifact directory WRITES the marker into it. In the
    %   readArtifacts suite, ndi.symmetry.readArtifacts.session.buildSession does
    %   exactly that, and 'buildSession' sorts before 'objectTypeMarker'. So for
    %   pythonArtifacts a PASS here is not proof that Python wrote the marker --
    %   only a FAIL is conclusive. Each test therefore also reports whether the
    %   marker file was already present when it ran. The sound version of this
    %   check belongs in Python's own suite, where no MATLAB code has run; see
    %   FUN_CASES_SCHEMA.md.
    %
    %   /!\ AUTHORED WITHOUT A MATLAB RUNTIME -- VALIDATE BEFORE RELYING ON IT.
    %
    %   See also: ndi.session.dir.directorytype,
    %     ndi.session.dir.objecttypemarkerfilename,
    %     ndi.symmetry.readArtifacts.session.buildSession,
    %     ndi.symmetry.readArtifacts.dataset.buildDataset

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)

        function testSessionDirectoryType(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, ...
                'session', 'buildSession', 'testBuildSessionArtifacts');

            if ~isfolder(artifactDir)
                disp(['Session artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            ndi.symmetry.readArtifacts.session.objectTypeMarker.reportMarker(artifactDir, ...
                SourceType, 'session');

            testCase.verifyTrue(ndi.session.dir.exists(artifactDir), ...
                ['The ' SourceType ' session artifact directory is not an NDI directory ' ...
                 '(no .ndi/reference.txt).']);

            t = ndi.session.dir.directorytype(artifactDir);
            testCase.verifyEqual(t, 'session', ...
                ['ndi.session.dir.directorytype returned ''' t ''' for the ' SourceType ...
                 ' session artifact directory; expected ''session''.']);
        end

        function testDatasetDirectoryType(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, ...
                'dataset', 'buildDataset', 'testBuildDatasetArtifacts');

            if ~isfolder(artifactDir)
                disp(['Dataset artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            ndi.symmetry.readArtifacts.session.objectTypeMarker.reportMarker(artifactDir, ...
                SourceType, 'dataset');

            testCase.verifyTrue(ndi.session.dir.exists(artifactDir), ...
                ['The ' SourceType ' dataset artifact directory is not an NDI directory ' ...
                 '(no .ndi/reference.txt).']);

            t = ndi.session.dir.directorytype(artifactDir);
            testCase.verifyEqual(t, 'dataset', ...
                ['ndi.session.dir.directorytype returned ''' t ''' for the ' SourceType ...
                 ' dataset artifact directory; expected ''dataset''. A dataset that has ' ...
                 'never been opened since markers were introduced reports ''unknown''.']);
        end

    end

    methods (Static)

        function reportMarker(artifactDir, sourceType, expectedType)
            % REPORTMARKER - print whether the object-type marker file is
            % present, and what it says.
            %
            %   Diagnostic only -- never asserts. See the ORDERING HAZARD note
            %   in the class help: for pythonArtifacts the marker may have been
            %   written by an earlier MATLAB test opening the directory, so its
            %   presence proves nothing while its ABSENCE proves the generating
            %   language did not write one.
            markerFile = fullfile(artifactDir, '.ndi', ...
                ndi.session.dir.objecttypemarkerfilename());
            if isfile(markerFile)
                % read with plain fopen/fread (the idiom buildSession.m uses)
                % rather than vlt.file.textfile2char, so this diagnostic does not
                % add a toolbox dependency of its own
                fid = fopen(markerFile, 'r');
                if fid < 0
                    fprintf('objectTypeMarker[%s/%s]: marker present but unreadable at %s.\n', ...
                        sourceType, expectedType, markerFile);
                    return;
                end
                contents = strtrim(fread(fid, inf, '*char')');
                fclose(fid);
                fprintf('objectTypeMarker[%s/%s]: marker present, contents ''%s''.\n', ...
                    sourceType, expectedType, contents);
            else
                fprintf(['objectTypeMarker[%s/%s]: NO marker file at %s -- the generating ' ...
                    'language did not write one, so directorytype can only answer ' ...
                    '''unknown''.\n'], sourceType, expectedType, markerFile);
            end
        end

    end
end
