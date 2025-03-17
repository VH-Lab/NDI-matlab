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

    documentList = ndi.database.metadata_app.convertFormDataToDocuments(datasetInformation, session_id);
    S = ndi.database.metadata_app.fun.add_to_database(S, documentList, session_id);
    [~, ~,dataset_id] = ndi.cloud.create_cloud_metadata_struct(datasetInformation);
    [b, ~] = ndi.cloud.up.upload_to_NDI_cloud(S, dataset_id);
    [status,dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
end
