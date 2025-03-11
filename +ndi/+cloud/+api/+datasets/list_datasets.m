function [status, response, datasets] = list_datasets(organization_id)
    % LIST_DATASETS - Get a list of all datasets in an organization
    %
    % [STATUS,RESPONSE, DATASETS] = ndi.cloud.api.datasets.LIST_DATASETS()
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the get request summary
    %   DATASETS - A high level summary of all datasets in the organization

    arguments
        organization_id (1,1) string = missing
    end
        
    auth_token = ndi.cloud.authenticate();
    if ismissing(organization_id)
        organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    end

    url = matlab.net.URI(ndi.cloud.api.url('list_datasets', 'organization_id', organization_id));
    method = matlab.net.http.RequestMethod.GET;
    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];
    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
        datasets = response.Body.Data.datasets;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end
