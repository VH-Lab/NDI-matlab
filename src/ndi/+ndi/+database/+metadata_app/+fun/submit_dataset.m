function [b, status, dataset, dataset_id] = submit_dataset(S, session_id, datasetInformation)
    %SUBMIT_DATASET - upload a test dataset to the cloud
    % [B, MSG, DATASET_ID] = ndi.database.metadata_app.fun.submit_dataset(S, TEST_NAME)
    %
    % inputs:
    %   S - ndi.session or ndi.dataset object
    %   session_id - the session id of the incoming session or dataset
    %   datasetInformation - metadata collected using the metadata app
    %
    % outputs:
    %   B - 1 if the upload was successful, 0 if not
    %   MSG - a message about the upload
    %   DATASET - the newly created dataset
    %   DATASET_ID - the dataset id of the uploaded dataset

    % Deprecated and unreachable: this errors rather than uploading, and
    % nothing calls it. Its body used to run ndi.cloud.upload.uploadToNDICloud,
    % which has been retired (NDI-matlab#964); that dead code is removed here
    % rather than left to imply a working path.
    error('ndi.database.metadata_app.fun.submit_dataset is deprecated. Use ndi.cloud.uploadDataset instead')
end
