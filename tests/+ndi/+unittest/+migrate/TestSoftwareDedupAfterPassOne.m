classdef TestSoftwareDedupAfterPassOne < matlab.unittest.TestCase
%TESTSOFTWAREDEDUPAFTERPASSONE Merging software right after pass 1 leaves the
%   final document set unchanged.
%
%   Decided by Jess Haley, 2026-10-22 [software dedup after pass one]
%   (did-schema V_eta_go_forward_class_audit.md): "duplicate software,
%   operating-system and interpreter entities are merged right after the first
%   pass, not only at the end, with a test that the final document set is
%   unchanged". ndi.migrate.local now runs ndi.migrate.internal.softwareDedup
%   after pass 1 AND at the end; 'SoftwareDedupAfterPassOne', false runs the
%   end-of-run merge alone, as before. This file migrates the same v1 database
%   both ways and compares the two destinations document by document.
%
%   HOW TWO RUNS ARE COMPARED. Every id a migration MINTS (a software entity,
%   a method, an epoch, a time reference ...) is random (did.ido.unique_id:
%   time plus a random number), so two runs of the same migration never share
%   minted ids, with or without this change. Ids that come from the v1
%   documents are the same in both runs and are compared as they are. Each
%   minted id is replaced, everywhere it occurs in any document's JSON, by a
%   label for the document it names, refined over several rounds (a document's
%   label is its own JSON with its references labelled by the previous round,
%   the Weisfeiler-Lehman scheme), with one dictionary shared by the two runs.
%   The two final multisets of labelled documents must be identical: same
%   count, same v1 ids, same classes, same content, same graph. A document
%   that differs is printed with its class, so a failure says what moved.
%
%   THE FIXTURES are the e2e workflow's two corpora (test-eta-migrate-e2e.yml):
%   20211116 (stimulus responses, Hartley and tuning calculators, each
%   carrying an `app` block, so pass 1 mints many duplicate software
%   entities) and PRED (the daqreader / daqsystem / file navigator spine,
%   whose software entities keep v1 ids and are pinned by `reader_id`).
%   SKIPS, NEVER FAILS, when the environment cannot support it: no mksqlite,
%   no NDI_TEST_ETA, no DID_SCHEMA_PATH, or no corpus.

    methods (TestClassSetup)
        function gate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~etaEnabled()
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; skipping.');
            end
        end
    end

    methods (Test)
        function test20211116IsUnchangedByTheEarlyMerge(testCase)
            dir_ = corpusOrSkip(testCase, '20211116');
            compareBothWays(testCase, readCorpusBodies(dir_), '20211116');
        end

        function testPREDIsUnchangedByTheEarlyMerge(testCase)
            dir_ = corpusOrSkip(testCase, 'PRED');
            compareBothWays(testCase, readCorpusBodies(dir_), 'PRED');
        end
    end
end

% ===================== the comparison =====================================

function compareBothWays(testCase, bodies, name)
[early, rEarly] = migrateOnce(testCase, bodies, true);
[endOnly, rEnd] = migrateOnce(testCase, bodies, false);

% the early merge ran, and merged something (else this proves nothing)
e = rEarly.secondPass.softwareDedupAfterPassOne;
verifyTrue(testCase, isstruct(e), 'the merge after pass 1 did not run');
verifyEmpty(testCase, rEnd.secondPass.softwareDedupAfterPassOne, ...
    'SoftwareDedupAfterPassOne=false still ran the early merge');
fprintf(['\n  [%s] software merge after pass 1: %d documents inspected, %d software ' ...
    'seen, %d merged away; at the end: %d seen, %d merged away (end-only run: %d ' ...
    'seen, %d merged away)\n'], name, e.documents_inspected, e.software_seen, ...
    e.software_merged_away, rEarly.secondPass.softwareDedup.software_seen, ...
    rEarly.secondPass.softwareDedup.software_merged_away, ...
    rEnd.secondPass.softwareDedup.software_seen, ...
    rEnd.secondPass.softwareDedup.software_merged_away);
verifyGreaterThan(testCase, e.software_seen, 0, ...
    'no software entity after pass 1: this corpus cannot test the early merge');

% the same outcome counts
verifyEqual(testCase, numel(early), numel(endOnly), sprintf( ...
    '%s: %d documents with the early merge, %d without', name, ...
    numel(early), numel(endOnly)));
verifyEqual(testCase, numel(rEarly.quarantine), numel(rEnd.quarantine), ...
    'quarantine count differs');
verifyEqual(testCase, rEarly.references.orphan_count, rEnd.references.orphan_count, ...
    'orphan count differs');

% the same documents, with minted ids canonicalised
stable = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(bodies)
    b = jsondecode(bodies{k});
    if isfield(b, 'base') && isfield(b.base, 'id') && ~isempty(b.base.id)
        stable(char(b.base.id)) = true;
    end
