function A = ingestedArchive(S, readerId, epochId)
%INGESTEDARCHIVE An ingested mfdaq epoch's data, read from its v2 data bodies.
%
%   A = ndi.vintage.ingestedArchive(SESSION, READERID, EPOCHID) finds, in a
%   v2 session, what NDI's mfdaq reader reads from a v1
%   `daqreader_mfdaq_epochdata_ingested` document for the ingested epoch
%   EPOCHID ('epoch_...', the `local_identifier` of the epoch entity) of the
%   reader READERID:
%
%     the epoch          the `entity` whose local_identifier is EPOCHID
%     its recordings     the statements timed by a relative_time_reference
%                        onto that epoch (time_reference_id -> referent_id)
%                        whose `acquisition_system_id` names a system whose
%                        `reader_id` is READERID
%     their data         the data bodies those statements own (owner_id),
%                        one per v1 attached file series, named by the v1
%                        series name in `data_body.filename`
%                        (`ai_group1_seg.nbf_#`, `channel_list.bin`, ...)
%
%   Decided by Jess Haley, 2026-10-29 [V2 ingest is one sampled body per
%   channel group] (did-schema did_v2_go_forward_class_audit.md): "a reader
%   finds an epoch's data through those bodies, not through the v1
%   `daqreader_mfdaq_epochdata_ingested` document". Migration writes that
%   shape ([ingested archives are sampled bodies]; DID-matlab
%   did2.convert.resolveEpochProbemap carries each v1 file series as an
%   opaque_body, ndi.migrate.internal.ingestedArchiveBodies turns each
%   channel group into a sampled_body). Both are read:
%
%     a sampled_body    its time dimension's `chunk` is the v1 segment length
%                       ([segment length is the time chunk]) and its `n` the
%                       number of samples; its covariates hold the channel
%                       list (channel number, offset, scale, and the sample
%                       rate as the time covariate's spacing)
%     an opaque_body    the v1 series as pass 1 carried it: member
%                       body_data_<k> is v1 segment k+1. Its segment length
%                       is the length of its first member when it has more
%                       than one (a single member holds the whole epoch)
%
%   A is a struct:
%
%     vintage       'v2'
%     epoch_id      EPOCHID
%     bodies        containers.Map, series name -> struct with fields
%                     doc     the body (ndi.document)
%                     kind    'sampled_body' or 'opaque_body'
%                     n       samples along time ([] when not stated)
%                     chunk   samples per member ([] when not stated)
%                     members the number of body_data_<k> members
%     channels      the v1 channel list (ndi.file.type.mfdaq_epoch_channel
%                   channel_information): read from the `channel_list.bin`
%                   body when there is one; otherwise rebuilt from the
%                   sampled bodies' covariates (each row named by its v1
%                   prefix and number, time_channel NaN: the second pass
%                   removes channel_list.bin only when every row is of that
%                   kind)
%     epochclock    cellstr, the ndi.time.clocktype strings of the clocks on
%                   which the epoch's extent is stated
%     t0_t1         cell, [t0 t1] on each of those clocks
%     clock_problem '' or, when no clock is stated, why
%
%   THE EPOCH'S CLOCK AND EXTENT. Decided by Jess Haley, 2026-11-01 [clock
%   only on the time reference]: "an ingested or migrated data body names no
%   clock: its time axis counts seconds from the start of the epoch ..., and
%   the recording observation's time references say when the epoch starts on
%   each clock". They are read from
%     1. the recordings' time references, and
%     2. any other relative_time_reference onto the epoch,
%   each one that states a clock and a start (and an end or duration), the
%   shape DID-matlab's jEpochClockReferences writes from a v1 epochtable
%   (clock, start, duration). When none does, EPOCHCLOCK and T0_T1 are empty
%   and CLOCK_PROBLEM says so; the reader then refuses to report a clock
%   rather than assume one.
%
%   See also ndi.daq.reader/getingestedarchive, ndi.daq.reader.mfdaq,
%            ndi.migrate.internal.ingestedArchiveBodies,
%            ndi.vintage.ingestedEpochs.

arguments
    S
    readerId (1,:) char
    epochId (1,:) char
end

A = struct('vintage', 'v2', 'epoch_id', epochId, ...
    'bodies', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'channels', [], 'epochclock', {{}}, 't0_t1', {{}}, 'clock_problem', '');

inSession = ndi.query('base.session_id', 'exact_string', S.id(), '');

% ---- the epoch -------------------------------------------------------
epochs = S.database_search(ndi.query('', 'isa', 'entity', '') & ...
    ndi.query('entity.local_identifier', 'exact_string', epochId, '') & inSession);
if isempty(epochs)
    error('NDI:daq:reader:ingestedNoEpoch', ...
        'No v2 epoch entity has local_identifier %s.', epochId);
end
epochIds = cellfun(@(d) d.id(), epochs, 'UniformOutput', false);
anchors = S.database_search(ndi.query('', 'isa', 'relative_time_reference', '') & ...
    ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'referent_id', i), ...
        epochIds, 'UniformOutput', false)));
anchorIds = cellfun(@(d) d.id(), anchors, 'UniformOutput', false);

