function [response] = delete_document(dataset_id, document_id)
    % DELETE_DOCUMENT - delete a document from the dataset
    %
    % [RESPONSE] = ndi.cloud.api.documents.DELETE_DOCUMENT(DATASET_ID, DOCUMENT_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   DOCUMENT_ID -  a string representing the document id
    %
    % Outputs:
    %   RESPONSE - a message saying if the document was deleted or not
    %

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.DELETE;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers);

    url = ndi.cloud.api.url('delete_document', 'dataset_id', dataset_id, 'document_id', document_id);

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
