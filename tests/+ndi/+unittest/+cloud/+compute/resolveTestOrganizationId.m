function orgId = resolveTestOrganizationId(testCase)
%RESOLVETESTORGANIZATIONID Return the org id to bill compute test sessions to.
%
%   ORGID = ndi.unittest.cloud.compute.resolveTestOrganizationId(TESTCASE)
%
%   Resolution order:
%     1. NDI_CLOUD_TEST_ORGANIZATION_ID env var, if non-empty. Lets CI pin
%        a specific org or a developer force a non-default one.
%     2. ndi.cloud.api.users.me().organizationID{1} -- the same org
%        ndi.cloud.authenticate already picks silently. Works for
%        single-org accounts (the sole org) and multi-org accounts (the
%        first, matching authenticate's behaviour) with no manual setup.
%
%   On single-org auto-tester accounts step 1 is empty and step 2 always
%   returns that one org, so nothing needs configuring; multi-org
%   developers likewise get a usable id from step 2 and can override with
%   the env var if they need a different one.
%
%   TESTCASE is passed so a lookup failure records a diagnostic via
%   verifyFail rather than throwing an opaque error out of TestClassSetup.

    orgId = string(getenv("NDI_CLOUD_TEST_ORGANIZATION_ID"));
    if strlength(orgId) > 0
        return
    end

    [ok, me] = ndi.cloud.api.users.me();
    if ~ok
        testCase.verifyFail(...
            "Could not fetch the current user via ndi.cloud.api.users.me " + ...
            "to auto-resolve NDI_CLOUD_TEST_ORGANIZATION_ID. Set the env " + ...
            "var explicitly to skip this lookup.");
        orgId = "";
        return
    end

    if isfield(me, 'organizationID') && ~isempty(me.organizationID)
        orgId = string(me.organizationID{1});
    else
        orgId = "";
    end
end