% ---- this reader's systems and their recordings of the epoch ---------
systems = S.database_search(ndi.query('', 'isa', 'acquisition_system', '') & ...
    ndi.query('', 'depends_on', 'reader_id', readerId) & inSession);
statements = {};
if ~isempty(anchors) && ~isempty(systems)
    statements = S.database_search(ndi.v2.isaQuery('statement') & ...
        ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'time_reference_id', i), ...
            anchorIds, 'UniformOutput', false)) & ...
        ndi.v2.anyOf(cellfun(@(d) ndi.query('', 'depends_on', 'acquisition_system_id', d.id()), ...
            systems, 'UniformOutput', false)));
end
if isempty(statements)
    error('NDI:daq:reader:ingestedNoRecording', ...
        'No v2 recording of epoch %s names an acquisition system read by reader %s.', ...
        epochId, readerId);
end

% ---- the bodies they own ---------------------------------------------
bodies = S.database_search(ndi.query('', 'isa', 'data_body', '') & ...
    ndi.v2.anyOf(cellfun(@(d) ndi.query('', 'depends_on', 'owner_id', d.id()), ...
        statements, 'UniformOutput', false)));
for k = 1:numel(bodies)
    p = bodies{k}.document_properties;
    fn = bodyFilename(p);
    if isempty(seriesKind(fn)) || isKey(A.bodies, fn)
        continue;   % not an archive series, or a shared body met twice
    end
    [n, chunk] = timeExtent(p);
    A.bodies(fn) = struct('doc', bodies{k}, 'kind', p.document_class.class_name, ...
        'n', n, 'chunk', chunk, 'members', numel(memberNames(p)));
end
if A.bodies.Count == 0
    error('NDI:daq:reader:ingestedNoBodies', ...
        'The v2 recordings of epoch %s own no ingested data body.', epochId);
end

% ---- the channel list --------------------------------------------------
if isKey(A.bodies, 'channel_list.bin')
    tname = [ndi.file.temp_name() '.bin'];
    writeMember(S, A.bodies('channel_list.bin').doc, 'body_data_0', tname);
    c = onCleanup(@() deleteIfThere(tname));
    A.channels = ndi.file.type.mfdaq_epoch_channel(tname).channel_information;
else
    A.channels = channelsFromCovariates(A.bodies);
end

% ---- the epoch's clock(s) and extent -----------------------------------
used = {};
for k = 1:numel(statements)
    used = [used, ndi.v2.edgeIds(statements{k}.document_properties, 'time_reference_id')]; %#ok<AGROW>
end
order = [find(ismember(anchorIds, used)), find(~ismember(anchorIds, used))];
for k = order(:)'
    [ok, clk, t0, t1] = clockExtent(anchors{k}.document_properties);
    if ok && ~any(strcmp(A.epochclock, clk))
        A.epochclock{end+1} = clk;
        A.t0_t1{end+1} = [t0 t1];
    end
end
if isempty(A.epochclock)
    A.clock_problem = sprintf(['The migrated epoch %s states no clock: none of its %d time ' ...
        'reference(s) (relative_time_reference onto the epoch entity) names a clock and a start, ' ...
        'so its epoch clock and t0_t1 cannot be read (did-schema [clock only on the time ' ...
        'reference]: "the recording observation''s time references say when the epoch starts ' ...
        'on each clock").'], epochId, numel(anchors));
end
end

% =====================================================================

function kind = seriesKind(fn)
% the archive series ndi.daq.reader.mfdaq/ingest_epochfiles attaches
kind = '';
if strcmp(fn, 'channel_list.bin'); kind = 'channel_list'; return; end
if ~isempty(regexp(fn, '^(ai|ao|ax|di|do|ti|evmktx)_group\d+_seg\.nbf_#$', 'once'))
    kind = 'series';
end
end

function fn = bodyFilename(p)
fn = '';
if isfield(p, 'data_body') && isstruct(p.data_body) && isfield(p.data_body, 'filename')
    fn = char(p.data_body.filename);
end
end

function names = memberNames(p)
names = {};
if ~isfield(p, 'files') || ~isstruct(p.files) || ~isfield(p.files, 'file_info')
    return;
end
fi = p.files.file_info;
if isstruct(fi); fi = num2cell(fi); end
names = cellfun(@(f) char(f.name), fi, 'UniformOutput', false);
names = names(startsWith(names, 'body_data_'));
end

function [n, chunk] = timeExtent(p)
% n and chunk of the body's time dimension (om:Time), [] when not stated
n = []; chunk = [];
if ~isfield(p, 'data') || ~isstruct(p.data) || ~isfield(p.data, 'dimensions')
    return;
end
dims = asCell(p.data.dimensions);
for k = 1:numel(dims)
    dk = dims{k};
    if isTimeTerm(dk, 'term')
        if isfield(dk, 'n') && ~isempty(dk.n); n = double(dk.n); end
        if isfield(dk, 'chunk') && ~isempty(dk.chunk); chunk = double(dk.chunk); end
        return;
    end
end
end