end
[sigA, sigB, clsA, clsB] = canonicalPair(early, endOnly, stable, 6);
[onlyA, ia] = setdiffMulti(sigA, sigB);
[onlyB, ib] = setdiffMulti(sigB, sigA);
fprintf('  [%s] %d documents each way; %d only with the early merge, %d only without\n', ...
    name, numel(early), numel(onlyA), numel(onlyB));
for k = 1:min(5, numel(ia))
    fprintf('    only with the early merge: %s  %s\n', clsA{ia(k)}, ...
        shorten(onlyA{k}));
end
for k = 1:min(5, numel(ib))
    fprintf('    only without it:           %s  %s\n', clsB{ib(k)}, ...
        shorten(onlyB{k}));
end
if ~isempty(onlyA) || ~isempty(onlyB)
    printRootDifferences(early, endOnly, stable, name);
end
verifyEmpty(testCase, onlyA, sprintf(['%s: %d document(s) differ between the ' ...
    'early-merge and end-only migrations (listed above)'], name, numel(onlyA)));
verifyEmpty(testCase, onlyB);
end

function printRootDifferences(A, B, stable, name)
%PRINTROOTDIFFERENCES Where the two runs first part. Round 1 compares each
%   document's OWN content (every minted reference the same placeholder);
%   round r also compares what its references pointed at r-1 hops away. The
%   first round with a difference is printed: each differing document around
%   its first difference from the closest document of its class on the other
%   side, and, when that difference is a reference, the documents each side's
%   reference names (their own content).
[r1A, r1B] = canonicalPair(A, B, stable, 1);
for r = 1:6
    [sA, sB, cA, cB, labA, labB] = canonicalPair(A, B, stable, r);
    [oA, iA] = setdiffMulti(sA, sB);
    [oB, iB] = setdiffMulti(sB, sA);
    if ~isempty(oA) || ~isempty(oB)
        break;
    end
end
fprintf(['  [%s] FIRST DIFFERENCE at round %d (1 = own content, r = r-1 hops ' ...
    'of references): %d document(s) only with the early merge, %d only without\n'], ...
    name, r, numel(oA), numel(oB));
classesA = cA(iA); classesB = cB(iB);
u = unique([classesA, classesB]);
for k = 1:numel(u)
    fprintf('    %-40s early-only %d, end-only-only %d\n', u{k}, ...
        sum(strcmp(classesA, u{k})), sum(strcmp(classesB, u{k})));
end
for k = 1:min(6, numel(oA))
    pk = find(strcmp(classesB, classesA{k}));
    if isempty(pk)
        fprintf('    early-only %s (none of its class on the other side): %s\n', ...
            classesA{k}, shorten(oA{k}));
        continue;
    end
    best = 0; bestP = pk(1);
    for j = pk
        m = min(numel(oB{j}), numel(oA{k}));
        d = find(oB{j}(1:m) ~= oA{k}(1:m), 1);
        if isempty(d); d = m + 1; end
        if d > best; best = d; bestP = j; end
    end
    lo = max(1, best - 160);
    fprintf('    %s differs at char %d:\n      early:    ...%s\n      end-only: ...%s\n', ...
        classesA{k}, best, oA{k}(lo:min(end, best + 160)), ...
        oB{bestP}(lo:min(end, best + 160)));
    tA = regexp(oA{k}(best:end), '^[0-9A-Za-z_]+', 'match', 'once');
    tB = regexp(oB{bestP}(best:end), '^[0-9A-Za-z_]+', 'match', 'once');
    % the label may have started a few characters earlier ("M12" vs "M15")
    pre = regexp(oA{k}(1:best-1), '[0-9A-Za-z_]+$', 'match', 'once');
    tA = [pre tA]; tB = [pre tB];
    describeLabel('early', tA, labA, r1A, cA);
    describeLabel('end-only', tB, labB, r1B, cB);
end
end

function describeLabel(side, label, labs, own, cls)
hits = find(strcmp(labs, label));
if isempty(hits)
    return;
end
fprintf('      %s reference %s names %d document(s), e.g. %s: %s\n', side, label, ...
    numel(hits), cls{hits(1)}, shorten(own{hits(1)}));
end

function [docs, result] = migrateOnce(testCase, bodies, early)
root = tempname();
mkdir(fullfile(root, '.ndi'));
testCase.addTeardown(@() rmdirQuiet(root));
buildV1Sqlite(fullfile(root, '.ndi', 'did-sqlite.sqlite'), bodies);
result = ndi.migrate.local(root, 'Validate', true, 'TargetVersion', 'V_eta', ...
    'Backup', false, 'SoftwareDedupAfterPassOne', early);
docs = destinationBodies(result.destination);
end

