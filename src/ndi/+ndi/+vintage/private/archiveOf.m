function A = archiveOf(S, epochId, anchors, statements, bodies, readChannels)
%ARCHIVEOF An ingested epoch's archive, put together from its documents.
%
%   A = archiveOf(S, EPOCHID, ANCHORS, STATEMENTS, BODIES, READCHANNELS) is
%   the struct ndi.vintage.ingestedArchive describes, from the documents
%   its searches found: ANCHORS, the relative_time_references onto the epoch;
%   STATEMENTS, this reader's recordings timed by them; BODIES, the data
%   bodies those own, each list in the order the database returned it.
%   ndi.vintage.ingestedArchive reads them with its own searches, one epoch
%   at a time; ndi.vintage.ingestedArchives reads every epoch's at once and
%   joins them in memory. Both put the archive together here, so they agree.
%   Raises NDI:daq:reader:ingestedNoBodies when no body is an archive series.
%
%   With READCHANNELS, A.events lists the epoch's unpacked event, marker and
%   text channels (ndi.vintage.ingestedEventChannels; [event channels are
%   time-valued observations], Jess Haley, 2026-11-17), and A.channels is the
%   `channel_list.bin` body's list when there is one, else the list rebuilt
%   from the channel groups' covariates and those channels
%   (ndi.vintage.ingestedChannelList).

A = struct('vintage', 'v2', 'epoch_id', epochId, ...
    'bodies', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'channels', [], 'events', [], 'epochclock', {{}}, 't0_t1', {{}}, 'clock_problem', '');
anchorIds = cellfun(@(d) d.id(), anchors, 'UniformOutput', false);
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

% ---- the event channels and the channel list ---------------------------
if readChannels
    A.events = ndi.vintage.ingestedEventChannels(statements, bodies);
end
if ~readChannels
    % the clock and extent only (see 'Channels' above)
elseif isKey(A.bodies, 'channel_list.bin')
    tname = [ndi.file.temp_name() '.bin'];
    writeMember(S, A.bodies('channel_list.bin').doc, 'body_data_0', tname);
    c = onCleanup(@() deleteIfThere(tname));
    A.channels = ndi.file.type.mfdaq_epoch_channel(tname).channel_information;
else
    groups = {};
    names = A.bodies.keys;
    for k = 1:numel(names)
        b = A.bodies(names{k});
        if strcmp(b.kind, 'sampled_body')
            groups{end+1} = b.doc.document_properties; %#ok<AGROW>
        end
    end
    A.channels = ndi.vintage.ingestedChannelList(groups, A.events);
end


% ---- the epoch's clock(s) and extent -----------------------------------
used = {};
for k = 1:numel(statements)
    used = [used, ndi.v2.edgeIds(statements{k}.document_properties, 'time_reference_id')]; %#ok<AGROW>
end
% the recordings' anchors in the order they name them (v1's clock order),
% then the rest (private/anchorOrder)
order = anchorOrder(anchorIds, used);
for k = order
    [ok, clk, t0, t1] = anchorClockExtent(anchors{k}.document_properties);
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
