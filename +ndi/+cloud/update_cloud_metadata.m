function [b, msg] = update_cloud_metadata(datasetid, auth_token, S)
% UPDATE_CLOUD_METADATA - upload metadata to the NDI Cloud
%
% [B,MSG] = ndi.cloud.UPDATE_CLOUD_METADATA(DATASETID, AUTH_TOKEN, S)
%
% Inputs:
%   DATASETID - the dataset ID to update
%   AUTH_TOKEN - an upload token for NDI Cloud
%   S - an ndi.session object with the metadata to upload
%
% Outputs:
%   B - did the upload work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''
%

% loops over all the metadata fields and posts an updated value to the cloud API

d = S.database_search(ndi.query('openMinds.fields.datasetInformation.abstract','hasfield'));
clear dataset_update;

dataset_update.abstract = d{1}.document_properties.openMINDS.fields.datasetinformation.abstract;

ndi.cloud.post_datasetid(datasetid,dataset_update,auth_token);
end

