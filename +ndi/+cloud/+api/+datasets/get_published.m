function [status, response, datasets] = get_published(page, page_size)
    % GET_PUBLISHED - get all published datasets
    %
    % [STATUS,RESPONSE,DATASETS] = ndi.cloud.api.datasets.GET_PUBLISHED(PAGE, PAGE_SIZE)
    %
    % Inputs:
    %   PAGE - an integer representing the page of result to get
    %   DATASET - an integer representing the number of results per page
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the get request summary
    %   DATASETS - a high level summary of all published datasets
    %

    arguments
        page (1,1) int32 = 1
        page_size (1,1) int32 = 20
    end

    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_published', 'page', page, 'page_size', page_size);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
        datasets = response.Body.Data;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end
