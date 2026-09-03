classdef notIngestedDataset < ndi.dataset
    % notIngestedDataset - the smallest dataset that is not fully ingested.
    %
    %   A test double, not a test. It exists so
    %   ndi.unittest.dataset.uploadDatasetIngestionGate can reach the one
    %   branch of ndi.cloud.uploadDataset that refuses to upload, WITHOUT
    %   touching NDI Cloud.
    %
    %   Why a double rather than a real dataset: to take that branch, a
    %   dataset's isIngested() must be false, which for a real dataset means
    %   a session carrying a DAQ system with un-ingested epoch files. Any
    %   dataset that IS ingested runs straight on into the network, which is
    %   precisely what this branch must not do. The subject under test is the
    %   function's output contract on the refusal path, not how isIngested
    %   computes its answer -- so the answer is stubbed and the contract is
    %   tested.
    %
    %   Only isIngested is overridden, and there is no constructor: the
    %   inherited default one is enough, exactly as ndi.dataset.dir relies on
    %   the implicit superclass call. Nothing else on the object is
    %   reachable, because the refusal returns before the dataset is used
    %   for anything else.
    %
    %   This file is a plain classdef, not a matlab.unittest.TestCase, so
    %   TestSuite discovery passes over it -- the same arrangement as
    %   ndi.unittest.cloud.closeAndRemoveDir.
    %
    %   See also: ndi.unittest.dataset.uploadDatasetIngestionGate

    methods
        function b = isIngested(~)
            % ISINGESTED - always false, which is the whole point.
            b = false;
        end
    end
end
