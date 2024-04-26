function [b, msg, dataset, dataset_id] = submit_dataset(S, session_id, datasetInformation)
%TEST_UPLOAD - upload a test dataset to the cloud
% [B, MSG, DATASET_ID] = ndi.database.metadata_app.fun.submit_dataset(S, SESSION_ID, DATASETINFORMATION) 
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
disp('converting documents...')
documentList = ndi.database.metadata_app.convertFormDataToDocuments(datasetInformation, session_id);
disp('adding documents to database...')
S = ndi.database.metadata_app.fun.add_to_database(S, documentList);
disp('creating database in the cloud...')
[~, ~,dataset_id] = ndi.cloud.create_cloud_metadata_struct(datasetInformation);
[b, msg] = ndi.database.fun.upload_to_NDI_cloud(S, dataset_id);
[auth_token, organization_id] = ndi.cloud.uilogin();
[status,dataset] = ndi.cloud.datasets.get_datasetId(dataset_id, auth_token);
assignin('base', 'dataset', dataset)
end

