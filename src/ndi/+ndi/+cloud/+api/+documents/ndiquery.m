function [b, answer, apiResponse, apiURL] = ndiquery(scope, query_obj, args)
%NDIQUERY User-facing wrapper to execute an NDI query.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.ndiquery(SCOPE, QUERY_OBJ, 'page', P, 'pageSize', PS)
%
%   Executes an NDI query against the cloud database.
%
%   Inputs:
%       scope       - The scope of the search ('public', 'private', 'all').
%       query_obj   - An ndi.query object defining the search criteria.
%   Name-Value Inputs:
%       page        - (Optional) The page number of results. Default is 1.
%       pageSize    - (Optional) The number of results per page. Default is 20.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct array of document summaries on success.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       q = ndi.query('base.name', 'exact_string', 'My Document');
%       [success, docs] = ndi.cloud.api.documents.ndiquery('private', q);
%
%   See also: ndi.cloud.api.implementation.documents.NdiQuery, ndi.query

    arguments
        scope (1,1) string {mustBeMember(scope, ["public", "private", "all"])}
        query_obj (1,1) ndi.query
        args.page (1,1) double = 1
        args.pageSize (1,1) double = 20
    end

    % Extract the search structure from the query object
    searchstructure = query_obj.searchstructure;

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.NdiQuery(...
        'scope', scope, ...
        'searchstructure', searchstructure, ...
        'page', args.page, ...
        'pageSize', args.pageSize);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
