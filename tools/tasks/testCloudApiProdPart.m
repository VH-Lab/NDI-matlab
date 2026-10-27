function testCloudApiProdPart(partIdx, numParts, varargin)
%testCloudApiProdPart Run a partition of the cloud tests against prod.
%
%   Forces CLOUD_API_ENVIRONMENT=prod and runs partition PARTIDX of NUMPARTS
%   over the ndi.unittest.cloud package. Used by the parallel "Cloud CI"
%   workflows so the cloud suite can be sharded across multiple runners.
%   Extra name-value arguments (e.g. 'CodeCoverage', true) are passed on
%   to testCloudApiPart.

    setenv("CLOUD_API_ENVIRONMENT", "prod")
    testCloudApiPart(partIdx, numParts, varargin{:})
end
