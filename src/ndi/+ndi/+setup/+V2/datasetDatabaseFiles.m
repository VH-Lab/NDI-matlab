function [files, folders, problems] = datasetDatabaseFiles(path)
%DATASETDATABASEFILES The V2 database files of a dataset: its own, then its linked sessions'.
%
%   [FILES, FOLDERS, PROBLEMS] = ndi.setup.V2.datasetDatabaseFiles(PATH) reads
%   the V2 dataset at PATH (the folder holding .ndi) and returns, as cellstrs:
%
%     FILES     the dataset's own database file, then that of each LINKED
%               session (a `linked_session` document names its folder;
%               V_eta_linked_session_plan.md)
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
rows = mksqlite(db.testHookDbId(), ...
    'SELECT body FROM documents WHERE classname = ''linked_session'' ORDER BY id');
for k = 1:numel(rows)
    p = jsondecode(rows(k).body);
    folder = ndi.v2.resolveLinkPath(char(p.linked_session.path), path);
    f = fullfile(folder, '.ndi', name);
    if isfile(f)
        files{end+1} = f; %#ok<AGROW>
        folders{end+1} = folder; %#ok<AGROW>
    else
        problems{end+1} = sprintf('linked session folder %s holds no V2 database', folder); %#ok<AGROW>
    end
end
end
