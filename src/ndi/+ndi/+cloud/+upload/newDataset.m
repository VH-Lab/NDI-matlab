function datasetId = newDataset(D)
    % NEWDATASET - upload a new dataset to NDI cloud
    %
    % DATASETID = ndi.cloud.upload.NEWDATASET(D)
    %
    % Upload an ndi.dataset object to NDI Cloud. The DATASETID on
    % NDI Cloud is returned.
    %
    % This is a thin wrapper around ndi.cloud.uploadDataset, which creates the
    % remote dataset record from the dataset's own metadata when the dataset
    % has no remote yet, and then uploads its documents and their files.
    %
    % PREFER ndi.cloud.uploadDataset DIRECTLY. It reports success and a
    % message rather than raising, accepts sync options, and can re-upload an
    % existing dataset as new. This wrapper exists so that code and
    % documentation naming ndi.cloud.upload.newDataset keeps working.
    %
    % Example:
    %   ndi.cloud.upload.newDataset(D)
    %
    % See also: ndi.cloud.uploadDataset

    arguments
        D (1,1) {mustBeA(D,'ndi.dataset')}
    end

    [success, datasetId, message] = ndi.cloud.uploadDataset(D);

    if ~success
        error('NDI:Cloud:Upload:NewDatasetFailed', ...
            'Failed to upload the new dataset: %s', message);
    end
end
