function [status, response, url] = get_files(dataset_id, uid)
% GET_FILES - get an upload URL for an artifact file that will be published
% to the NDI Cloud
% Same functionality as ndi.cloud.api.files.GET_FILES
%
% [STATUS,RESPONSE,URL] = ndi.cloud.api.datasets.GET_FILES(DATASET_ID, UID)
%
% Inputs:
%   DATASET_ID - a string representing the id of the dataset
%   UID - a string representing a unique identifier that can be used to
%   reference the file in documents
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the get request summary
%   URL - the upload URL to PUT the file to
%

[auth_token, ~] = ndi.cloud.uilogin();

url = matlab.net.URI(ndi.cloud.api.url('get_files', 'dataset_id', dataset_id, 'uid', uid));

method = matlab.net.http.RequestMethod.GET;

acceptField = matlab.net.http.HeaderField('accept','application/json');
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField authorizationField];

request = matlab.net.http.RequestMessage(method, headers);
response = send(request, url);
status = 1;
if (response.StatusCode == 200)
    status = 0;
    url = response.Body.Data.url;
else
    error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
end
end
