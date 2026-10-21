function [navBodies, report] = navigatorEpochFiles(path, bodies)
%NAVIGATOREPOCHFILES The epoch files of a session with no epochfiles cache, from its file navigators.
%
%   [NAVBODIES, REPORT] = ndi.migrate.internal.navigatorEpochFiles(PATH, BODIES)
%   opens the v1 session at PATH, asks each acquisition system's file
%   navigator for its epoch table, and returns, for every epoch that BODIES
%   (the v1 document bodies being migrated) holds no `epochfiles_ingested`
%   document for, a TRANSIENT v1 `epochfiles_ingested` body built exactly as
%   ndi.file.navigator/ingest builds one (navigator.m: `epoch_id`, `files` =
%   {'epochid://<id>'; the epoch's files}, `epochprobemap` = the serialized
%   epoch probe map, a `filenavigator_id` edge).
%
%   WHY (Jess Haley, 2026-10-21, did-schema V_eta_recording_observation_plan.md):
%   migrated recordings link their epoch files as data bodies, matching native
%   V2: one observation per element per epoch, `data_body` true, an
%   `opaque_body` per epoch file by location, shared by the electrodes recorded
%   in it, with the channel map. The DID batch pass
%   did2.convert.resolveEpochProbemap builds that from the cached
%   `epochfiles_ingested` documents. A session that was never ingested has no
%   such cache (PRED and 20211116 among the test corpora): only the file
%   navigator, which reads the session folder, knows its epochs' files and
%   probe maps. This supplies the same facts in the same shape, so ONE
%   pipeline (epochMint -> resolveEpochProbemap) handles both.
%
%   THE BODIES ARE TRANSIENT. They are not v1 documents and must not be
%   written: ndi.migrate.local converts them with the rest (so epochMint mints
%   their epochs and resolveEpochProbemap decomposes them), then REMOVES every
%   document carrying one of REPORT.transient_ids -- including the
%   ingestion_manifest a transient body may have been renamed to, which would
%   otherwise claim an ingestion that never happened.
%
%   An epoch the navigator reports as ingested (its files are an
%   `epochid://` cache) already has a document and is skipped. Every failure
%   is caught and counted; NAVBODIES is then empty and the migration proceeds
%   without per-epoch recording observations for those epochs.
%
%   See also ndi.migrate.local, did2.convert.resolveEpochProbemap,
%   ndi.file.navigator.

arguments
    path {mustBeTextScalar}
    bodies cell
end

navBodies = {};
report = struct('ran', false, 'daqsystems_seen', 0, 'epochs_seen', 0, ...
    'epochs_cached_already', 0, 'epochs_ingested', 0, 'epochs_synthesized', 0, ...
    'files_named', 0, 'error', '', 'transient_ids', {{}});

% the v1 epoch caches the batch already holds: (session, navigator, epoch)
cached = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(bodies)
    b = bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if ~isstruct(b) || ~isfield(b, 'document_class') ...
            || ~isfield(b.document_class, 'class_name') ...
            || ~strcmp(char(b.document_class.class_name), 'epochfiles_ingested') ...
            || ~isfield(b, 'epochfiles_ingested')
        continue;
    end
    cached(cacheKey(sessionOf(b), depOf(b, 'filenavigator_id'), ...
        char(b.epochfiles_ingested.epoch_id))) = true;
end

try
    S = ndi.session.dir(char(path));
    sid = S.id();
    devs = S.daqsystem_load('name', '(.*)');
    if isempty(devs)
        devs = {};
    elseif ~iscell(devs)
        devs = {devs};
    end
    report.ran = true;
    for d = 1:numel(devs)
        report.daqsystems_seen = report.daqsystems_seen + 1;
        nav = devs{d}.filenavigator;
        navId = nav.id();
        et = nav.epochtable();
        for i = 1:numel(et)
            report.epochs_seen = report.epochs_seen + 1;
            files = et(i).underlying_epochs.underlying;
            if ndi.file.navigator.isingested(files)
                report.epochs_ingested = report.epochs_ingested + 1;
                continue;
            end
            if isKey(cached, cacheKey(sid, navId, et(i).epoch_id))
                report.epochs_cached_already = report.epochs_cached_already + 1;
                continue;
            end
            b = struct();
            b.document_class = struct( ...
                'definition', '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
                'validation', '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
                'class_name', 'epochfiles_ingested', ...
                'property_list_name', 'epochfiles_ingested', ...
                'class_version', 1, ...
                'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
            b.depends_on = struct('name', 'filenavigator_id', 'value', navId);
            id = did.ido.unique_id();
            b.base = struct('id', id, 'session_id', sid, 'name', '', ...
                'datestamp', char(datetime('now', 'TimeZone', 'UTC', ...
                    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''')));
            % exactly as ndi.file.navigator/ingest writes it
            b.epochfiles_ingested = struct('epoch_id', et(i).epoch_id, ...
                'files', {cat(1, {['epochid://' et(i).epoch_id]}, files(:))}, ...
                'epochprobemap', et(i).epochprobemap.serialize());
            navBodies{end+1} = b; %#ok<AGROW>
            report.transient_ids{end+1} = id;
            report.epochs_synthesized = report.epochs_synthesized + 1;
            report.files_named = report.files_named + numel(files);
        end
    end
catch ME
    report.error = sprintf('%s: %s', ME.identifier, ME.message);
    navBodies = {};
    report.transient_ids = {};
end
end

function k = cacheKey(sid, navId, epochId)
k = [char(sid) '|' char(navId) '|' char(epochId)];
end

function s = sessionOf(b)
s = '';
if isfield(b, 'base') && isfield(b.base, 'session_id'); s = char(b.base.session_id); end
end

function v = depOf(b, name)
v = '';
if ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
if iscell(deps); deps = [deps{:}]; end
for k = 1:numel(deps)
    if strcmp(deps(k).name, name)
        if isfield(deps(k), 'value'); v = char(deps(k).value); end
        return;
    end
end
end
