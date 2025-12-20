function [b, answer, apiResponse, apiURL] = ndiqueryAll(scope, query_obj, args)
%NDIQUERYALL User-facing wrapper to execute an NDI query repeatedly to obtain all matches.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.ndiqueryAll(SCOPE, QUERY_OBJ, 'pageSize', PS)
%
%   Executes an NDI query repeatedly, paginating through results to return all matching documents.
%
%   Inputs:
%       scope       - The scope of the search ('public', 'private', 'all').
%       query_obj   - An ndi.query object defining the search criteria.
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
        scope (1,1) string {mustBeMember(scope, ["public", "private", "all"])}
        query_obj (1,1) ndi.query
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
