function [status, response] = post_submit(dataset_id)
% POST_SUBMIT - submit a dataset for review
%
% [STATUS,RESPONSE] = ndi.cloud.api.datasets.POST_SUBMIT(DATASET_ID)
%
% Inputs:
%   DATASET_ID - an id of the dataset
%
% Outputs:
%   STATUS - did the post request work? 1 for no, 0 for yes
%   RESPONSE - the dataset was submitted
%

[auth_token, ~] = ndi.cloud.uilogin();

method = matlab.net.http.RequestMethod.POST;

body = matlab.net.http.MessageBody('');

acceptField = matlab.net.http.HeaderField('accept','application/json');
contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField contentTypeField authorizationField];

req = matlab.net.http.RequestMessage(method, headers, body);

url = matlab.net.URI(ndi.cloud.api.url('post_submit', 'dataset_id', dataset_id));

response = req.send(url);
status = 1;
if (response.StatusCode == 200)
    status = 0;
else
    error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
end
end
