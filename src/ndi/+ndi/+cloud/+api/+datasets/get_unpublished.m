function [response, datasets] = get_unpublished(page, page_size)
    % GET_UNPUBLISHED - get all submitted but unpublished datasets
    %
    % RESPONSE = ndi.cloud.api.datasets.GET_UNPUBLISHED(PAGE, PAGE_SIZE)
    %
    % Inputs:
    %   PAGE - an integer representing the page of result to get
    %   DATASET - an integer representing the number of results per page
    %
    % Outputs:
    %   RESPONSE - the updated dataset summary
    %   DATASETS - a high level summary of all unpublished datasets
    
    arguments
        page (1,1) int32 = 1
        page_size (1,1) int32 = 20
    end
    
    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_unpublished', 'page', page, 'page_size', page_size);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        datasets = response.Body.Data;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end
