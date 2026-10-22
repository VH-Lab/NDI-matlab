function [filePath, status] = v1AttachedFile(v1Body, name, ndiDir)
%V1ATTACHEDFILE Where the bytes of a v1 document's attached file are, on this computer.
%
%   [FILEPATH, STATUS] = ndi.migrate.internal.v1AttachedFile(V1BODY, NAME, NDIDIR)
%   finds the file NAME that the v1 document body V1BODY (a decoded struct)
%   lists in `files.file_info`, for a session whose .ndi directory is NDIDIR.
%   FILEPATH is '' when the bytes are not here; STATUS says which case held:
%
%     'store'                 <NDIDIR>/files/<uid>: where the legacy backend
%                             (did.implementations.sqlitedb) copied the bytes
%                             when the document was added, and where
%                             did2.database.sqlitedb keeps them too
%     'source'                not in the store, but at the location the
%                             document records (a 'file' location)
%     'not on this computer'  listed, but in neither place (a document-only
%                             corpus, or a session copied without files/)
%     'not declared'          the document lists no file NAME
%
%   The same lookup, in the same order, as
%   ndi.migrate.internal.settleIngestedFiles, which later points the migrated
%   document's locations at those bytes. A uid that is not a plain file name
%   (did.file.isSafeUid) is never joined onto a path.
%
%   See also ndi.migrate.internal.settleIngestedFiles,
%            ndi.migrate.internal.stimulusPresentationToItem.

arguments
    v1Body
    name (1,:) char
    ndiDir (1,:) char
end

filePath = '';
status = 'not declared';
if ~isstruct(v1Body) || ~isscalar(v1Body) || ~isfield(v1Body, 'files') ...
        || ~isstruct(v1Body.files) || ~isscalar(v1Body.files)
    return;
end
infos = {};
if isfield(v1Body.files, 'file_info')
    infos = asCell(v1Body.files.file_info);
end
listed = false;
if isfield(v1Body.files, 'file_list') && ~isempty(v1Body.files.file_list)
    listed = any(strcmp(cellstr(v1Body.files.file_list), name));
end
storeDir = fullfile(ndiDir, 'files');
for i = 1:numel(infos)
    e = infos{i};
    if ~isstruct(e) || ~isfield(e, 'name') || ~strcmp(char(e.name), name)
        continue;
    end
    listed = true;
    if ~isfield(e, 'locations')
        continue;
    end
    locs = asCell(e.locations);
    % the store first, for every location, then the recorded locations
    for j = 1:numel(locs)
        L = locs{j};
        if ~isstruct(L) || ~isfield(L, 'uid') || isempty(L.uid)
            continue;
        end
        uid = char(L.uid);
        if did.file.isSafeUid(uid) && isfile(fullfile(storeDir, uid))
            filePath = fullfile(storeDir, uid);
            status = 'store';
            return;
        end
    end
    for j = 1:numel(locs)
        L = locs{j};
        if ~isstruct(L) || ~isfield(L, 'location') || isempty(L.location)
            continue;
        end
        type = 'file';
        if isfield(L, 'location_type') && ~isempty(L.location_type)
            type = lower(strtrim(char(L.location_type)));
        end
        if strcmp(type, 'file') && isfile(char(L.location))
            filePath = char(L.location);
            status = 'source';
            return;
        end
    end
end
if listed
    status = 'not on this computer';
end
end

function c = asCell(x)
if isempty(x)
    c = {};
elseif iscell(x)
    c = reshape(x, 1, []);
else
    c = reshape(num2cell(x), 1, []);
end
end
