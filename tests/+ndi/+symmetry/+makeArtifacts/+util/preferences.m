classdef preferences < matlab.unittest.TestCase

    methods (TestMethodTeardown)
        function teardownPreferences(testCase)
            % OVERRIDE TEARDOWN:
            % Do nothing so artifacts persist for the Python test suite.
        end
    end

    methods (Test)
        function testPreferences(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'util', 'preferences', 'testPreferences');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Load the live preferences singleton so we use the real registered
            % defaults; then build a flat JSON payload using the same
            % 'Category__Subcategory__Name' encoding that ndi.preferences uses
            % on disk. We write to the artifact dir rather than overwriting
            % the user's real prefdir copy.
            items = ndi.preferences.list();

            % Override a couple of non-default values for round-trip testing
            overrides = struct();
            overrides.Cloud__Upload__Max_File_Batch_Size = 123456789;
            overrides.Cloud__Download__Max_Document_Batch_Count = 42;

            S = struct();
            for i = 1:numel(items)
                if isempty(items(i).Subcategory)
                    key = sprintf('%s__%s', items(i).Category, items(i).Name);
                else
                    key = sprintf('%s__%s__%s', items(i).Category, items(i).Subcategory, items(i).Name);
                end
                if isfield(overrides, key)
                    S.(key) = overrides.(key);
                else
                    S.(key) = items(i).DefaultValue;
                end
            end

            jsonStr = jsonencode(S, 'PrettyPrint', true);
            outFile = fullfile(artifactDir, 'NDI_Preferences.json');
            fid = fopen(outFile, 'w');
            if fid > 0
                fwrite(fid, jsonStr, 'char');
                fclose(fid);
            else
                error('Could not create NDI_Preferences.json file');
            end

            % Also record the override metadata so the read test can verify
            metaFile = fullfile(artifactDir, 'preferences_overrides.json');
            metaStr = jsonencode(overrides, 'PrettyPrint', true);
            fid = fopen(metaFile, 'w');
            if fid > 0
                fwrite(fid, metaStr, 'char');
                fclose(fid);
            else
                error('Could not create preferences_overrides.json file');
            end
        end
    end
end
