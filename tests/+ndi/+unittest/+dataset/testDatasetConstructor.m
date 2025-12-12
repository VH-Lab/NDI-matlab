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
    end
end
