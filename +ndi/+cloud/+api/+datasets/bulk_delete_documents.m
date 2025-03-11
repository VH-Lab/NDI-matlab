function [status, response] = bulk_delete_documents(dataset_id,document_ids)
    %BULK_DELETE_DOCUMENTS - Delete a set of documents from the dataset
    %
    % [STATUS, RESPONSE] = ndi.cloud.api.datasets.BULK_DELETE_DOCUMENTS(DATASET_ID, DOCUMENT_IDS)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %   DOCUMENT_IDS - a cell array of document ids to delete
    %
    % Outputs:
    %   STATUS - did the post request work? 1 for no, 0 for yes
    %   response - the post request response

    auth_token = ndi.cloud.authenticate();
    json = struct();
    json.documentIds = document_ids;

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = matlab.net.URI(ndi.cloud.api.url('bulk_delete_documents', 'dataset_id', dataset_id));

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
