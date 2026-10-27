classdef AdminOrganizationsTest < matlab.unittest.TestCase
% AdminOrganizationsTest - Test suite for the ndi.cloud.api.admin organization commands.
%
%   Exercises the client wrappers around the admin endpoints
%   (ndi-cloud-node admin.router.ts):
%
%     GET    /admin/organizations
%     GET    /admin/organizations/{organizationId}
%     PATCH  /admin/organizations/{organizationId}
%     POST   /admin/organizations/{organizationId}/members
%     DELETE /admin/organizations/{organizationId}/members/{userId}
%     GET    /admin/users
%     GET    /admin/users/{userId}
%
%   Which tests run depends on the test account:
%
%     - Every account: getUserOrganizations() with no input, which needs
%       no administrator rights.
%     - Accounts WITHOUT administrator rights: the admin endpoints must
%       answer 403. The admin tests are skipped.
%     - Accounts WITH administrator rights: the read-only admin tests run,
%       and the 403 test is skipped.
%     - Accounts WITH administrator rights, against the dev API (or with
%       NDI_CLOUD_ALLOW_ADMIN_WRITE_TESTS=true): the tests that change
%       organizations also run. They only touch a dedicated scratch
%       organization (see scratchOrganization), add the test account to it
%       and remove it again, so nothing the account really belongs to is
%       changed. The API cannot delete organizations, so the scratch
%       organization is created once and reused.
%
%   Requirements:
%     - NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment variables
%     - CLOUD_API_ENVIRONMENT=dev to run against the dev API
%     - Optional: NDI_CLOUD_TEST_ADMIN_ORGANIZATION_ID to name the scratch
%       organization to use instead of finding or creating one by name

    properties (Constant)
        ScratchOrganizationName = "NDI-matlab admin unittest scratch (safe to ignore)";
        % Valid 24-hex id that will not match any stored record.
        NonexistentID = "000000000000000000000000";
    end

    properties
        Narrative (1,:) string
        IsAdmin (1,1) logical = false
        MyID (1,1) string = ""
        MyEmail (1,1) string = ""
        MyOrganizationIDs (1,:) string = string.empty(1,0)
        ScratchOrganizationID (1,1) string = ""
    end

    methods (Static, Access = private)
        function ids = idRow(c)
            % IDROW Return a cell array of ids as a 1-by-N string row (1-by-0 if empty).
            ids = reshape(string(c), 1, []);
        end
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
            testCase.MyID = string(me.id);
            testCase.MyEmail = string(me.email);
            testCase.MyOrganizationIDs = ndi.unittest.cloud.AdminOrganizationsTest.idRow(me.organizationID);
        end

        function checkEndpointDeployed(testCase)
            % Skip (rather than fail) in an API environment that does not
            % have the admin endpoints: there the API's catch-all answers
            % 404, while a deployed endpoint answers 200 or 403.
            [~, ~, resp] = ndi.cloud.api.admin.listOrganizations('pageSize', 1);
            testCase.assumeNotEqual(double(resp.StatusCode), 404, ...
                "The /admin endpoints are not deployed in this API environment. Skipping AdminOrganizationsTest.");
        end
    end

    methods (TestMethodSetup)
        function resetNarrative(testCase)
            testCase.Narrative = "Begin AdminOrganizationsTest";
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
                "Admin tests that change organizations run only against the dev API " + ...
                "(or with NDI_CLOUD_ALLOW_ADMIN_WRITE_TESTS=true). Skipping.");
        end

        function orgID = scratchOrganization(testCase)
            % Return the id of the scratch organization, finding or creating it once.
            if strlength(testCase.ScratchOrganizationID) > 0
                orgID = testCase.ScratchOrganizationID;
                return
            end

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

            % Never add the account to, or remove it from, an organization
            % it really belongs to.
            testCase.assertFalse(ismember(orgID, testCase.MyOrganizationIDs), ...
                "The scratch organization " + orgID + " is one the test account " + ...
                "already belongs to. Point NDI_CLOUD_TEST_ADMIN_ORGANIZATION_ID at a " + ...
                "dedicated organization.");
            testCase.ScratchOrganizationID = orgID;
        end
    end

    methods (Test)
        % ------------------------------------------------------------------
        % Any account can list its own organizations.
        function testOwnOrganizationsWithoutAdmin(testCase)
            narrative = testCase.Narrative;
            narrative(end+1) = "Calling getUserOrganizations with no input.";
            [b, r, resp, url] = ndi.cloud.api.admin.getUserOrganizations();
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(string(r.userID), testCase.MyID, msg);
            testCase.verifyEqual(sort(ndi.unittest.cloud.AdminOrganizationsTest.idRow(r.organizationID)), ...
                sort(testCase.MyOrganizationIDs), msg);
            testCase.verifyEqual(numel(r.organizationName), numel(r.organizationID), msg);
        end

        % ------------------------------------------------------------------
        % An account without administrator rights is refused by every
        % admin endpoint.
        function testNonAdminIsForbidden(testCase)
            testCase.assumeFalse(testCase.IsAdmin, ...
                "The test account is an administrator. Skipping the non-admin test.");
            narrative = testCase.Narrative;

            calls = {
                "listOrganizations",     @() ndi.cloud.api.admin.listOrganizations()
                "listUsers",             @() ndi.cloud.api.admin.listUsers()
                "getUser",               @() ndi.cloud.api.admin.getUser(testCase.MyID)
                "getOrganization",       @() ndi.cloud.api.admin.getOrganization(testCase.NonexistentID)
                "addOrganizationMember", @() ndi.cloud.api.admin.addOrganizationMember( ...
                                                 testCase.NonexistentID, testCase.MyID)
                "removeOrganizationMember", @() ndi.cloud.api.admin.removeOrganizationMember( ...
                                                 testCase.NonexistentID, testCase.MyID)
                };
            for i = 1:size(calls, 1)
                narrative(end+1) = "Calling " + calls{i,1} + " without admin rights; expecting 403."; %#ok<AGROW>
                [b, answer, resp, url] = calls{i,2}();
                msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
                testCase.verifyFalse(b, msg);
                testCase.verifyEqual(double(resp.StatusCode), 403, msg);
            end

            narrative(end+1) = "Calling addOrganizationMemberByEmail; expecting the lookup to fail.";
            [b, answer, resp, url] = ndi.cloud.api.admin.addOrganizationMemberByEmail( ...
                testCase.NonexistentID, testCase.MyEmail);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 403, msg);
        end

        % ------------------------------------------------------------------
        function testListOrganizations(testCase)
            testCase.assumeAdmin();
            narrative = testCase.Narrative;
            narrative(end+1) = "Calling listOrganizations with pageSize 2.";
            [b, r, resp, url] = ndi.cloud.api.admin.listOrganizations('pageSize', 2);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 200, msg);
            for f = ["organizations", "page", "limit", "total", "totalPages"]
                testCase.verifyTrue(isfield(r, f), msg);
            end
            orgs = ndi.cloud.api.implementation.admin.asStructCell(r.organizations);
            testCase.verifyLessThanOrEqual(numel(orgs), 2, msg);
            testCase.verifyGreaterThanOrEqual(r.total, numel(orgs), msg);
            testCase.verifyEqual(r.limit, 2, msg);
        end

        % ------------------------------------------------------------------
        function testListUsersAndFindUserByEmail(testCase)
            testCase.assumeAdmin();
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling listUsers with the test account's email.";
            [b, r, resp, url] = ndi.cloud.api.admin.listUsers('query', testCase.MyEmail);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.assertTrue(b, msg);
            users = ndi.cloud.api.implementation.admin.asStructCell(r.users);
            ids = cellfun(@(u) string(u.id), users, 'UniformOutput', false);
            testCase.verifyTrue(ismember(testCase.MyID, [ids{:}]), msg);

            narrative(end+1) = "Calling findUserByEmail with the email in upper case.";
            [b, u, resp, url] = ndi.cloud.api.admin.findUserByEmail(upper(testCase.MyEmail));
            msg = ndi.unittest.cloud.APIMessage(narrative, b, u, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyClass(u.id, 'char', msg);
            testCase.verifyEqual(string(u.id), testCase.MyID, msg);

            narrative(end+1) = "Calling findUserByEmail with an address no account has.";
            noSuchEmail = "no-such-user-" + string(char(java.util.UUID.randomUUID().toString())) + "@example.invalid";
            [b, u, resp, url] = ndi.cloud.api.admin.findUserByEmail(noSuchEmail);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, u, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyTrue(isfield(u, 'error'), msg);
        end

        % ------------------------------------------------------------------
        function testGetUserOrganizations(testCase)
            testCase.assumeAdmin();
            narrative = testCase.Narrative;
            expected = sort(testCase.MyOrganizationIDs);

            narrative(end+1) = "Calling getUser with the test account's id.";
            [b, u, resp, url] = ndi.cloud.api.admin.getUser(testCase.MyID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, u, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(string(u.email), testCase.MyEmail, msg);
            testCase.verifyEqual(sort(ndi.unittest.cloud.AdminOrganizationsTest.idRow(u.organizationID)), expected, msg);

            for who = [testCase.MyID, testCase.MyEmail]
                narrative(end+1) = "Calling getUserOrganizations(""" + who + """)."; %#ok<AGROW>
                [b, r, resp, url] = ndi.cloud.api.admin.getUserOrganizations(who);
                msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
                testCase.assertTrue(b, msg);
                testCase.verifyEqual(string(r.userID), testCase.MyID, msg);
                testCase.verifyEqual(sort(ndi.unittest.cloud.AdminOrganizationsTest.idRow(r.organizationID)), expected, msg);
            end
        end

        % ------------------------------------------------------------------
        function testInvalidIDs(testCase)
            testCase.assumeAdmin();
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling getOrganization with a malformed id; expecting 400.";
            [b, r, resp, url] = ndi.cloud.api.admin.getOrganization("not-an-id");
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);

            narrative(end+1) = "Calling getOrganization with an unknown id; expecting 404.";
            [b, r, resp, url] = ndi.cloud.api.admin.getOrganization(testCase.NonexistentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, msg);

            narrative(end+1) = "Calling addOrganizationMember with an unknown user; expecting 404.";
            [b, r, resp, url] = ndi.cloud.api.admin.addOrganizationMember( ...
                testCase.NonexistentID, testCase.NonexistentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, msg);
        end

        % ------------------------------------------------------------------
        % Add the test account to the scratch organization by email, check
        % it shows up from both sides, then remove it again.
        function testAddAndRemoveMemberByEmail(testCase)
            testCase.assumeWriteAllowed();
            orgID = testCase.scratchOrganization();
            narrative = testCase.Narrative;
            testCase.addTeardown(@() ndi.cloud.api.admin.removeOrganizationMember(orgID, testCase.MyID));

            narrative(end+1) = "Making sure the test account is not in the scratch organization.";
            [b, org, resp, url] = ndi.cloud.api.admin.removeOrganizationMember(orgID, testCase.MyID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, org, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyFalse(ismember(testCase.MyID, string(org.memberID)), msg);
            countBefore = org.memberCount;

            narrative(end+1) = "Adding the test account by email.";
            [b, org, resp, url] = ndi.cloud.api.admin.addOrganizationMemberByEmail(orgID, testCase.MyEmail);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, org, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyTrue(ismember(testCase.MyID, string(org.memberID)), msg);
            testCase.verifyEqual(org.memberCount, countBefore + 1, msg);

            narrative(end+1) = "Adding the test account again; expecting no change.";
            [b, org, resp, url] = ndi.cloud.api.admin.addOrganizationMember(orgID, testCase.MyID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, org, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(org.memberCount, countBefore + 1, msg);

            narrative(end+1) = "Checking the membership from the user's side.";
            [b, r, resp, url] = ndi.cloud.api.admin.getUserOrganizations(testCase.MyID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyTrue(ismember(orgID, string(r.organizationID)), msg);

            narrative(end+1) = "Removing the test account by email.";
            [b, org, resp, url] = ndi.cloud.api.admin.removeOrganizationMemberByEmail(orgID, testCase.MyEmail);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, org, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyFalse(ismember(testCase.MyID, string(org.memberID)), msg);
            testCase.verifyEqual(org.memberCount, countBefore, msg);

            narrative(end+1) = "Checking the user's side again.";
            [b, r, resp, url] = ndi.cloud.api.admin.getUserOrganizations(testCase.MyEmail);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, r, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyFalse(ismember(orgID, string(r.organizationID)), msg);
        end

        % ------------------------------------------------------------------
        % Write back the scratch organization's own values: exercises PATCH
        % without changing anything.
        function testUpdateOrganization(testCase)
            testCase.assumeWriteAllowed();
            orgID = testCase.scratchOrganization();
            narrative = testCase.Narrative;

            narrative(end+1) = "Fetching the scratch organization.";
            [b, org, resp, url] = ndi.cloud.api.admin.getOrganization(orgID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, org, resp, url);
            testCase.assertTrue(b, msg);

            narrative(end+1) = "Writing back its name and canUploadDataset.";
            [b, updated, resp, url] = ndi.cloud.api.admin.updateOrganization(orgID, ...
                'name', string(org.name), 'canUploadDataset', logical(org.canUploadDataset));
            msg = ndi.unittest.cloud.APIMessage(narrative, b, updated, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(string(updated.name), string(org.name), msg);
            testCase.verifyEqual(logical(updated.canUploadDataset), logical(org.canUploadDataset), msg);

            narrative(end+1) = "Calling updateOrganization with no fields; expecting an error.";
            testCase.verifyError(@() ndi.cloud.api.admin.updateOrganization(orgID), ...
                'NDI:Cloud:Admin:NoUpdates');
        end
    end
end
