function M = ingestedArchiveSeries(bodies)
%INGESTEDARCHIVESERIES An ingested epoch's v2 data bodies, by the v1 file series each carries.
%
%   M = ndi.vintage.ingestedArchiveSeries(BODIES) takes BODIES, a cell of the
%   epoch's data bodies (ndi.document), and returns a containers.Map from
%   the v1 series name (`data_body.filename`: `ai_group1_seg.nbf_#`,
%   `channel_list.bin`, ...) to a struct with fields
%
%     doc      the body (ndi.document)
%     kind     'sampled_body' or 'opaque_body' (its class), or 'split_time'
%     n        samples along time ([] when not stated)
%     chunk    samples per member ([] when not stated)
%     members  the number of body_data_<k> members
%     docs     (every entry) a cell of the bodies, in column order
%     numbers  (every entry) the time channel each of DOCS holds ([] unless
%              'split_time')
%
%   A body whose filename is no archive series is skipped; a series met twice
%   keeps the first body, except a split time group's:
%
%   A TIME GROUP OF SEVERAL TIME CHANNELS. Decided by Jess Haley, 2026-11-19
%   [time group with several time channels split] (did-schema
%   did_v2_standing_wiring_plan.md): "each time channel becomes its own keyed
%   `time` value" (ndi.migrate.internal.ingestedArchiveBodies). Each is a
%   sampled_body whose filename is the v1 time group's
%   (`ti_group<g>_seg.nbf_#`) and whose condition "time channel"
%   (EMPTY:0000374) counts its time channel. Those bodies are one entry,
%   kind 'split_time': DOCS sorted by time channel (the order NDI's writer
%   lists them, and the column order of the v1 file), NUMBERS their time
%   channels, DOC the first, n, chunk and members the first's. The v1
%   segment is rebuilt from them by ndi.vintage.ingestedSplitTime.
%
%   Used by ndi.vintage.ingestedArchive and ndi.vintage.ingestedArchives
%   (private/archiveOf), so both see the same series.
%
%   See also ndi.vintage.ingestedArchive, ndi.vintage.ingestedSplitTime,
%            ndi.vintage.ingestedArchiveFile.

arguments
    bodies cell
end

M = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    p = bodies{k}.document_properties;
    fn = bodyFilename(p);
    if isempty(seriesKind(fn))
        continue;   % not an archive series
    end
    [n, chunk] = timeExtent(p);
    kind = p.document_class.class_name;
    tc = splitTimeChannel(p, fn, kind);
    e = struct('doc', bodies{k}, 'kind', kind, 'n', n, 'chunk', chunk, ...
        'members', numel(memberNames(p)), 'docs', {bodies(k)}, 'numbers', []);
    if ~isfinite(tc)
        if ~isKey(M, fn); M(fn) = e; end   % a shared body met twice: the first
        continue;
    end
    e.kind = 'split_time';
    e.numbers = tc;
    if ~isKey(M, fn)
        M(fn) = e;
        continue;
    end
    old = M(fn);
    if ~strcmp(old.kind, 'split_time') || any(old.numbers == tc)
        continue;   % a series met twice, or a split channel met twice
    end
    docs = [old.docs, bodies(k)];
    numbers = [old.numbers, tc];
    [numbers, o] = sort(numbers);
    docs = docs(o);
    first = docs{1}.document_properties;
    [n, chunk] = timeExtent(first);
    M(fn) = struct('doc', docs{1}, 'kind', 'split_time', 'n', n, 'chunk', chunk, ...
        'members', numel(memberNames(first)), 'docs', {docs}, 'numbers', numbers);
end
end

% =====================================================================

function tc = splitTimeChannel(p, fn, kind)
% the time channel a split time group's body holds (its condition "time
% channel", EMPTY:0000374, count); NaN for any other body
tc = NaN;
if ~strcmp(kind, 'sampled_body') || isempty(regexp(fn, '^ti_group\d+_seg\.nbf_#$', 'once'))
    return;
end
if ~isfield(p.data_body, 'conditions'); return; end
cs = asCell(p.data_body.conditions);
for c = 1:numel(cs)
    x = cs{c};
    if ~isstruct(x) || ~isfield(x, 'variable') || ~isstruct(x.variable) ...
            || ~isfield(x.variable, 'node') || ~strcmp(char(x.variable.node), 'EMPTY:0000374')
        continue;
    end
    v = [];
    if isfield(x, 'count'); v = x.count; end
    if isempty(v) && isfield(x, 'numeric'); v = x.numeric; end
    if isnumeric(v) && isscalar(v) && isfinite(v)
        tc = double(v);
        return;
    end
end
end

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

function c = asCell(x)
if iscell(x); c = x; elseif isstruct(x); c = num2cell(x); else; c = {}; end
end
