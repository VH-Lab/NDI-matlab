function testCloudApiProdPart(partIdx, numParts)
%testCloudApiProdPart Run a partition of the cloud tests against prod.
%
%   Forces CLOUD_API_ENVIRONMENT=prod and runs partition PARTIDX of NUMPARTS
%   over the ndi.unittest.cloud package. Used by the parallel "Cloud CI"
%   workflows so the cloud suite can be sharded across multiple runners.

    setenv("CLOUD_API_ENVIRONMENT", "prod")
    testCloudApiPart(partIdx, numParts)
end
