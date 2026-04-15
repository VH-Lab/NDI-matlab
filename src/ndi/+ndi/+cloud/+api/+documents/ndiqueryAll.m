function [b, answer, apiResponse, apiURL] = ndiqueryAll(scope, query_obj, args)
%NDIQUERYALL User-facing wrapper to execute an NDI query repeatedly to obtain all matches.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.ndiqueryAll(SCOPE, QUERY_OBJ, 'pageSize', PS)
%
%   Executes an NDI query repeatedly, paginating through results to return all matching documents.
%
%   Inputs:
%       scope       - The scope of the search. One of 'public', 'private',
%                     'all', or a comma-separated list of 24-character hex
%                     dataset ObjectIds.
%       query_obj   - An ndi.query or did.query object defining the search criteria.
%   Name-Value Inputs:
%       pageSize    - (Optional) The number of results per page. Default is 1000.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct array of all matching document summaries on success.
%       apiResponse  - An array of matlab.net.http.ResponseMessage objects from all page calls.
%       apiURL       - An array of URLs that were called.
%
%   Example:
%       q = ndi.query('base.name', 'contains_string', 'Data');
%       [success, all_docs] = ndi.cloud.api.documents.ndiqueryAll('private', q);
%
%   See also: ndi.cloud.api.documents.ndiquery, ndi.query

    arguments
        scope (1,1) string {iMustBeValidScope}
        query_obj (1,1) did.query
        args.pageSize (1,1) double = 1000
    end

    % Extract the search structure from the query object
    searchstructure = query_obj.searchstructure;

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.NdiQueryAll(...
        'scope', scope, ...
        'searchstructure', searchstructure, ...
        'pageSize', args.pageSize);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end

function iMustBeValidScope(scope)
    % Accepts 'public', 'private', 'all', or a comma-separated list of
    % 24-character hex dataset ObjectIds.
    s = string(scope);
    if any(strcmp(s, ["public", "private", "all"]))
        return;
    end
    parts = strtrim(split(s, ","));
    parts(parts == "") = [];
    if isempty(parts)
        error("ndiqueryAll:InvalidScope", ...
            "scope must be 'public', 'private', 'all', or a comma-separated list of 24-character hex dataset IDs");
    end
    for i = 1:numel(parts)
        if isempty(regexp(parts(i), '^[a-fA-F0-9]{24}$', 'once'))
            error("ndiqueryAll:InvalidScope", ...
                "scope entry '%s' is not a valid 24-character hex dataset ID", parts(i));
        end
    end
end
