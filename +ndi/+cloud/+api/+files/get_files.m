function [status, response, upload_url] = get_files(dataset_id, uid, auth_token)
% GET_FILES - get an upload URL for an artifact file that will be
% published to NDI Cloud
% Same functionality as ndi.cloud.api.datasets.GET_FILES
%
% [STATUS,RESPONSE,UPLOAD_URL] = ndi.cloud.api.files.GET_FILES(DATASET_ID, UID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   UID -  a string representing the unique identifier that can be used to
%   reference the file in document
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the upload summary
%   UPLOAD_URL - the upload URL to put the file to
%
[status, response, upload_url] = ndi.cloud.api.datasets.get_files(dataset_id, uid, auth_token);
end