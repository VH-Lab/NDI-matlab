function [response, summary] = list_dataset_documents(dataset_id)
    % LIST_DATASET_DOCUMENTS - Get a list of summaries for all documents of a dataset
    %
    % [RESPONSE, SUMMARY] = ndi.cloud.api.documents.LIST_DATASET_DOCUMENTS(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %
    % Outputs:
    %   RESPONSE - the get response
    %   SUMMARY - The list of documents in the dataset
    %

    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('list_dataset_documents', 'dataset_id', dataset_id);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        summary = response.Body.Data;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end
