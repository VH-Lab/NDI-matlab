function release = latestRelease(options)
% LATESTRELEASE - the latest published NDI-matlab release on GitHub
%
%   RELEASE = ndi.update.latestRelease()
%
%   Asks the GitHub Releases API for the latest (non-draft, non-prerelease)
%   release and returns a structure with fields:
%       Version     - version number without the leading 'v' (e.g. "1.2.0")
%       Tag         - the release tag (e.g. "v1.2.0")
%       Url         - web page of the release
%       Notes       - release notes (markdown)
%       PublishedAt - publication time as reported by GitHub
%       MltbxName   - file name of the attached toolbox, or "" if none
%       MltbxUrl    - download URL of the attached toolbox, or "" if none
%
%   RELEASE = ndi.update.latestRelease(Name, Value) accepts:
%       Repository - "owner/name" on GitHub (default "VH-Lab/NDI-matlab")
%       Timeout    - seconds to wait for GitHub (default 10)
%
%   If the environment variable GITHUB_TOKEN is set, it is sent with the
%   request, which raises GitHub's limit of 60 unauthenticated requests per
%   hour.

    arguments
        options.Repository (1,1) string = "VH-Lab/NDI-matlab"
        options.Timeout (1,1) double {mustBePositive} = 10
    end

    headers = {'Accept', 'application/vnd.github+json'};
    token = getenv('GITHUB_TOKEN');
    if ~isempty(token)
        headers(end+1, :) = {'Authorization', ['Bearer ' token]};
    end
    opts = weboptions('ContentType', 'json', 'Timeout', options.Timeout, ...
        'HeaderFields', headers);

    url = "https://api.github.com/repos/" + options.Repository + "/releases/latest";
    r = webread(url, opts);

    release.Tag = string(r.tag_name);
    release.Version = regexprep(release.Tag, '^[vV]', '');
    release.Url = string(r.html_url);
    release.Notes = "";
    if isfield(r, 'body') && ~isempty(r.body)
        release.Notes = string(r.body);
    end
    release.PublishedAt = "";
    if isfield(r, 'published_at') && ~isempty(r.published_at)
        release.PublishedAt = string(r.published_at);
    end
    release.MltbxName = "";
    release.MltbxUrl = "";
    if isfield(r, 'assets') && ~isempty(r.assets)
        assets = r.assets;
        if iscell(assets)
            assets = [assets{:}];
        end
        for i = 1:numel(assets)
            if endsWith(string(assets(i).name), ".mltbx", 'IgnoreCase', true)
                release.MltbxName = string(assets(i).name);
                release.MltbxUrl = string(assets(i).browser_download_url);
                break
            end
        end
    end
end
