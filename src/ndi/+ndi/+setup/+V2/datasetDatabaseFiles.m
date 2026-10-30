function [files, folders, problems] = datasetDatabaseFiles(path)
%DATASETDATABASEFILES The V2 database files of a dataset: its own, then its linked sessions'.
%
%   [FILES, FOLDERS, PROBLEMS] = ndi.setup.V2.datasetDatabaseFiles(PATH) reads
%   the V2 dataset at PATH (the folder holding .ndi) and returns, as cellstrs:
%
%     FILES     the dataset's own database file, then that of each LINKED
%               session (the Pathname of its "database linking" relation
%               names its folder, ndi.v2.sessionLinkOf: Jess Haley 2026-10-29
%               [linked session link details]; in a dataset written before
%               that relation, a `linked_session` document names it)
%     FOLDERS   the folder each file's documents are in (PATH first)
%     PROBLEMS  each linked session whose folder holds no V2 database
%
%   For tools that read a dataset's documents directly (a census, an edge
%   check, a term inventory): an INGESTED session is in the first file; a
%   linked one in its own. It reads the database files and opens no session.
%
%   See also ndi.v2.datasetSessions, ndi.setup.conv.haley.verifyDataset.

arguments
    path (1,:) char {mustBeFolder}
end
name = ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME();
own = fullfile(path, '.ndi', name);
if ~isfile(own)
    error('ndi:setup:V2:noDataset', 'No V2 database at %s.', own);
end
files = {own};
folders = {path};
problems = {};
db = did2.database.sqlitedb(own);
closer = onCleanup(@() db.close());
% the folders: each "database linking" relation's Pathname, then each
% (older) linked_session document's path, each folder once
links = {};
rows = mksqlite(db.testHookDbId(), ...
    'SELECT body FROM documents WHERE classname = ''directed_relation'' ORDER BY id');
for k = 1:numel(rows)
    link = ndi.v2.sessionLinkOf(jsondecode(rows(k).body));
    if strcmp(link.kind, 'linked') && ~isempty(link.path)
        links{end+1} = link.path; %#ok<AGROW>
    end
end
rows = mksqlite(db.testHookDbId(), ...
    'SELECT body FROM documents WHERE classname = ''linked_session'' ORDER BY id');
for k = 1:numel(rows)
    p = jsondecode(rows(k).body);
    links{end+1} = char(p.linked_session.path); %#ok<AGROW>
end
seen = {};
for k = 1:numel(links)
    folder = ndi.v2.resolveLinkPath(links{k}, path);
    key = char(java.io.File(folder).getCanonicalPath());
    if ismember(key, seen)
        continue;
    end
    seen{end+1} = key; %#ok<AGROW>
    f = fullfile(folder, '.ndi', name);
    if isfile(f)
        files{end+1} = f; %#ok<AGROW>
        folders{end+1} = folder; %#ok<AGROW>
    else
        problems{end+1} = sprintf('linked session folder %s holds no V2 database', folder); %#ok<AGROW>
    end
end
end
