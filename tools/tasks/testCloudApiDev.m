function testCloudApiDev(varargin)
%testCloudApiDev Run the cloud tests against the dev environment.
%
%   This forces CLOUD_API_ENVIRONMENT=dev and runs every test in
%   tests/+ndi/+unittest/+cloud, against https://dev-api.ndi-cloud.com/v1.
%   The sibling of testCloudApiProd, for the case where an API change is
%   deployed to dev and not yet to prod.
%
%   The scheduled "Test NDI Cloud Api" workflow already covers both
%   environments as a matrix. This exists for running dev by hand, locally
%   or with workflow_dispatch, without editing an environment variable and
%   remembering to put it back.
%
%   See also: testCloudApiProd, testFileSeriesCloud, ndi.cloud.api.url

    setenv("CLOUD_API_ENVIRONMENT", "dev")
    testCloudApi(varargin{:})
end
