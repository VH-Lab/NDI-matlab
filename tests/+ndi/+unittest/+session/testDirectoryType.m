classdef testDirectoryType < matlab.unittest.TestCase
    % TESTDIRECTORYTYPE - Test quick session/dataset directory-type detection
    %
    % Exercises ndi.session.dir.directorytype, ndi.dataset.dir.exists, and the
    % .ndi object-type marker file written by the ndi.session.dir and
    % ndi.dataset.dir constructors.

    properties
        TempDir
    end

    methods (TestMethodSetup)
        function setupTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@rmdir, testCase.TempDir, 's');
        end
    end

    methods (Test)

        function testSessionIsDetectedAsSession(testCase)
            % A plain session directory should report as 'session'.
            p = fullfile(testCase.TempDir, 'a_session');
            mkdir(p);
            s = ndi.session.dir('my_ref', p); %#ok<NASGU>

            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'session');
            testCase.verifyFalse(ndi.dataset.dir.exists(p));
            testCase.verifyTrue(ndi.session.dir.exists(p)); % any NDI dir
        end

        function testEmptyDatasetIsDetectedAsDataset(testCase)
            % The important case: a freshly created dataset with NO sessions
            % yet must still report as 'dataset'.
            p = fullfile(testCase.TempDir, 'an_empty_dataset');
            mkdir(p);
            d = ndi.dataset.dir('my_ds_ref', p); %#ok<NASGU>

            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
            testCase.verifyTrue(ndi.dataset.dir.exists(p));
            testCase.verifyTrue(ndi.session.dir.exists(p)); % any NDI dir
        end

        function testNonNDIDirectoryIsNone(testCase)
            % A directory with no .ndi content is not an NDI directory.
            p = fullfile(testCase.TempDir, 'not_ndi');
            mkdir(p);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'none');
            testCase.verifyFalse(ndi.dataset.dir.exists(p));
        end

        function testLegacyDirectoryIsUnknownThenMigrated(testCase)
            % A directory created before markers existed (marker file absent)
            % should report 'unknown', then be migrated to 'session' when opened.
            p = fullfile(testCase.TempDir, 'legacy_session');
            mkdir(p);
            s = ndi.session.dir('legacy_ref', p); %#ok<NASGU>

            % Simulate a legacy directory by removing the marker file.
            markerfile = fullfile(p, '.ndi', ndi.session.dir.objecttypemarkerfilename());
            delete(markerfile);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'unknown');

            % Re-opening records the type (lazy migration).
            s2 = ndi.session.dir(p); %#ok<NASGU>
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'session');
        end

        function testReopeningEmptyDatasetAsSessionDoesNotDowngrade(testCase)
            % Opening a dataset directory through ndi.session.dir must not
            % relabel it as a plain session (the dataset marker must survive).
            p = fullfile(testCase.TempDir, 'dataset_reopened_as_session');
            mkdir(p);
            d = ndi.dataset.dir('ds_ref', p); %#ok<NASGU>
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');

            % Open the same directory as a session (as the dataset itself does
            % internally) and confirm the marker is preserved.
            s = ndi.session.dir(p); %#ok<NASGU>
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
            testCase.verifyTrue(ndi.dataset.dir.exists(p));
        end

    end
end
