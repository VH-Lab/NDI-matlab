function c = compareVersions(a, b)
% COMPAREVERSIONS - compare two major.minor.patch version strings
%
%   C = ndi.update.compareVersions(A, B)
%
%   Returns -1 if A is older than B, 0 if they are the same, and 1 if A is
%   newer than B. A leading 'v' (as in a git tag 'v1.2.3') is ignored, as is
%   any pre-release or build suffix ('1.2.3-beta', '1.2.3+abc'). Missing
%   components count as 0, so '1.2' equals '1.2.0'.
%
%   Example:
%       ndi.update.compareVersions("v1.1.2", "1.2.0")   % returns -1

    arguments
        a (1,1) string
        b (1,1) string
    end

    na = versionParts(a);
    nb = versionParts(b);
    n = max(numel(na), numel(nb));
    na(end+1:n) = 0;
    nb(end+1:n) = 0;

    c = 0;
    for i = 1:n
        if na(i) < nb(i)
            c = -1;
            return
        elseif na(i) > nb(i)
            c = 1;
            return
        end
    end
end

function parts = versionParts(s)
    s = strtrim(s);
    if startsWith(s, ["v", "V"])
        s = extractAfter(s, 1);
    end
    s = regexprep(s, '[-+].*$', '');
    pieces = split(s, ".");
    parts = str2double(pieces)';
    if isempty(parts) || any(isnan(parts))
        error('ndi:update:compareVersions:badVersion', ...
            'Cannot read a version number from "%s".', s);
    end
end
