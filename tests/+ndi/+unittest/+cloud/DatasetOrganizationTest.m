classdef DatasetOrganizationTest < matlab.unittest.TestCase
% DatasetOrganizationTest - Test suite for moving a dataset between organizations.
%
%   Exercises ndi.cloud.api.datasets.reassignDatasetOrganization, the
%   client wrapper around the admin-only endpoint
%
%     POST /admin/datasets/{datasetId}/organization
%
%   and checks that the ordinary metadata update
%   (ndi.cloud.api.datasets.updateDataset) cannot change a dataset's
%   organization. Organization membership is what grants access to an
%   unpublished dataset, so moving one changes who can see it; that is why
%   only administrators may do it.
%
%   Which tests run depends on the test account:
%
%     - Every account: updateDataset must leave organizationId unchanged.
%     - Accounts WITHOUT administrator rights: the move must answer 403.
%       The admin tests are skipped.
%     - Accounts WITH administrator rights: the tests of the server's
%       input checks run (they change nothing), and the 403 test is skipped.
%     - Accounts WITH administrator rights, against the dev API (or with
%       NDI_CLOUD_ALLOW_ADMIN_WRITE_TESTS=true): the round-trip test also
%       runs. It moves a dataset it created itself into the scratch
%       organization used by AdminOrganizationsTest, moves it back, and
%       deletes it.
%
%   Requirements:
%     - NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment variables
%     - CLOUD_API_ENVIRONMENT=dev to run against the dev API
%     - Optional: NDI_CLOUD_TEST_ADMIN_ORGANIZATION_ID to name the scratch
%       organization to use instead of finding or creating one by name

    properties (Constant)
        DatasetNamePrefix = "NDI_UNITTEST_DATASET_ORG_";
        ScratchOrganizationName = "NDI-matlab admin unittest scratch (safe to ignore)";
        % Valid 24-hex id that will not match any stored record.
        NonexistentID = "000000000000000000000000";
        Reason = "NDI-matlab unittest DatasetOrganizationTest";
    end

    properties
        Narrative (1,:) string
        IsAdmin (1,1) logical = false
        HomeOrganizationID (1,1) string = ""
        DatasetID (1,1) string = missing
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = ['Missing NDI Cloud credentials (NDI_CLOUD_USERNAME/', ...
                'NDI_CLOUD_PASSWORD). Skipping cloud-dependent tests.'];
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function identifyTestAccount(testCase)
            % Admin status comes from the server's own record of the
            % account, so the suite needs no extra configuration.
            [b, me, resp, url] = ndi.cloud.api.users.me();
            msg = ndi.unittest.cloud.APIMessage("Fetching the test account with users.me", ...
                b, me, resp, url);
            testCase.assertTrue(b, msg);
            testCase.IsAdmin = isfield(me, 'isAdmin') && logical(me.isAdmin);
            % Tests that need a dataset skip (see assumeHomeOrganization)
            % when the account has no organization that allows upload.
            try
                testCase.HomeOrganizationID = string(ndi.unittest.cloud.testOrganizationID());
            catch
                testCase.HomeOrganizationID = "";
            end
        end

        function checkEndpointDeployed(testCase)
            % Skip (rather than fail) in an API environment that does not
            % have the endpoint yet: there the API's catch-all answers 404.
            % A deployed endpoint answers this call (blank reason) with 403
            % for non-admins or 400 for admins, before any lookup.
            [~, ~, resp] = ndi.unittest.cloud.DatasetOrganizationTest.callWithoutReasonCheck( ...
                testCase.NonexistentID, testCase.NonexistentID, "");
            testCase.assumeNotEqual(double(resp.StatusCode), 404, ...
                "POST /admin/datasets/{datasetId}/organization is not deployed in this " + ...
                "API environment. Skipping DatasetOrganizationTest.");
        end
    end

    methods (TestMethodSetup)
        function resetNarrative(testCase)
            testCase.Narrative = "Begin DatasetOrganizationTest";
            testCase.DatasetID = missing;
        end
    end

    methods (Static, Access = private)
        function [b, answer, resp, url] = callWithoutReasonCheck(datasetID, orgID, reason)
            % Call the implementation class directly, skipping the
            % wrapper's own non-blank reason check, so the server's checks
            % can be tested.
            api_call = ndi.cloud.api.implementation.datasets.ReassignDatasetOrganization( ...
                'cloudDatasetID', datasetID, 'cloudOrganizationID', orgID, 'reason', reason);
            [b, answer, resp, url] = api_call.execute();
        end
    end

    methods (Access = private)
        function assumeAdmin(testCase)
            testCase.assumeTrue(testCase.IsAdmin, ...
                "The test account is not an administrator. Skipping admin-only test.");
        end

        function assumeWriteAllowed(testCase)
            testCase.assumeAdmin();
            allowed = strcmpi(getenv("CLOUD_API_ENVIRONMENT"), "dev") || ...
                strcmpi(getenv("NDI_CLOUD_ALLOW_ADMIN_WRITE_TESTS"), "true");
            testCase.assumeTrue(allowed, ...
                "Admin tests that move datasets run only against the dev API " + ...
                "(or with NDI_CLOUD_ALLOW_ADMIN_WRITE_TESTS=true). Skipping.");
        end

        function assumeHomeOrganization(testCase)
            testCase.assumeGreaterThan(strlength(testCase.HomeOrganizationID), 0, ...
                "The test account does not belong to any organization that allows " + ...
                "dataset upload. Skipping test that needs one.");
        end

        function datasetID = createTemporaryDataset(testCase, narrative)
            % Create a dataset in the home organization and schedule its deletion.
            testCase.assumeHomeOrganization();
            uniqueName = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b, datasetID, resp, url] = ndi.cloud.api.datasets.createDataset( ...
                struct("name", uniqueName), 'organizationID', char(testCase.HomeOrganizationID));
            narrative(end+1) = "SETUP: Creating temporary dataset " + uniqueName + ...
                " in organization " + testCase.HomeOrganizationID + ".";
            testCase.assertTrue(b, ndi.unittest.cloud.APIMessage(narrative, b, datasetID, resp, url));
            datasetID = string(datasetID);
            testCase.DatasetID = datasetID;
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(datasetID, 'when', 'now'));
        end

        function orgID = organizationOf(testCase, datasetID, narrative)
            % Read the dataset's current organization with the ordinary getDataset.
            [b, ds, resp, url] = ndi.cloud.api.datasets.getDataset(datasetID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.assertTrue(b, msg);
            testCase.assertTrue(isfield(ds, 'organizationId'), msg);
            orgID = string(ds.organizationId);
        end

        function orgID = scratchOrganization(testCase)
            % Return the id of the scratch organization, finding or creating it.
            orgID = string(getenv("NDI_CLOUD_TEST_ADMIN_ORGANIZATION_ID"));
            if strlength(orgID) == 0
                [b, r, resp, url] = ndi.cloud.api.admin.listOrganizations( ...
                    'query', testCase.ScratchOrganizationName, 'pageSize', 100);
                testCase.assertTrue(b, ndi.unittest.cloud.APIMessage( ...
                    "Searching for the scratch organization", b, r, resp, url));
                orgs = ndi.cloud.api.implementation.admin.asStructCell(r.organizations);
                for i = 1:numel(orgs)
                    if string(orgs{i}.name) == testCase.ScratchOrganizationName
                        orgID = string(orgs{i}.id);
                        break
                    end
                end
            end
            if strlength(orgID) == 0
                [b, org, resp, url] = ndi.cloud.api.admin.createOrganization( ...
                    testCase.ScratchOrganizationName);
                testCase.assertTrue(b, ndi.unittest.cloud.APIMessage( ...
                    "Creating the scratch organization", b, org, resp, url));
                orgID = string(org.id);
            end
            testCase.assertNotEqual(orgID, testCase.HomeOrganizationID, ...
                "The scratch organization is the test account's own dataset organization. " + ...
                "Point NDI_CLOUD_TEST_ADMIN_ORGANIZATION_ID at a dedicated organization.");
        end
    end

    methods (Test)
        % ------------------------------------------------------------------
        % Any account: the ordinary metadata update ignores organizationId.
        function testUpdateDatasetCannotChangeOrganization(testCase)
            narrative = testCase.Narrative;
            narrative(end+1) = "Testing that updateDataset cannot move a dataset to another organization.";
            datasetID = testCase.createTemporaryDataset(narrative);

            narrative(end+1) = "Reading the dataset's organization before the update.";
            before = testCase.organizationOf(datasetID, narrative);
            testCase.verifyEqual(before, testCase.HomeOrganizationID, ...
                ndi.unittest.cloud.APIMessage(narrative, true, before, [], ""));

            narrative(end+1) = "Calling updateDataset with a new name and organizationId = " + ...
                testCase.NonexistentID + "; expecting the name to change and the organization not to.";
            newName = testCase.DatasetNamePrefix + "renamed_" + string(did.ido.unique_id());
            [b, answer, resp, url] = ndi.cloud.api.datasets.updateDataset(datasetID, ...
                struct('name', char(newName), 'organizationId', char(testCase.NonexistentID)));
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.assertTrue(b, msg);

            narrative(end+1) = "Reading the dataset back.";
            [b, ds, resp, url] = ndi.cloud.api.datasets.getDataset(datasetID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.assertTrue(b, msg);
            narrative(end+1) = "Testing: the name changed, so the update was applied.";
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.verifyEqual(string(ds.name), newName, msg);
            narrative(end+1) = "Testing: organizationId is unchanged.";
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.verifyEqual(string(ds.organizationId), before, msg);
            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % An account without administrator rights cannot move datasets,
        % even a dataset it owns.
        function testNonAdminIsForbidden(testCase)
            testCase.assumeFalse(testCase.IsAdmin, ...
                "The test account is an administrator. Skipping the non-admin test.");
            narrative = testCase.Narrative;
            datasetID = testCase.createTemporaryDataset(narrative);

            narrative(end+1) = "Calling reassignDatasetOrganization on the account's own dataset " + ...
                "without admin rights; expecting 403.";
            [b, answer, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                datasetID, testCase.NonexistentID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 403, msg);

            narrative(end+1) = "Testing: the dataset is still in its original organization.";
            testCase.verifyEqual(testCase.organizationOf(datasetID, narrative), ...
                testCase.HomeOrganizationID, ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url));
            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % The wrapper refuses a blank reason before calling the server.
        function testBlankReasonIsRefusedLocally(testCase)
            narrative = testCase.Narrative;
            narrative(end+1) = "Calling reassignDatasetOrganization with a blank reason; expecting a local error.";
            testCase.verifyError(@() ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                testCase.NonexistentID, testCase.NonexistentID, "   "), ...
                'NDI:Cloud:Datasets:ReasonRequired', strjoin(narrative, newline));
            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Admin: the server's input checks. None of these changes anything.
        function testServerInputChecks(testCase)
            testCase.assumeAdmin();
            testCase.assumeHomeOrganization();
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling the endpoint with a malformed dataset id; expecting 400.";
            [b, r, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                "not-an-id", testCase.NonexistentID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);

            narrative(end+1) = "Calling the endpoint with a malformed organization id; expecting 400.";
            [b, r, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                testCase.NonexistentID, "not-an-id", testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);

            narrative(end+1) = "Calling the endpoint directly with an empty reason; expecting the server to answer 400.";
            [b, r, resp, url] = ndi.unittest.cloud.DatasetOrganizationTest.callWithoutReasonCheck( ...
                testCase.NonexistentID, testCase.HomeOrganizationID, "");
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);

            narrative(end+1) = "Calling the endpoint with an unknown organization; expecting 404.";
            [b, r, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                testCase.NonexistentID, testCase.NonexistentID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, msg);

            narrative(end+1) = "Calling the endpoint with an unknown dataset; expecting 404.";
            [b, r, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                testCase.NonexistentID, testCase.HomeOrganizationID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, msg);
            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Admin, dev API: move a dataset into the scratch organization and
        % back again.
        function testReassignRoundTrip(testCase)
            testCase.assumeWriteAllowed();
            testCase.assumeHomeOrganization();
            narrative = testCase.Narrative;
            scratchID = testCase.scratchOrganization();
            homeID = testCase.HomeOrganizationID;
            datasetID = testCase.createTemporaryDataset(narrative);
            narrative(end+1) = "SETUP: Using temporary dataset " + datasetID + ...
                "; scratch organization is " + scratchID + ".";

            narrative(end+1) = "Moving the dataset to the organization it is already in; expecting 400.";
            [b, r, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                datasetID, homeID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);

            narrative(end+1) = "Moving the dataset to the scratch organization.";
            [b, ds, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                datasetID, scratchID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.assertTrue(b, msg);
            narrative(end+1) = "Testing: the response reports the scratch organization.";
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.verifyEqual(string(ds.id), datasetID, msg);
            testCase.verifyEqual(string(ds.organizationId), scratchID, msg);

            narrative(end+1) = "Testing: getDataset also reports the scratch organization.";
            testCase.verifyEqual(testCase.organizationOf(datasetID, narrative), scratchID, ...
                ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url));

            narrative(end+1) = "Moving the dataset back to its original organization.";
            [b, ds, resp, url] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
                datasetID, homeID, testCase.Reason);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(string(ds.organizationId), homeID, msg);

            narrative(end+1) = "Testing: getDataset reports the original organization again.";
            testCase.verifyEqual(testCase.organizationOf(datasetID, narrative), homeID, ...
                ndi.unittest.cloud.APIMessage(narrative, b, ds, resp, url));
            testCase.Narrative = narrative;
        end
    end
end
