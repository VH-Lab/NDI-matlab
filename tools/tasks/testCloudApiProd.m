function testCloudApiProd(varargin)
%testCloudApiProd Run the cloud tests against the prod environment.
%
%   This forces CLOUD_API_ENVIRONMENT=prod and runs every test in
%   tests/+ndi/+unittest/+cloud. It is used by the "NDI Test Suite Cloud
%   Prod" workflow so the non-cloud suite and the cloud suite can run in
%   parallel on push/PR events.

    setenv("CLOUD_API_ENVIRONMENT", "prod")
    testCloudApi(varargin{:})
end
