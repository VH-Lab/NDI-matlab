function folder = resolveLinkPath(path, datasetPath)
%RESOLVELINKPATH A linked session's folder, as an absolute path.
%
%   FOLDER = ndi.v2.resolveLinkPath(PATH, DATASETPATH): a `linked_session`
%   PATH is relative to the dataset's folder DATASETPATH when the session is
%   inside it, else absolute. Either way FOLDER is absolute. '/' and '\' are
%   both read as separators, so a dataset written on one system opens on
%   another.
%
%   See also ndi.v2.linkPath, ndi.v2.datasetSessions.

arguments
    path (1,:) char
    datasetPath (1,:) char
end
p = strrep(strrep(path, '\', filesep), '/', filesep);
if isAbsolute(p)
    folder = p;
else
    folder = fullfile(datasetPath, p);
end
end

function tf = isAbsolute(p)
tf = startsWith(p, filesep) || ~isempty(regexp(p, '^[A-Za-z]:', 'once'));
end
