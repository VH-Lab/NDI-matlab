function [response, datasets] = list_datasets(organization_id)
    % LIST_DATASETS - Get a list of all datasets in an organization
    %
    % [RESPONSE, DATASETS] = ndi.cloud.api.datasets.LIST_DATASETS()
    %
    % Outputs:
    %   RESPONSE - the get request summary
    %   DATASETS - A high level summary of all datasets in the organization

    arguments
        organization_id (1,1) string = missing
    end

    auth_token = ndi.cloud.authenticate();
    if ismissing(organization_id)
        organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    end

    url = ndi.cloud.api.url('list_datasets', 'organization_id', organization_id);
    method = matlab.net.http.RequestMethod.GET;
    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];
    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);

    if (response.StatusCode == 200)
        % Request succeeded
        datasets = response.Body.Data.datasets;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end