function tf = isTimeTerm(s, field)
tf = false;
if ~isstruct(s) || ~isfield(s, field) || ~isstruct(s.(field)); return; end
t = s.(field);
if isfield(t, 'node') && strcmp(char(t.node), 'om:Time'); tf = true; return; end
tf = isfield(t, 'name') && strcmpi(char(t.name), 'time');
end

function ci = channelsFromCovariates(bodies)
% the v1 channel list rows a converted channel group carries
% (ndi.migrate.internal.ingestedArchiveBodies: channel number, offset and
% scale along the channel dimension, the sample rate as the time spacing,
% the channel type as the body's condition)
ci = struct('name', {}, 'type', {}, 'time_channel', {}, 'sample_rate', {}, ...
    'offset', {}, 'scale', {}, 'number', {}, 'group', {}, 'dataclass', {});
[types, abbrev] = ndi.daq.reader.mfdaq.channel_types();
names = bodies.keys;
for k = 1:numel(names)
    b = bodies(names{k});
    if ~strcmp(b.kind, 'sampled_body'); continue; end
    tok = regexp(names{k}, '^([a-z]+)_group(\d+)_seg', 'tokens', 'once');
    if isempty(tok) || any(strcmp(tok{1}, {'ti', 'evmktx'})); continue; end
    p = b.doc.document_properties;
    ab = channelPrefixOf(p, tok{1});
    type = types{find(strcmp(abbrev, ab), 1)};
    covs = asCell(p.data.covariates);
    nums = []; off = []; sc = []; sr = NaN;
    for c = 1:numel(covs)
        cv = covs{c};
        v = cv.variable;
        nm = ''; node = '';
        if isfield(v, 'name'); nm = char(v.name); end
        if isfield(v, 'node'); node = char(v.node); end
        if isTimeTerm(cv, 'variable') && isfield(cv, 'spacing') && isstruct(cv.spacing) ...
                && isfield(cv.spacing, 'value')
            sr = 1 / double(cv.spacing.value);
        elseif strcmp(nm, 'channel number')
            nums = double(cv.count(:)');
        elseif strcmp(node, 'AFO:AFQ_0000202')
            off = double(cv.quantity.value(:)');
        elseif strcmp(node, 'NCIT:C70774')
            sc = double(cv.quantity.value(:)');
        end
    end
    if any(strcmp(ab, {'di', 'do'})); dc = 'digital'; else; dc = 'ephys'; end
    for r = 1:numel(nums)
        ci(end+1) = struct('name', sprintf('%s%d', ab, nums(r)), 'type', type, ...
            'time_channel', NaN, 'sample_rate', sr, 'offset', off(r), 'scale', sc(r), ...
            'number', nums(r), 'group', str2double(tok{2}), 'dataclass', dc); %#ok<AGROW>
    end
end
end

function ab = channelPrefixOf(p, filePrefix)
% the channel type the body's condition names (by node: [channel types]);
% the file's prefix when it names none
ab = filePrefix;
if ~isfield(p, 'data_body') || ~isfield(p.data_body, 'conditions'); return; end
cs = asCell(p.data_body.conditions);
for c = 1:numel(cs)
    if isfield(cs{c}, 'term') && ~isempty(cs{c}.term)
        got = char(ndi.vintage.channelPrefix(cs{c}.term));
        if any(strcmp(got, {'ai', 'ao', 'ax', 'di', 'do'}))
            ab = got;
            return;
        end
    end
end
end

function [ok, clk, t0, t1] = clockExtent(p)
% a relative_time_reference's clock (ndi.time.clocktype string), start and
% end, in seconds; ok false unless all three are stated
ok = false; clk = ''; t0 = []; t1 = [];
if ~isfield(p, 'relative_time_reference') || ~isstruct(p.relative_time_reference) ...
        || ~isfield(p.relative_time_reference, 'value') || ~isstruct(p.relative_time_reference.value)
    return;
end
v = p.relative_time_reference.value;
if ~isfield(v, 'clock') || isempty(v.clock) || ~isfield(v, 'start')
    return;
end
clk = char(ndi.v2.vocabHandle('clock', v.clock));
t0 = secondsOf(v.start);
if isempty(clk) || isempty(t0); return; end
if isfield(v, 'end'); t1 = secondsOf(v.end); end
if isempty(t1) && isfield(v, 'duration')
    d = secondsOf(v.duration);
    if ~isempty(d); t1 = t0 + d; end
end
ok = ~isempty(t1);
end

function s = secondsOf(x)
s = [];
if isstruct(x) && ~isempty(x) && isfield(x, 'seconds') && ~isempty(x(1).seconds) ...
        && isnumeric(x(1).seconds)
    s = double(x(1).seconds);
end
end

function writeMember(S, doc, member, target)
f = S.database_openbinarydoc(doc, member);
data = f.fread(Inf, 'uint8');
S.database_closebinarydoc(f);
fid = fopen(target, 'wb', 'ieee-le');
fwrite(fid, data, 'uint8');
fclose(fid);
end

function c = asCell(x)
if iscell(x); c = x; elseif isstruct(x); c = num2cell(x); else; c = {}; end
end

function deleteIfThere(f)
if isfile(f); delete(f); end
end
