function data = githubApi(apiPath, timeout)
% GITHUBAPI - GET one GitHub REST API resource and decode its JSON
%
%   DATA = githubApi(APIPATH, TIMEOUT) requests
%   https://api.github.com/APIPATH (APIPATH may include a query string)
%   and returns the decoded JSON. If the environment variable GITHUB_TOKEN
%   is set, it is sent with the request, which raises GitHub's limit of
%   60 unauthenticated requests per hour. Errors from webread propagate.

    arguments
        apiPath (1,1) string
        timeout (1,1) double {mustBePositive} = 10
    end

    headers = {'Accept', 'application/vnd.github+json'};
    token = getenv('GITHUB_TOKEN');
    if ~isempty(token)
        headers(end+1, :) = {'Authorization', ['Bearer ' token]};
    end
    opts = weboptions('ContentType', 'json', 'Timeout', timeout, ...
        'HeaderFields', headers);
    data = webread("https://api.github.com/" + apiPath, opts);
end
