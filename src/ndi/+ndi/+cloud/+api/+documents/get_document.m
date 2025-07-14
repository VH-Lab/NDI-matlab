function [response, document] = get_document(dataset_id, document_id)
    % GET_DOCUMENT - get a document
    %
    % [RESPONSE,DOCUMENT] = ndi.cloud.api.documents.GET_DOCUMENT(DATASET_ID, DOCUMENT_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   DOCUMENT_ID -  a string representing the document id
    %
    % Outputs:
    %   RESPONSE - the updated dataset summary
    %   DOCUMENT - A document object required by the user
    %

    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_document', 'dataset_id', dataset_id, 'document_id', document_id);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        document = response.Body.Data;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end
