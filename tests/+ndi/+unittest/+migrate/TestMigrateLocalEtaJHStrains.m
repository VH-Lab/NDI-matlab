classdef TestMigrateLocalEtaJHStrains < matlab.unittest.TestCase
%TESTMIGRATELOCALETAJHSTRAINS The JH corpus's strains after the whole ndi.migrate.local.
%   JH (the Haley dataset's v1 corpus, JH.zip) has no end-to-end workflow on
%   V2; this runs the strain checks Dab runs in TestMigrateLocalEtaDab on it:
%   [openMINDS minted ids are an accepted loss], [lab-made strain ids are an
%   accepted loss too] and [strain fields checked after the second pass]
%   (Jess Haley, 2026-11-19, did-schema did_v2_go_forward_class_audit.md),
%   through ndi.unittest.migrate.verifyStrainsAfterSecondPass. Gated on
%   NDI_TEST_ETA_JH (set by test-eta-migrate-jh-strains.yml) and on mksqlite.
%   The corpus readers are the ones of the strain census measurement
%   (NDI-matlab branch claude/measure-strain-census, run 44606204276).

    properties
        Bodies
        Result
    end

    methods (TestClassSetup)
        function gateAndMigrate(testCase)
            testCase.assumeFalse(isempty(getenv('NDI_TEST_ETA_JH')), ...
                'NDI_TEST_ETA_JH unset: the JH corpus run is on demand');
            testCase.assumeFalse(isempty(which('mksqlite')), 'mksqlite not on path');
            corpusDir = ensureCorpus('JH');
            testCase.Bodies = readCorpusBodies(corpusDir);
            fprintf('  [JH] read %d v1 document(s)\n', numel(testCase.Bodies));
            testCase.assertGreaterThan(numel(testCase.Bodies), 0, 'the JH corpus is empty');
            root = tempname(); mkdir(root); mkdir(fullfile(root, '.ndi'));
            buildV1Sqlite(fullfile(root, '.ndi', 'did-sqlite.sqlite'), testCase.Bodies);
            t = tic;
            testCase.Result = ndi.migrate.local(root, 'Validate', true, ...
                'TargetVersion', 'did_v2', 'Backup', false);
            fprintf('  [JH] ndi.migrate.local: %.1f s, %d quarantined\n', toc(t), ...
                numel(testCase.Result.quarantine));
            disp('  strainAssembly report:'); disp(testCase.Result.secondPass.strainAssembly);
            disp('  subjectStrainAssembly report:'); disp(testCase.Result.secondPass.subjectStrainAssembly);
        end
    end

    methods (Test)
        function testEpochInstrumentCensus(testCase)
            % Decided by Jess Haley, 2026-11-26 [instrument of an epoch
            % interaction is a link] (did-schema
            % did_v2_go_forward_class_audit.md): before it is built, count
            % the interactions that name an instrument_id and are not on an
            % epoch, and the devices it would make elements. Report-only.
            c = ndi.unittest.migrate.epochInstrumentCensus( ...
                testCase.Result.destination, 'JH');
            verifyGreaterThan(testCase, c.documents_inspected, 0, ...
                'the census read no document from the migrated database');
        end

        function testStrainsAfterTheSecondPass(testCase)
            % one strain entity per strain name per session, one instance_of
            % per subject, no openminds: id on a strain, and every v1
            % Strain's deferred fields carried by its strain entity
            ndi.unittest.migrate.verifyStrainsAfterSecondPass(testCase, ...
                testCase.Result, testCase.Bodies, ...
                destinationBodies(testCase.Result.destination), 'JH');
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

