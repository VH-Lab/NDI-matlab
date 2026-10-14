function path = linkPath(folder, datasetPath)
%LINKPATH The `path` a linked_session document records for FOLDER.
%
%   PATH = ndi.v2.linkPath(FOLDER, DATASETPATH): FOLDER relative to the
%   dataset's folder DATASETPATH when FOLDER is inside it (written with '/',
%   so it reads the same on any system), else FOLDER absolute
%   (V_eta_linked_session_plan.md). A dataset moved with its sessions inside
%   it then still finds them.
%
%   See also ndi.v2.resolveLinkPath.

arguments
    folder (1,:) char
    datasetPath (1,:) char
end
f = char(java.io.File(folder).getCanonicalPath());
d = char(java.io.File(datasetPath).getCanonicalPath());
if startsWith(f, [d filesep])
    path = strrep(f(numel(d)+2:end), filesep, '/');
else
    path = f;
end
end
