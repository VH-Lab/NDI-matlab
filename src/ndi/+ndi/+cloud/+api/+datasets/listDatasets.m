function [b, answer, apiResponse, apiURL] = listDatasets(options)
%LISTDATASETS User-facing wrapper to list the datasets the user can see.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.listDatasets(...)
%
%   With 'cloudOrganizationID', retrieves one page of the datasets within
%   that organization.
%
%   Without 'cloudOrganizationID', retrieves ALL datasets in ALL of the
%   organizations the current user belongs to (see
%   ndi.cloud.internal.getOrganizations). NDI Cloud only lists datasets per
%   organization, so this queries each organization in turn and fetches
%   every page; 'page' and 'pageSize' are ignored in this mode. Each
%   returned dataset is tagged with the fields 'organizationId' and
%   'organizationName' of the organization it was listed under.
%
%   Optional Inputs (Name-Value Pairs):
%       cloudOrganizationID - The ID of the organization to query. If not
%           provided, all of the user's organizations are queried.
%       page - The page number to retrieve (default 1). Only used with
%           cloudOrganizationID.
%       pageSize - The number of datasets per page (default 20). Only used
%           with cloudOrganizationID.
%
%   Outputs:
%       b            - True if the call(s) succeeded, false otherwise.
%       answer       - A structure with fields 'totalNumber', 'page', 'pageSize',
%                      and 'datasets' on success, or an error struct on failure.
%                      Across all organizations, 'datasets' is a cell array
%                      of dataset structs, 'page' is 1 and 'pageSize' and
%                      'totalNumber' are the number of datasets returned.
%       apiResponse  - The full matlab.net.http.ResponseMessage object (the
%                      last one, when several calls are made).
%       apiURL       - The URL that was called (when several calls are
%                      made, a single string listing all of them,
%                      separated by newlines).
%
%   Example:
%       % List all of my datasets, in every organization I belong to
%       [success, result] = ndi.cloud.api.datasets.listDatasets();
%       my_datasets = result.datasets;
%
%       % List datasets in one organization, with pagination
%       orgId = ndi.cloud.internal.chooseOrganization('organizationName', 'My Lab');
%       [s, res] = ndi.cloud.api.datasets.listDatasets( ...
%           'cloudOrganizationID', orgId, 'page', 2, 'pageSize', 50);
%
%   See also: ndi.cloud.api.implementation.datasets.ListDatasets,
%             ndi.cloud.internal.getOrganizations

    arguments
        options.cloudOrganizationID (1,1) string = missing
        options.page (1,1) double = 1
        options.pageSize (1,1) double = 20
    end

    if ~ismissing(options.cloudOrganizationID) && strlength(options.cloudOrganizationID) > 0
        api_call = ndi.cloud.api.implementation.datasets.ListDatasets(...
            'cloudOrganizationID', options.cloudOrganizationID, ...
            'page', options.page, ...
            'pageSize', options.pageSize);
        [b, answer, apiResponse, apiURL] = api_call.execute();
        return;
    end

    % No organization given: list every page of every organization.
    pageSize = 100;
    organizations = ndi.cloud.internal.getOrganizations();

    b = true;
    datasets = {};
    apiResponse = matlab.net.http.ResponseMessage.empty;
    urls = string.empty(1,0);

    for i = 1:numel(organizations)
        page = 1;
        fetched = 0;
        while true
            api_call = ndi.cloud.api.implementation.datasets.ListDatasets(...
                'cloudOrganizationID', organizations(i).id, ...
                'page', page, ...
                'pageSize', pageSize);
            [ok, pageAnswer, apiResponse, pageURL] = api_call.execute();
            urls(end+1) = string(pageURL); %#ok<AGROW>
            if ~ok
                b = false;
                answer = pageAnswer;
                apiURL = strjoin(urls, newline);
                return;
            end

            pageDatasets = asCell(pageAnswer.datasets);
            for k = 1:numel(pageDatasets)
                d = pageDatasets{k};
                if ~isfield(d, 'organizationId')
                    d.organizationId = organizations(i).id;
                end
                d.organizationName = organizations(i).name;
                datasets{end+1} = d; %#ok<AGROW>
            end

            fetched = fetched + numel(pageDatasets);
            total = inf;
            if isfield(pageAnswer, 'totalNumber') && ~isempty(pageAnswer.totalNumber)
                total = double(pageAnswer.totalNumber);
            end
            if isempty(pageDatasets) || numel(pageDatasets) < pageSize || fetched >= total
                break;
            end
            page = page + 1;
        end
    end

    apiURL = strjoin(urls, newline);
    answer = struct('totalNumber', numel(datasets), 'page', 1, ...
        'pageSize', numel(datasets), 'datasets', {datasets});
end

function c = asCell(datasets)
    % Normalize a struct array or cell array of dataset structs to a 1xN cell.
    if iscell(datasets)
        c = datasets(:)';
    elseif isstruct(datasets)
        c = num2cell(datasets(:)');
    else
        c = {};
    end
end
