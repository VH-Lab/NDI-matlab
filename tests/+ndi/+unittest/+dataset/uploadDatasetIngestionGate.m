classdef uploadDatasetIngestionGate < matlab.unittest.TestCase
    % uploadDatasetIngestionGate - uploadDataset must RETURN its refusal, not error.
    %
    %   Issue #914. ndi.cloud.uploadDataset declares three outputs and
    %   refuses a dataset that is not fully ingested as its first act
    %   (uploadDataset.m:53). That refusal returned before cloudDatasetId had
    %   ever been assigned, so MATLAB raised
    %
    %       Output argument "cloudDatasetId" (and maybe others) not assigned
    %
    %   instead of handing back the message the code had just written. Every
    %   caller asking for more than one output hit it, including the dataset
    %   navigator's upload action (datasetsPane.m:661) -- so a user uploading
    %   a dataset with linked sessions got a raw MATLAB error rather than
    %   "Dataset is not fully ingested."
    %
    %   WHY THIS TEST IS HERE AND NOT IN +cloud
    %   The refusal is the one branch of uploadDataset that touches no
    %   network, so it is the one branch testable offline. Tests under
    %   tests/+ndi/+unittest/+cloud are excluded from the main suite by
    %   testToolboxNoCloud and need live NDI Cloud credentials; a bug on a
    %   path that never calls the cloud would keep hiding there. It sits
    %   beside isInCloudTest, which tests another cloud-adjacent dataset
    %   method entirely offline for the same reason.
    %
    %   Every existing uploadDataset test uploads a dataset that IS fully
    %   ingested, which is why none of them reached this line.
    %
    %   See also: ndi.unittest.dataset.notIngestedDataset

    properties
        Dataset
        testDir
    end

    methods (TestMethodSetup)
        function makeDataset(testCase)
            testCase.Dataset = ndi.unittest.dataset.notIngestedDataset();
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            if ~isempty(testCase.testDir) && isfolder(testCase.testDir)
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods (Test)

        function testThreeOutputCallReturnsTheRefusal(testCase)
            % THE BUG. Pre-fix this line errors rather than returning.
            [success, cloudDatasetId, message] = ...
                ndi.cloud.uploadDataset(testCase.Dataset);

            testCase.verifyFalse(success, ...
                'A dataset that is not fully ingested must not report a successful upload.');
            testCase.verifyEmpty(cloudDatasetId, ...
                'No remote dataset was created, so cloudDatasetId must come back empty.');
            testCase.verifyClass(cloudDatasetId, 'char', ...
                'cloudDatasetId is documented as a char; [] would be a different contract.');
            testCase.verifySubstring(message, 'not fully ingested', ...
                'The caller must receive the reason the upload was refused.');
        end

        function testNavigatorCallShapeReturnsTheRefusal(testCase)
            % The exact shape the dataset navigator uses (datasetsPane.m:661).
            % `~` still requests three outputs, so it is expected to have
            % failed the same way; pinning the shape settles it either way.
            [success, ~, message] = ndi.cloud.uploadDataset(testCase.Dataset);

            testCase.verifyFalse(success);
            testCase.verifySubstring(message, 'not fully ingested');
        end

        function testTwoOutputCallReturnsTheRefusal(testCase)
            [success, cloudDatasetId] = ndi.cloud.uploadDataset(testCase.Dataset);

            testCase.verifyFalse(success);
            testCase.verifyEmpty(cloudDatasetId);
        end

        function testSingleOutputCallStillWorks(testCase)
            % The one call shape that was NEVER broken -- nargout of 1 never
            % asks for cloudDatasetId. It is here so the fix is shown to
            % preserve working behaviour, not only to repair broken behaviour.
            success = ndi.cloud.uploadDataset(testCase.Dataset);

            testCase.verifyFalse(success);
        end

        function testAnIngestedDatasetDoesNotTripTheGate(testCase)
            % Guards against the gate over-firing. A real, empty dataset is
            % fully ingested (ndi.dataset/isIngested returns true when there
            % are no sessions), so uploadDataset would proceed past line 53.
            %
            % uploadDataset itself is deliberately NOT called here: past that
            % line it talks to NDI Cloud, and this suite runs without
            % credentials. What is asserted is the gate's input.
            testCase.testDir = char(tempname);
            mkdir(testCase.testDir);

            ds = ndi.dataset.dir('ingestedEnough', testCase.testDir);
            testCase.verifyTrue(ds.isIngested(), ...
                'An empty dataset is fully ingested, so the upload gate must not fire on it.');
        end

    end
end
