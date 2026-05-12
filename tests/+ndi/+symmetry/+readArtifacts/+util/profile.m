classdef profile < matlab.unittest.TestCase

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testProfile(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'util', 'profile', 'testProfile');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            profilesFile = fullfile(artifactDir, 'NDI_Cloud_Profiles.json');
            testCase.assertTrue(isfile(profilesFile), ...
                ['NDI_Cloud_Profiles.json missing in ' SourceType '.']);

            fid = fopen(profilesFile, 'r');
            raw = fread(fid, inf, '*char')';
            fclose(fid);
            S = jsondecode(raw);

            testCase.assertTrue(isfield(S, 'Profiles'), ...
                ['Profiles field missing in ' SourceType '.']);
            testCase.assertTrue(isfield(S, 'DefaultUID'), ...
                ['DefaultUID field missing in ' SourceType '.']);

            profiles = S.Profiles;
            if isstruct(profiles)
                arr = profiles;
            elseif iscell(profiles)
                arr = [profiles{:}];
            else
                testCase.verifyFail(['Unexpected Profiles type in ' SourceType '.']);
                return;
            end
            testCase.verifyEqual(numel(arr), 1, ...
                ['Expected exactly one profile entry in ' SourceType '.']);

            p = arr(1);
            testCase.verifyTrue(isfield(p, 'UID') && ~isempty(p.UID), ...
                ['UID missing in ' SourceType ' profile.']);
            testCase.verifyEqual(char(p.Nickname), 'SymmetryTest', ...
                ['Nickname mismatch in ' SourceType '.']);
            testCase.verifyEqual(char(p.Email), 'test@example.org', ...
                ['Email mismatch in ' SourceType '.']);
            testCase.verifyEqual(char(p.Stage), 'test', ...
                ['Stage should be ''test'' in ' SourceType '.']);
            testCase.verifyFalse(isfield(p, 'PasswordSecret'), ...
                ['PasswordSecret must not be persisted on disk in ' SourceType '.']);
        end
    end
end
