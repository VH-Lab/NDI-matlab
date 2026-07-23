classdef testDatasetConstructor < matlab.unittest.TestCase
    % TESTDATASETCONSTRUCTOR - Test the constructor of ndi.dataset.dir

    properties
        TempDir
    end

    methods (TestMethodSetup)
        function setupTempDir(testCase)
            testCase.TempDir = [tempname];
            mkdir(testCase.TempDir);
            testCase.addTeardown(@rmdir, testCase.TempDir, 's');
        end
    end

    methods (Test)
        function testConstructorWithEmptyDocs(testCase)
            % Test that calling constructor with 3 args where 3rd is empty struct
            % behaves like calling with 2 args.

            ref = 'test_ref';
            path = fullfile(testCase.TempDir, 'test_dataset');
            mkdir(path);

            % 1. Call with 2 arguments
            % We need to create the session directory inside
            mkdir(fullfile(path, '.ndi'));

            % Since ndi.dataset.dir constructor requires a session to exist or creates it?
            % Looking at the code:
            % elseif nargin==2
            %    ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name);

            % ndi.session.dir creates the session if it doesn't exist?
            % ndi.session.dir(reference, path_name)

            ds1 = ndi.dataset.dir(ref, path);

            % 2. Call with 3 arguments (empty cell array)
            % Use a different path so they don't conflict, although they are separate objects
            path2 = fullfile(testCase.TempDir, 'test_dataset_2');
            mkdir(path2);
            mkdir(fullfile(path2, '.ndi'));

            ds2 = ndi.dataset.dir(ref, path2, {});

            % Verify ds2 is a valid ndi.dataset.dir object
            testCase.verifyClass(ds2, 'ndi.dataset.dir');

            % Check path (it might or might not have trailing separator depending on OS/implementation,
            % but typically it doesn't force one if not present in input, or strips it.
            % The error showed it didn't have one.
            expectedPath = path2;
            if ~strcmp(ds2.path, expectedPath) && strcmp(ds2.path, [expectedPath filesep])
                 expectedPath = [expectedPath filesep];
            end
            testCase.verifyEqual(ds2.path, expectedPath);

            % Verify session is initialized by calling a method that relies on it
            % 'session' property is protected, so we cannot access it directly.
            % But .id() delegates to session.id()
            id = ds2.id();
            testCase.verifyNotEmpty(id, 'Dataset ID (delegated to session) should not be empty');
            testCase.verifyTrue(ischar(id) || isstring(id), 'Dataset ID should be a string or char');
        end

        function testOpeningSessionAsDatasetErrors(testCase)
            % Opening a plain session directory as an ndi.dataset.dir must fail
            % cleanly rather than silently succeeding and relabeling the
            % directory as a dataset.

            p = fullfile(testCase.TempDir, 'plain_session');
            mkdir(p);
            s = ndi.session.dir('sess_ref', p); %#ok<NASGU>
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'session');

            % One-argument (open) form.
            testCase.verifyError(@() ndi.dataset.dir(p), ...
                'NDI:dataset:dir:NotADataset');

            % Two-argument (reference, path) form.
            testCase.verifyError(@() ndi.dataset.dir('sess_ref', p), ...
                'NDI:dataset:dir:NotADataset');

            % The failed open must not have altered the directory's type.
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'session');
        end

        function testOpeningDatasetAsDatasetStillWorks(testCase)
            % The guard must not block re-opening a genuine dataset.
            p = fullfile(testCase.TempDir, 'real_dataset');
            mkdir(p);
            d1 = ndi.dataset.dir('ds_ref', p); %#ok<NASGU>
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');

            d2 = ndi.dataset.dir(p);
            testCase.verifyClass(d2, 'ndi.dataset.dir');
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
        end

        function testOpeningUnmarkedSessionAsDatasetErrors(testCase)
            % A legacy session whose type marker was never recorded ('unknown')
            % must be investigated and caught, not mislabeled as a dataset.
            p = fullfile(testCase.TempDir, 'legacy_session');
            mkdir(p);
            s = ndi.session.dir('sess_ref', p); %#ok<NASGU>

            % Simulate a pre-marker directory by deleting the marker file.
            markerfile = fullfile(p, '.ndi', ...
                ndi.session.dir.objecttypemarkerfilename());
            delete(markerfile);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'unknown');

            % Opening as a dataset must fail and must have recorded 'session'.
            testCase.verifyError(@() ndi.dataset.dir(p), ...
                'NDI:dataset:dir:NotADataset');
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'session');
        end

        function testOpeningUnmarkedPopulatedDatasetStillWorks(testCase)
            % A legacy dataset that carries bookkeeping documents but whose
            % marker was never recorded ('unknown') must be recognized as a
            % dataset by the investigation and still open.
            p = fullfile(testCase.TempDir, 'legacy_dataset');
            mkdir(p);
            d1 = ndi.dataset.dir('ds_ref', p);

            % Give it dataset bookkeeping (a 'session_in_a_dataset' document) by
            % linking a session, so that it is distinguishable from a plain
            % session on disk, then simulate a pre-marker directory by deleting
            % the marker file.
            memberDir = fullfile(testCase.TempDir, 'member_session');
            mkdir(memberDir);
            s = ndi.session.dir('member_ref', memberDir);
            d1.add_linked_session(s);
            markerfile = fullfile(p, '.ndi', ...
                ndi.session.dir.objecttypemarkerfilename());
            delete(markerfile);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'unknown');

            % Re-opening must succeed and re-record 'dataset'.
            d2 = ndi.dataset.dir(p);
            testCase.verifyClass(d2, 'ndi.dataset.dir');
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
        end
    end
end
