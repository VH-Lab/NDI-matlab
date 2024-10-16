function [status, response, dataset_id] = post_organization(dataset)
% POST_ORGANIZATION - Create a new dataset
%
% [STATUS,RESPONSE] = ndi.cloud.api.datasets.POST_ORGANIZATION(DATASET)
%
% Inputs:
%   DATASET - a JSON object representing the dataset
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - the new dataset summary
%   DATASET_ID - the id of the newly created dataset

[auth_token, organization_id] = ndi.cloud.uilogin();

method = matlab.net.http.RequestMethod.POST;

body = matlab.net.http.MessageBody(dataset);

acceptField = matlab.net.http.HeaderField('accept','application/json');
contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField contentTypeField authorizationField];

req = matlab.net.http.RequestMessage(method, headers, body);

url = matlab.net.URI(ndi.cloud.api.url('post_organization', 'organization_id', organization_id));

response = req.send(url);
status = 1;
if (response.StatusCode == 201)
    status = 0;
    dataset_id = response.Body.Data.id;
else
    error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
end
end
