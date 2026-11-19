function R = cloudReadtimeseriesTiming(options)
%CLOUDREADTIMESERIESTIMING Time readtimeseries on an NDI Cloud dataset, v1 and after ndi.migrate.local.
%
%   R = ndi.unittest.migrate.cloudReadtimeseriesTiming() signs in to NDI
%   Cloud with NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD, downloads the Haley
%   dataset's documents and the binary files of a fixed set of element
%   epochs, reads each with readtimeseries on the v1 database, migrates the
%   dataset in place with ndi.migrate.local, reads each again, and compares
%   the samples and times. It prints a report with its denominators first
%   and returns it.
%
%   WHY. Decided by Jess Haley, 2026-11-19 [readtimeseries timed with NDI
%   Cloud] (did-schema did_v2_standing_wiring_plan.md), for
%   VH-Lab/NDI-matlab#1018: "an on-demand NDI-matlab workflow, never on
%   push, signs in to NDI Cloud with a repository secret, fetches the Haley
%   session's binaries and times `readtimeseries` on v1 and on migrated v2,
%   comparing the samples; until a team member adds the secret it reports
%   not measured and exits cleanly." The corpus zips (JH.zip included) carry
%   no binary files, and the Haley files are at ndic:// paths, so no corpus
%   test can read these series. The workflow is
%   .github/workflows/test-cloud-readtimeseries-haley.yml.
%
%   NOT MEASURED is a third state. With no credentials in the environment
%   this prints "NOT MEASURED: no NDI Cloud secret" and returns
%   R.state = 'not measured'; it never reads as equal or as differing.
%
%   THE FIXED SET. From the downloaded documents, the v1 `element` documents
%   that have at least one `element_epoch` (the .vhsb series
%   ndi.element.timeseries/readtimeseries reads) are the candidates. They
%   are grouped by `element.type`; the types are taken in sorted order, the
%   elements of each in order of document id, round robin, until
%   'MaxElements' are chosen, so one type does not take the whole set. Of
%   each, the 'EpochsPerElement' epochs with the smallest epoch ids are read.
%   The same input gives the same set. 'ElementIds' names the set instead.
%
%   THE BINARIES. Only the chosen epochs' files are downloaded
%   (ndi.cloud.download.downloadDatasetFiles) and recorded as local files
%   (ndi.cloud.sync.internal.updateFileInfoForLocalFiles), as
%   ndi.cloud.downloadDataset does with 'SyncFiles' true for every file;
%   every other document keeps its ndic:// location
%   (updateFileInfoForRemoteFiles), as with 'SyncFiles' false. So the v1
%   reads do not download, and the bytes are in the database's file store
%   when ndi.migrate.local's second pass and the migrated reads look for
%   them (did2sqlite reads no ndic:// location).
%
%   THE TIMES. Per pair, in seconds: the session's getelements (once per
%   session and side), the element's epochtable, and readtimeseries(epoch,
%   -Inf, Inf) twice (first and second read). The migration itself is
%   timed too.
%
%   THE COMPARISON. Per pair: the sample arrays equal (isequaln, sizes
%   included), and the times equal exactly or within 'TimeTolerance'
%   seconds (default 1e-9; the largest difference is printed). A pair is
%   `same` when both reads returned, the samples are equal and the times are
%   within the tolerance.
%
%   Options (name-value):
%     DatasetId         NDI Cloud dataset id (default
%                       '682e7772cdf3f24938176fac', the Haley dataset of
%                       VH-Lab/NDI-matlab#1018)
%     WorkDir           where the dataset is downloaded (default tempname)
%     MaxElements       number of elements to read (default 4)
%     EpochsPerElement  epochs read per element (default 1)
%     ElementIds        explicit element document ids (default {}: the
%                       fixed set above)
%     TimeTolerance     seconds (default 1e-9)
%     ReportFile        a JSON copy of R is written here when not empty
%
%   R (denominators first):
%     state                 'measured' or 'not measured'
%     reason                why not measured (empty when measured)
%     dataset_id
%     documents_downloaded  every document of the dataset (THE first
%                           denominator)
%     elements_in_documents v1 `element` documents
%     candidate_elements    of those, the ones with an element_epoch
%     pairs_selected        (element, epoch) pairs read (THE denominator of
%                           the comparison)
%     files_downloaded      file uids fetched for those epochs
%     migration             {seconds, total, migrated, quarantined}
%     pairs_same, pairs_differ, pairs_v1_error, pairs_v2_error
%     pairs                 one row per pair: element id, name, type,
%                           session id, epoch id, v1 and v2 {size, seconds,
%                           epochtable seconds, second-read seconds, error},
%                           samples_equal, times_exact, times_max_abs_diff,
%                           same
%     getelements           per session and side: {session_id, side,
%                           seconds, count, error}
%
%   See also ndi.unittest.migrate.TestReadTimeseriesEquivalence (the same
%   comparison on a fixture built from code), ndi.migrate.local.

arguments
    options.DatasetId (1,:) char = '682e7772cdf3f24938176fac'
    options.WorkDir (1,:) char = ''
    options.MaxElements (1,1) double {mustBePositive, mustBeInteger} = 4
    options.EpochsPerElement (1,1) double {mustBePositive, mustBeInteger} = 1
    options.ElementIds cell = {}
    options.TimeTolerance (1,1) double {mustBeNonnegative} = 1e-9
    options.ReportFile (1,:) char = ''
end

R = struct('state', 'not measured', 'reason', '', 'dataset_id', options.DatasetId, ...
    'documents_downloaded', 0, 'elements_in_documents', 0, 'candidate_elements', 0, ...
    'pairs_selected', 0, 'files_downloaded', 0, ...
    'migration', struct('seconds', NaN, 'total', NaN, 'migrated', NaN, 'quarantined', NaN), ...
    'pairs_same', 0, 'pairs_differ', 0, 'pairs_v1_error', 0, 'pairs_v2_error', 0, ...
    'pairs', struct([]), 'getelements', struct([]));

% ---- the secret --------------------------------------------------------------
if isempty(getenv('NDI_CLOUD_USERNAME')) || isempty(getenv('NDI_CLOUD_PASSWORD'))
    R.reason = 'no NDI Cloud secret';
    fprintf('NOT MEASURED: no NDI Cloud secret\n');
    writeReport(R, options.ReportFile);
    return;
end

% ---- sign in, download the documents --------------------------------------
fprintf('Signing in to NDI Cloud (environment: %s)\n', ...
    char(string(defaultTo(getenv('CLOUD_API_ENVIRONMENT'), 'prod'))));
ndi.cloud.authenticate('InteractionEnabled', 'off');

workDir = options.WorkDir;
if isempty(workDir)
    workDir = tempname();
end
datasetFolder = fullfile(workDir, options.DatasetId);
if ~isfolder(datasetFolder)
    mkdir(datasetFolder);
end
fprintf('Downloading the documents of dataset %s\n', options.DatasetId);
tic;
docs = ndi.cloud.download.downloadDocumentCollection(string(options.DatasetId), "");
fprintf('  %d document(s) in %.1f s\n', numel(docs), toc);
R.documents_downloaded = numel(docs);
if isempty(docs)
    error('NDI:cloudReadtimeseriesTiming:noDocuments', ...
        'Dataset %s returned no documents.', options.DatasetId);
end

% ---- the fixed set -------------------------------------------------------------
[elements, epochsOf] = elementsAndEpochs(docs);
R.elements_in_documents = numel(elements);
ids = cellfun(@(d) d.id(), elements, 'UniformOutput', false);
hasEpochs = cellfun(@(i) isKey(epochsOf, i), ids);
R.candidate_elements = sum(hasEpochs);
chosen = chooseElements(elements(hasEpochs), options.MaxElements, options.ElementIds);
pairs = struct('element_id', {}, 'name', {}, 'type', {}, 'session_id', {}, ...
    'epoch_id', {}, 'epoch_doc', {});
for k = 1:numel(chosen)
    e = chosen{k};
    eps = epochsOf(e.id());
    epIds = cellfun(@(d) char(d.document_properties.epochid.epochid), eps, 'UniformOutput', false);
    [~, order] = sort(epIds);
    for j = order(1:min(options.EpochsPerElement, numel(order)))
        pairs(end+1) = struct('element_id', e.id(), ...
            'name', char(e.document_properties.element.name), ...
            'type', char(e.document_properties.element.type), ...
            'session_id', char(e.document_properties.base.session_id), ...
            'epoch_id', epIds{j}, 'epoch_doc', {eps{j}}); %#ok<AGROW>
    end
end
R.pairs_selected = numel(pairs);
fprintf(['\nDENOMINATORS: %d document(s) downloaded; %d element document(s), %d with an ' ...
    'element_epoch; %d (element, epoch) pair(s) selected\n'], R.documents_downloaded, ...
    R.elements_in_documents, R.candidate_elements, R.pairs_selected);
if isempty(pairs)
    error('NDI:cloudReadtimeseriesTiming:nothingToRead', ...
        'No element of dataset %s has an element_epoch to read.', options.DatasetId);
end

% ---- the chosen epochs' binaries, then the v1 dataset ---------------------
filesFolder = fullfile(datasetFolder, ndi.cloud.sync.internal.Constants.FileSyncLocation);
if ~isfolder(filesFolder)
    mkdir(filesFolder);
end
epochDocs = {pairs.epoch_doc};
uids = ndi.cloud.sync.internal.getFileUidsFromDocuments(epochDocs);
R.files_downloaded = numel(uids);
fprintf('Downloading %d file(s) of the selected epochs\n', numel(uids));
tic;
if ~isempty(uids)
    ndi.cloud.download.downloadDatasetFiles(string(options.DatasetId), string(filesFolder), ...
        reshape(string(uids), 1, []), 'Verbose', false);
end
fprintf('  in %.1f s\n', toc);
localIds = cellfun(@(d) d.id(), epochDocs, 'UniformOutput', false);
for k = 1:numel(docs)
    if any(strcmp(docs{k}.id(), localIds))
        docs{k} = ndi.cloud.sync.internal.updateFileInfoForLocalFiles(docs{k}, ...
            string(filesFolder), string(options.DatasetId));
    else
        docs{k} = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(docs{k}, ...
            string(options.DatasetId));
    end
end
fprintf('Building the v1 dataset at %s\n', datasetFolder);
tic;
D = ndi.dataset.dir([], datasetFolder, docs); %#ok<NASGU>
fprintf('  in %.1f s\n', toc);
clear D docs
closeAll();

% ---- read v1 ------------------------------------------------------------------
[v1, ge1] = readPairs(datasetFolder, pairs, 'v1');

% ---- migrate ----------------------------------------------------------------
fprintf('\nMigrating %s with ndi.migrate.local\n', datasetFolder);
tic;
mig = ndi.migrate.local(datasetFolder, 'Validate', true, 'Backup', false);
R.migration = struct('seconds', toc, 'total', mig.summary.total, ...
    'migrated', mig.summary.migrated_count, 'quarantined', numel(mig.quarantine));
fprintf('  %d source document(s), %d migrated, %d quarantined, in %.1f s\n', ...
    R.migration.total, R.migration.migrated, R.migration.quarantined, R.migration.seconds);
closeAll();

% ---- read v2 ------------------------------------------------------------------
[v2, ge2] = readPairs(datasetFolder, pairs, 'v2');
R.getelements = [ge1, ge2];

% ---- compare ----------------------------------------------------------------
rows = struct([]);
for k = 1:numel(pairs)
    a = v1(k);
    b = v2(k);
    row = struct('element_id', pairs(k).element_id, 'name', pairs(k).name, ...
        'type', pairs(k).type, 'session_id', pairs(k).session_id, ...
        'epoch_id', pairs(k).epoch_id, 'v1', summary(a), 'v2', summary(b), ...
        'samples_equal', false, 'times_exact', false, 'times_max_abs_diff', NaN, 'same', false);
    if ~isempty(a.err)
        R.pairs_v1_error = R.pairs_v1_error + 1;
    elseif ~isempty(b.err)
        R.pairs_v2_error = R.pairs_v2_error + 1;
    else
        row.samples_equal = isequal(size(a.data), size(b.data)) && isequaln(a.data, b.data);
        [row.times_exact, row.times_max_abs_diff] = compareTimes(a.t, b.t);
        row.same = row.samples_equal && (row.times_exact || ...
            row.times_max_abs_diff <= options.TimeTolerance);
        if row.same
            R.pairs_same = R.pairs_same + 1;
        else
            R.pairs_differ = R.pairs_differ + 1;
        end
    end
    rows = [rows, row]; %#ok<AGROW>
end
R.pairs = rows;
R.state = 'measured';
printReport(R, options.TimeTolerance);
writeReport(R, options.ReportFile);
end

% =========================================================================

function [elements, epochsOf] = elementsAndEpochs(docs)
% the v1 element documents, and element id -> its element_epoch documents
elements = {};
epochsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(docs)
    d = docs{k};
    cn = char(d.document_properties.document_class.class_name);
    if strcmp(cn, 'element')
        elements{end+1} = d; %#ok<AGROW>
    elseif strcmp(cn, 'element_epoch')
        eid = char(d.dependency_value('element_id', 'ErrorIfNotFound', 0));
        if isempty(eid); continue; end
        if isKey(epochsOf, eid)
            epochsOf(eid) = [epochsOf(eid), {d}];
        else
            epochsOf(eid) = {d};
        end
    end
end
end

function chosen = chooseElements(candidates, maxElements, elementIds)
% the fixed set: named ids, else round robin over the sorted types
if ~isempty(elementIds)
    ids = cellfun(@(d) d.id(), candidates, 'UniformOutput', false);
    chosen = {};
    for k = 1:numel(elementIds)
        hit = find(strcmp(ids, elementIds{k}), 1);
        if isempty(hit)
            error('NDI:cloudReadtimeseriesTiming:noSuchElement', ...
                'Element %s is not an element with an element_epoch in this dataset.', elementIds{k});
        end
        chosen{end+1} = candidates{hit}; %#ok<AGROW>
    end
    return;
end
types = cellfun(@(d) char(d.document_properties.element.type), candidates, 'UniformOutput', false);
ids = cellfun(@(d) d.id(), candidates, 'UniformOutput', false);
utypes = sort(unique(types));
queues = cell(1, numel(utypes));
for t = 1:numel(utypes)
    members = find(strcmp(types, utypes{t}));
    [~, o] = sort(ids(members));
    queues{t} = members(o);
end
chosen = {};
while numel(chosen) < maxElements && any(~cellfun(@isempty, queues))
    for t = 1:numel(utypes)
        if numel(chosen) >= maxElements; break; end
        if isempty(queues{t}); continue; end
        chosen{end+1} = candidates{queues{t}(1)}; %#ok<AGROW>
        queues{t}(1) = [];
    end
end
end

function [out, ge] = readPairs(datasetFolder, pairs, side)
% open the dataset, each session once, and read every pair
out = struct('data', {}, 't', {}, 'err', {}, 'seconds', {}, 'seconds_second', {}, ...
    'epochtable_seconds', {});
ge = struct('session_id', {}, 'side', {}, 'seconds', {}, 'count', {}, 'error', {});
fprintf('\nReading %d pair(s) on the %s dataset\n', numel(pairs), side);
D = [];
openErr = '';
% the side is the database the folder opens: v1's didsqlite before the
% migration, the migrated did2sqlite after it
expected = struct('v1', 'ndi.database.implementations.database.didsqlite', ...
    'v2', 'ndi.database.implementations.database.did2sqlite');
try
    D = ndi.dataset.dir(datasetFolder);
    db = ndi.database.fun.opendatabase(fullfile(datasetFolder, '.ndi'), D.id());
    if ~isa(db, expected.(side))
        openErr = sprintf('the %s dataset opened a %s, not a %s', side, class(db), ...
            expected.(side));
    end
    clear db
catch ME
    openErr = errorText(ME);
end
sessions = unique({pairs.session_id}, 'stable');
objs = containers.Map('KeyType', 'char', 'ValueType', 'any');
for s = 1:numel(sessions)
    g = struct('session_id', sessions{s}, 'side', side, 'seconds', NaN, 'count', NaN, ...
        'error', openErr);
    if isempty(openErr)
        try
            S = D.open_session(sessions{s});
            tic;
            els = S.getelements();
            g.seconds = toc;
            if ~iscell(els); els = {els}; end
            g.count = numel(els);
            for j = 1:numel(els)
                objs([sessions{s} '|' els{j}.id()]) = els{j};
            end
        catch ME
            g.error = errorText(ME);
        end
    end
    fprintf('  %s session %s: getelements %s\n', side, sessions{s}, geText(g));
    ge(end+1) = g; %#ok<AGROW>
end
for k = 1:numel(pairs)
    p = pairs(k);
    r = struct('data', [], 't', [], 'err', '', 'seconds', NaN, 'seconds_second', NaN, ...
        'epochtable_seconds', NaN);
    key = [p.session_id '|' p.element_id];
    try
        g = ge(strcmp({ge.session_id}, p.session_id));
        assert(isempty(g(1).error), 'opening the session or getelements raised: %s', g(1).error);
        assert(isKey(objs, key), 'getelements returned no element with id %s', p.element_id);
        o = objs(key);
        tic;
        o.epochtable();
        r.epochtable_seconds = toc;
        tic;
        [r.data, r.t] = o.readtimeseries(p.epoch_id, -Inf, Inf);
        r.seconds = toc;
        tic;
        o.readtimeseries(p.epoch_id, -Inf, Inf);
        r.seconds_second = toc;
    catch ME
        r.err = errorText(ME);
    end
    fprintf('  %s %s "%s" (%s) epoch %s: %s\n', side, p.element_id, p.name, p.type, ...
        p.epoch_id, readText(r));
    out(end+1) = r; %#ok<AGROW>
end
clear D S objs
closeAll();
end

function [exact, maxDiff] = compareTimes(a, b)
exact = isequaln(a, b);
maxDiff = NaN;
if exact
    maxDiff = 0;
    return;
end
if isnumeric(a) && isnumeric(b) && isequal(size(a), size(b))
    maxDiff = max(abs(double(a(:)) - double(b(:))), [], 'omitnan');
    if isempty(maxDiff); maxDiff = 0; end
else
    maxDiff = Inf;
end
end

function s = summary(r)
s = struct('size', size(r.data), 'seconds', r.seconds, 'seconds_second', r.seconds_second, ...
    'epochtable_seconds', r.epochtable_seconds, 'error', r.err);
end

function printReport(R, tol)
fprintf('\n==== readtimeseries on NDI Cloud dataset %s, v1 and after ndi.migrate.local ====\n', ...
    R.dataset_id);
fprintf(['DENOMINATORS: %d document(s) downloaded; %d element document(s), %d with an ' ...
    'element_epoch; %d pair(s) selected; %d file(s) downloaded\n'], R.documents_downloaded, ...
    R.elements_in_documents, R.candidate_elements, R.pairs_selected, R.files_downloaded);
fprintf('STATE: %s\n', upper(R.state));
fprintf('MIGRATION: %d source document(s), %d migrated, %d quarantined, %.1f s\n', ...
    R.migration.total, R.migration.migrated, R.migration.quarantined, R.migration.seconds);
for g = R.getelements
    fprintf('GETELEMENTS %s session %s: %s\n', g.side, g.session_id, geText(g));
end
fprintf(['PAIRS: %d selected: %d same (samples equal, times within %g s), %d differ, ' ...
    '%d v1 read error(s), %d v2 read error(s)\n'], R.pairs_selected, R.pairs_same, ...
    R.pairs_differ, tol, R.pairs_v1_error, R.pairs_v2_error);
for p = R.pairs
    fprintf('  %s "%s" (%s) epoch %s\n', p.element_id, p.name, p.type, p.epoch_id);
    fprintf('    v1: %s\n    v2: %s\n', sideText(p.v1), sideText(p.v2));
    fprintf('    samples equal %d; times exact %d, max |dt| %g s; SAME %d\n', ...
        p.samples_equal, p.times_exact, p.times_max_abs_diff, p.same);
end
end

function s = sideText(x)
if ~isempty(x.error)
    s = ['ERROR ' x.error];
    return;
end
s = sprintf('%s samples; epochtable %.3f s; readtimeseries %.3f s (second read %.3f s)', ...
    mat2str(x.size), x.epochtable_seconds, x.seconds, x.seconds_second);
end

function s = readText(r)
if ~isempty(r.err)
    s = ['ERROR ' r.err];
    return;
end
s = sprintf('%s samples; epochtable %.3f s; readtimeseries %.3f s (second read %.3f s)', ...
    mat2str(size(r.data)), r.epochtable_seconds, r.seconds, r.seconds_second);
end

function s = geText(g)
if ~isempty(g.error)
    s = ['ERROR ' g.error];
else
    s = sprintf('%d element(s) in %.1f s', g.count, g.seconds);
end
end

function writeReport(R, file)
if isempty(file); return; end
fid = fopen(file, 'w');
if fid < 0
    warning('NDI:cloudReadtimeseriesTiming:reportFile', 'Could not write %s.', file);
    return;
end
fprintf(fid, '%s', jsonencode(R, 'PrettyPrint', true));
fclose(fid);
end

function closeAll()
try
    mksqlite('close');
catch
end
end

function v = defaultTo(v, d)
if isempty(v); v = d; end
end

function s = errorText(ME)
s = sprintf('%s (%s)', ME.message, ME.identifier);
if ~isempty(ME.stack)
    s = sprintf('%s at %s:%d', s, ME.stack(1).name, ME.stack(1).line);
end
end
