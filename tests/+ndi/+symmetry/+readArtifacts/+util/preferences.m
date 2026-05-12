classdef preferences < matlab.unittest.TestCase

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testPreferences(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'util', 'preferences', 'testPreferences');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            prefsFile = fullfile(artifactDir, 'NDI_Preferences.json');
            testCase.assertTrue(isfile(prefsFile), ...
                ['NDI_Preferences.json missing in ' SourceType '.']);

            fid = fopen(prefsFile, 'r');
            raw = fread(fid, inf, '*char')';
            fclose(fid);
            S = jsondecode(raw);

            % Assert the key-encoding format Category__Subcategory__Name (or
            % Category__Name) for every field present.
            fields = fieldnames(S);
            testCase.verifyNotEmpty(fields, ['No preference keys in ' SourceType '.']);
            for i = 1:numel(fields)
                parts = split(string(fields{i}), '__');
                testCase.verifyTrue(numel(parts) == 2 || numel(parts) == 3, ...
                    ['Preference key ' fields{i} ' does not match Category__[Subcategory__]Name in ' SourceType '.']);
            end

            % Load the override metadata and round-trip values
            metaFile = fullfile(artifactDir, 'preferences_overrides.json');
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                raw = fread(fid, inf, '*char')';
                fclose(fid);
                overrides = jsondecode(raw);
                ofields = fieldnames(overrides);
                for i = 1:numel(ofields)
                    testCase.verifyTrue(isfield(S, ofields{i}), ...
                        ['Override key ' ofields{i} ' missing from prefs in ' SourceType '.']);
                    testCase.verifyEqual(S.(ofields{i}), overrides.(ofields{i}), ...
                        ['Override value mismatch for ' ofields{i} ' in ' SourceType '.']);
                end
            end
        end
    end
end
