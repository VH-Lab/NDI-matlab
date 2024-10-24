function [status, response] = post_datasetId(dataset_id, dataset)
    % POST_DATASETID - update a dataset to NDI Cloud
    %
    % [STATUS,RESPONSE] = ndi.cloud.api.datasets.POST_DATASETID(DATASET_ID, DATASET)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %   DATASET - the updated version of the dataset in JSON-formatted text
    %
    % Outputs:
    %   STATUS - did the post request work? 1 for no, 0 for yes
    %   RESPONSE - the updated dataset summary
    %

    [auth_token, ~] = ndi.cloud.uilogin();

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(dataset);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = matlab.net.URI(ndi.cloud.api.url('post_datasetId', 'dataset_id', dataset_id));

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
        response = response.Body.Data;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
