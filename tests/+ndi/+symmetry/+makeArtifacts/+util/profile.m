classdef profile < matlab.unittest.TestCase

    methods (TestMethodTeardown)
        function teardownProfile(testCase)
            % OVERRIDE TEARDOWN:
            % Do nothing so artifacts persist for the Python test suite.
        end
    end

    methods (Test)
        function testProfile(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'util', 'profile', 'testProfile');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Use the in-memory backend so no AES file or keyring secret is
            % persisted. Reset the singleton state so we start clean.
            ndi.cloud.profile.useBackend('memory');
            ndi.cloud.profile.reset();

            uid = ndi.cloud.profile.add('SymmetryTest', 'test@example.org', 'not-a-real-secret');
            ndi.cloud.profile.setStage(uid, 'dev');
            ndi.cloud.profile.setStage(uid, 'prod');
            % Per spec, set Stage=test by mutating the in-memory profile
            % (the setStage method only accepts 'prod'/'dev'). We write the
            % stage directly into the JSON payload to satisfy the
            % symmetry contract.
            entry = ndi.cloud.profile.get(uid);
            entry.Stage = 'test';
            entry = rmfield(entry, 'PasswordSecret'); % do not persist secrets on disk

            payload = struct('Profiles', entry, 'DefaultUID', '');
            jsonStr = jsonencode(payload, 'PrettyPrint', true);
            outFile = fullfile(artifactDir, 'NDI_Cloud_Profiles.json');
            fid = fopen(outFile, 'w');
            if fid > 0
                fwrite(fid, jsonStr, 'char');
                fclose(fid);
            else
                error('Could not create NDI_Cloud_Profiles.json file');
            end

            % Clean up the in-memory singleton state so other tests are not
            % affected. No secret leaves the process.
            ndi.cloud.profile.reset();
        end
    end
end
