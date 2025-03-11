function [status, response, datasets] = get_unpublished(page, page_size)
    % GET_UNPUBLISHED - get all submitted but unpublished datasets
    %
    % [STATUS,RESPONSE] = ndi.cloud.api.datasets.GET_UNPUBLISHED(PAGE, PAGE_SIZE)
    %
    % Inputs:
    %   PAGE - an integer representing the page of result to get
    %   DATASET - an integer representing the number of results per page
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the updated dataset summary
    %   DATASETS - a high level summary of all unpublished datasets

    auth_token = ndi.cloud.authenticate();

    page = int2str(page);
    page_size = int2str(page_size);
    url = matlab.net.URI(ndi.cloud.api.url('get_unpublished', 'page', page, 'page_size', page_size));

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