function [sigA, sigB, clsA, clsB, prevA, prevB] = canonicalPair(A, B, stable, rounds)
%CANONICALPAIR Labelled JSON of every document of two runs, minted ids replaced
%   by the label of the document they name (see the class help).
[txtA, tokA, clsA, idxA, isStA, idsA] = prepare(A, stable);
[txtB, tokB, clsB, idxB, isStB, idsB] = prepare(B, stable);
labA = initialLabels(idsA, isStA);
labB = initialLabels(idsB, isStB);
sigA = {}; sigB = {};
for r = 1:rounds
    prevA = labA; prevB = labB;   % the labels the round's signatures embed
    sigA = relabel(txtA, tokA, idxA, labA, stable);
    sigB = relabel(txtB, tokB, idxB, labB, stable);
    dict = containers.Map('KeyType', 'char', 'ValueType', 'double');
    all_ = unique([sigA, sigB]);
    for k = 1:numel(all_)
        dict(all_{k}) = k;
    end
    labA = nextLabels(sigA, dict, idsA, isStA);
    labB = nextLabels(sigB, dict, idsB, isStB);
end
end

function [txt, tok, cls, idx, isStable, ids] = prepare(docs, stable)
n = numel(docs);
txt = cell(1, n); tok = cell(1, n); cls = cell(1, n); ids = cell(1, n);
for k = 1:n
    ids{k} = char(docs{k}.base.id);
    cls{k} = char(docs{k}.document_class.class_name);
    txt{k} = jsonencode(docs{k});
    [m, s, e] = regexp(txt{k}, '[0-9a-f]{16}_[0-9a-f]{16}', 'match', 'start', 'end');
    tok{k} = struct('m', {m}, 's', s, 'e', e);
end
idx = containers.Map(ids, num2cell(1:n));
isStable = cellfun(@(i) isKey(stable, i), ids);
end

function lab = initialLabels(ids, isStable)
lab = repmat({'M'}, 1, numel(ids));
lab(isStable) = ids(isStable);
end

function lab = nextLabels(sig, dict, ids, isStable)
lab = cell(1, numel(sig));
for k = 1:numel(sig)
    if isStable(k)
        lab{k} = ids{k};
    else
        lab{k} = sprintf('M%d', dict(sig{k}));
    end
end
end

function sig = relabel(txt, tok, idx, lab, stable)
sig = cell(1, numel(txt));
for k = 1:numel(txt)
    t = tok{k};
    if isempty(t.m)
        sig{k} = txt{k};
        continue;
    end
    parts = cell(1, 2 * numel(t.m) + 1);
    prev = 1;
    for j = 1:numel(t.m)
        parts{2*j-1} = txt{k}(prev:t.s(j)-1);
        id = t.m{j};
        if isKey(stable, id)
            parts{2*j} = id;
        elseif isKey(idx, id)
            parts{2*j} = lab{idx(id)};
        else
            parts{2*j} = 'DANGLING';
        end
        prev = t.e(j) + 1;
    end
    parts{end} = txt{k}(prev:end);
    sig{k} = [parts{:}];
end
end

function [only, where] = setdiffMulti(a, b)
%SETDIFFMULTI The entries of A not matched one-for-one in B (a multiset
%   difference), and their positions in A.
counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(b)
    if isKey(counts, b{k}); counts(b{k}) = counts(b{k}) + 1; else; counts(b{k}) = 1; end
end
only = {}; where = [];
for k = 1:numel(a)
    if isKey(counts, a{k}) && counts(a{k}) > 0
        counts(a{k}) = counts(a{k}) - 1;
    else
        only{end+1} = a{k}; %#ok<AGROW>
        where(end+1) = k; %#ok<AGROW>
    end
end
end

function s = shorten(s)
if numel(s) > 400
    s = [s(1:400) ' ...'];
end
end

% ===================== fixtures and readers ===============================

function d = corpusOrSkip(testCase, name)
d = '';
try
    d = ensureCorpus(name);
catch ME
    assumeFail(testCase, sprintf('could not fetch the %s corpus (%s); skipping.', ...
        name, ME.message));
end
end

function corpusDir = ensureCorpus(name)
%ENSURECORPUS Download (once) and extract <NAME>.zip, with the URL and cache
%   layout TestMigrateLocalEta20211116 / TestMigrateLocalEtaPRED use, so the
%   three tests read one copy.
corpusURL = sprintf('https://ndi-programming-development.s3.us-east-1.amazonaws.com/%s.zip', name);
cacheRoot = fullfile(tempdir(), ['ndi-corpus-' name]);
corpusDir = fullfile(cacheRoot, name);
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, [name '.zip']);
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
if ~isfolder(corpusDir)
    error('ndi:corpus:noDir', 'the zip did not extract a %s/ directory under %s', ...
        name, cacheRoot);
end
end

function bodies = readCorpusBodies(corpusDir)
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function buildV1Sqlite(tmpFile, bodies)
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
for k = 1:numel(bodies)
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        sprintf('id_%05d', k), k, bodies{k}, 0);
end
end

function bodies = destinationBodies(dstPath)
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

function tf = etaEnabled()
raw = lower(strtrim(getenv('NDI_TEST_ETA')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end

function rmdirQuiet(d)
try
    if isfolder(d)
        rmdir(d, 's');
    end
catch
end
end
