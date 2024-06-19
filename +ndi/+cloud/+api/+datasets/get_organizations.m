function [status, response, datasets] = get_organizations(varargin)
    % GET_ORGANIZATIONS - get a high level summary of all datasets in the
    % organization
    %
    % [STATUS,RESPONSE, DATASETS] = ndi.cloud.api.datasets.GET_ORGANIZATIONS()
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the get request summary
    %   DATASETS - A high level summary of all datasets in the organization
    %
    auth_token = '';
    organization_id = '';

    if (nargin == 2) && ischar(varargin{1}) && ischar(varargin{2}),
        auth_token = varargin{1};
        organization_id = varargin{2};
    else,
        [auth_token, organization_id] = ndi.cloud.uilogin();
    end;
    url = matlab.net.URI(ndi.cloud.api.url('get_organizations', 'organization_id', organization_id));
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
    