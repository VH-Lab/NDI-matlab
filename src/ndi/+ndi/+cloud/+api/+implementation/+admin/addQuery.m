function apiURL = addQuery(apiURL, query, page, pageSize)
%ADDQUERY Append the search and paging query of an admin list endpoint.
%
%   APIURL = ndi.cloud.api.implementation.admin.addQuery(APIURL, QUERY, PAGE, PAGESIZE)
%
%   The admin list endpoints take q (case-insensitive substring search),
%   page (1-based) and limit (1-100). q is sent only when QUERY is not
%   empty. PAGESIZE is sent as the server's 'limit' parameter.

    arguments
        apiURL (1,1) matlab.net.URI
        query (1,1) string
        page (1,1) double
        pageSize (1,1) double
    end

    q = [matlab.net.QueryParameter('page', sprintf('%d', page)) ...
        matlab.net.QueryParameter('limit', sprintf('%d', pageSize))];
    if strlength(query) > 0
        q = [matlab.net.QueryParameter('q', char(query)) q];
    end
    if isempty(apiURL.Query)
        apiURL.Query = q;
    else
        apiURL.Query = [apiURL.Query q];
    end
end
