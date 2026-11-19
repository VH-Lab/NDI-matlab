classdef TestStrainEntityCensus < matlab.unittest.TestCase
%TESTSTRAINENTITYCENSUS MEASUREMENT ONLY: strain entities per name per session
%   on a real corpus (NDI_CENSUS_CORPUS = 'Dab' or 'JH') after the whole
%   ndi.migrate.local, read back from the destination database. Asserts only
%   that something was read; prints ndi.unittest.migrate.strainEntityCensus and
%   the two strain passes' reports.

    methods (Test)
        function testCensus(testCase)
            assumeFalse(testCase, isempty(which('mksqlite')), 'mksqlite not on path');
            corpus = getenv('NDI_CENSUS_CORPUS');
            assumeFalse(testCase, isempty(corpus), 'NDI_CENSUS_CORPUS unset');
            corpusDir = ensureCorpus(corpus);
            bodies = readCorpusBodies(corpusDir);
            fprintf('  [%s] read %d v1 document(s)\n', corpus, numel(bodies));
            if strcmp(corpus, 'Dab')
                bodies = keepDabrowskaBodies(bodies);
                fprintf('  [%s] kept %d Dabrowska document(s)\n', corpus, numel(bodies));
            end
            verifyGreaterThan(testCase, numel(bodies), 0);
            root = tempname(); mkdir(root); mkdir(fullfile(root, '.ndi'));
            buildV1Sqlite(fullfile(root, '.ndi', 'did-sqlite.sqlite'), bodies);
            t = tic;
            r = ndi.migrate.local(root, 'Validate', true, 'TargetVersion', 'did_v2', 'Backup', false);
            fprintf('  [%s] ndi.migrate.local: %.1f s, %d quarantined\n', corpus, toc(t), numel(r.quarantine));
            disp('  strainAssembly report:'); disp(r.secondPass.strainAssembly);
            disp('  subjectStrainAssembly report:'); disp(r.secondPass.subjectStrainAssembly);
            dst = destinationBodies(r.destination);
            c = ndi.unittest.migrate.strainEntityCensus(dst);
            fprintf('  [%s] CENSUS: %s\n', corpus, jsonencode(c));
            verifyGreaterThan(testCase, c.documents, 0);
        end
    end
end

function corpusDir = ensureCorpus(name)
corpusURL = ['https://ndi-programming-development.s3.us-east-1.amazonaws.com/' name '.zip'];
cacheRoot = fullfile(tempdir(), ['ndi-corpus-' name]);
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, [name '.zip']);
if ~isfile(zipPath); websave(zipPath, corpusURL); end
unzip(zipPath, cacheRoot);
f = dir(fullfile(cacheRoot, '**', '*.json'));
f = f(~startsWith({f.name}, '._'));
folders = unique({f.folder});
[~, big] = max(cellfun(@(d) nnz(strcmp({f.folder}, d)), folders));
corpusDir = folders{big};
end

function bodies = readCorpusBodies(corpusDir)
%READCORPUSBODIES Every v1 document in the corpus, as JSON text.
%   `._` sidecars are macOS resource forks the zip carries; skipping them is
%   what did2.validate.sourceCensus's own reader does.
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function bodies = keepDabrowskaBodies(bodies)
%KEEPDABROWSKABODIES Drop corpus B out of Dab.zip, by session, at read time.
%   Dab.zip bundles the Dabrowska dataset with the whole of corpus B (the
%   Fitzpatrick tree-shrew dataset `2013_treeshrew_LGNctx`). Keep the documents
%   whose base.session_id is the `dabrowska_2025` dataset session or one of the
%   sessions its `session_in_a_dataset` documents list; drop the rest. Selects
%   POSITIVELY (what is Dabrowska's), so a third dataset added to the zip later
%   would be dropped rather than silently tested. Errors when the dataset
%   session is absent: a filter that keeps nothing is a defect, not a skip.
datasetRef = 'dabrowska_2025';
decoded = cell(size(bodies));
sessionOf = cell(size(bodies));
for k = 1:numel(bodies)
    j = jsondecode(bodies{k});
    decoded{k} = j;
    sessionOf{k} = '';
    if isfield(j, 'base') && isfield(j.base, 'session_id')
        sessionOf{k} = j.base.session_id;
    end
end
keep = {};
for k = 1:numel(decoded)
    j = decoded{k};
    if isfield(j, 'document_class') && strcmp(j.document_class.class_name, 'session') ...
            && isfield(j, 'session') && isfield(j.session, 'reference') ...
            && strcmp(j.session.reference, datasetRef)
        keep{end+1} = sessionOf{k}; %#ok<AGROW>
    end
end
if isempty(keep)
    error('ndi:corpus:noDabrowskaDataset', ...
        'Dab.zip holds no `session` document with reference "%s"', datasetRef);
end
for k = 1:numel(decoded)
    j = decoded{k};
    if isfield(j, 'document_class') ...
            && strcmp(j.document_class.class_name, 'session_in_a_dataset') ...
            && any(strcmp(sessionOf{k}, keep)) ...
            && isfield(j, 'session_in_a_dataset')
        keep{end+1} = j.session_in_a_dataset.session_id; %#ok<AGROW>
    end
end
keep = unique(keep);
fprintf('  Dabrowska sessions kept: %s\n', strjoin(keep, ', '));
bodies = bodies(ismember(sessionOf, keep));
end

function buildV1Sqlite(tmpFile, bodies)
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES.
%   The shape is `docs(doc_id, doc_idx, json_code, timestamp)` because that is
%   what did2.convert.readers.sqliteV1 issues (`SELECT json_code FROM docs`),
%   the same columns the real legacy backend writes.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
% BULK INSERT IN ONE TRANSACTION -- one fsync per row outside a transaction is
% pathological at scale (the Soph run #1 timeout). Throwaway fixture DB, so
% drop the per-write durability guarantees too.
mksqlite(dbid, 'PRAGMA synchronous = OFF');
mksqlite(dbid, 'PRAGMA journal_mode = MEMORY');
mksqlite(dbid, 'BEGIN TRANSACTION');
for k = 1:numel(bodies)
    docId = sprintf('id_%06d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
mksqlite(dbid, 'COMMIT');
end

function bodies = destinationBodies(dstPath)
%DESTINATIONBODIES Every document in the destination, as structs, read ONCE.
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

