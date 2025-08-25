function [response, summary] = list_dataset_documents(dataset_id, options)
    % LIST_DATASET_DOCUMENTS - Get a list of summaries for all documents of a dataset.
    %
    % [RESPONSE, SUMMARY] = ndi.cloud.api.documents.list_dataset_documents(DATASET_ID, options)
    %
    % Inputs:
    %   DATASET_ID - (1,1) string
    %                A string representing the dataset id.
    %   options.page - (1,1) double
    %                  The page number of results to retrieve. Defaults to 1.
    %   options.pageSize - (1,1) double
    %                      The number of results to retrieve per page.
    %                      Defaults to 1000.
    %
    % Outputs:
    %   RESPONSE - The full HTTP response object.
    %   SUMMARY  - A list of document summaries from the dataset.
    %
    
    arguments
        dataset_id (1,1) string
        options.page (1,1) double = 1
        options.pageSize (1,1) double = 1000
    end

    auth_token = ndi.cloud.authenticate();

    % Build name-value pairs for the URL function
    url_options = {'page', options.page, 'page_size', options.pageSize};

    url = ndi.cloud.api.url('list_dataset_documents', 'dataset_id', dataset_id, url_options{:});

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

