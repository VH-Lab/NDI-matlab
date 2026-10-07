function r = timeOf(container, refDoc, depth, cache)
%TIMEOF A time reference, read and resolved to wall-clock time where it can be.
%
%   R = ndi.v2.timeOf(CONTAINER, REFDOC) returns a struct:
%     kind          'absolute' or 'relative'
%     start, end    datetime (UTC): the instant or interval, resolved through
%                   the referent chain when the reference is relative (NaT
%                   when it cannot be)
%     start_offset, end_offset  seconds from the referent (relative only)
%     relation      the OWL-Time relation to the referent, when given
%     clock         the clock the offsets are on
%     referent_id   the document the reference is relative to
%     approximate   true when the start or end is marked approximate
%     tolerance     [minus plus] seconds of the start (NaN when none)
%     resolved_by   'value', 'offset', 'relation' (the referent's own extent)
%                   or '' (not resolved)
%
%   A relative reference resolves through its referent's own time
%   references (a session's, an epoch's, a statement's), up to 8 levels.
%
%   R = ndi.v2.timeOf(CONTAINER, REFDOC, DEPTH, CACHE): CACHE, a
%   containers.Map, holds documents under 'doc:<id>' (ndi.v2.getDocuments
%   fills it) and each referent's resolved anchor under 'anchor:<id>', so a
%   referent shared by many references is read and resolved once
%   (ndi.v2.timesOf).

if nargin < 3, depth = 0; end
if nargin < 4, cache = []; end
p = ndi.v2.props(refDoc);
k = char(p.document_class.class_name);
r = struct('kind', '', 'start', NaT('TimeZone', 'UTC'), 'end', NaT('TimeZone', 'UTC'), ...
    'start_offset', NaN, 'end_offset', NaN, 'relation', '', 'clock', '', 'referent_id', '', ...
    'approximate', false, 'tolerance', [NaN NaN], 'resolved_by', '');
v = ndi.v2.blockOf(p, k, 'value', struct());
if strcmp(k, 'absolute_time_reference')
    r.kind = 'absolute';
    st = getOr(v, 'start', struct());
    r.start = ndi.v2.parseUtc(getOr(st, 'utc', ''));
    r.approximate = logical(getOr(st, 'approximate', false));
    r.tolerance = tol(getOr(st, 'tolerance', []));
    en = endOf(v);
    r.end = ndi.v2.parseUtc(getOr(en, 'utc', ''));
    du = getOr(v, 'duration', struct());
    if isnat(r.end) && ~isempty(getOr(du, 'seconds', []))
        r.end = r.start + seconds(double(du.seconds));
    end
    r.approximate = r.approximate || logical(getOr(en, 'approximate', false));
    if ~isnat(r.start), r.resolved_by = 'value'; end
    return;
end
r.kind = 'relative';
r.relation = ndi.v2.termName(getOr(v, 'relation', ''));
r.clock = ndi.v2.termName(getOr(v, 'clock', ''));
ids = ndi.v2.edgeIds(p, 'referent_id');
if ~isempty(ids), r.referent_id = ids{1}; end
st = getOr(v, 'start', struct());
r.start_offset = double(getOr(st, 'seconds', NaN));
r.tolerance = tol(getOr(st, 'tolerance', []));
r.approximate = logical(getOr(st, 'approximate', false));
en = endOf(v);
r.end_offset = double(getOr(en, 'seconds', NaN));
du = getOr(v, 'duration', struct());
if isnan(r.end_offset) && ~isnan(r.start_offset) && ~isempty(getOr(du, 'seconds', []))
    r.end_offset = r.start_offset + double(du.seconds);
end
if isempty(r.referent_id) || depth >= 8
    return;
end
if ~isempty(cache) && isKey(cache, ['anchor:' r.referent_id])
    anchor = cache(['anchor:' r.referent_id]);
else
    ref = docOf(container, r.referent_id, cache);
    if isempty(ref), return; end
    anchor = anchorOf(container, ref, depth, cache);
    if ~isempty(cache), cache(['anchor:' r.referent_id]) = anchor; end
end
if isempty(anchor) || isnat(anchor.start)
    return;
end
if ~isnan(r.start_offset)
    r.start = anchor.start + seconds(r.start_offset);
    if ~isnan(r.end_offset), r.end = anchor.start + seconds(r.end_offset); end
    r.resolved_by = 'offset';
else
    r.start = anchor.start;          % a relation alone: the referent's own extent
    r.end = anchor.end;
    r.resolved_by = 'relation';
    r.approximate = true;
end
end

function a = anchorOf(container, refDoc, depth, cache)
% the referent's own time: its first time reference that resolves
a = [];
p = ndi.v2.props(refDoc);
if any(strcmp(ndi.v2.classChain(p), 'time_reference'))
    a = ndi.v2.timeOf(container, refDoc, depth + 1, cache);
    return;
end
ids = ndi.v2.edgeIds(p, 'time_reference_id');
for i = 1:numel(ids)
    d = docOf(container, ids{i}, cache);
    if isempty(d), continue; end
    t = ndi.v2.timeOf(container, d, depth + 1, cache);
    if ~isnat(t.start)
        a = t;
        return;
    end
end
end

function d = docOf(container, id, cache)
% a document by id: from CACHE when it holds it (or held its absence)
if ~isempty(cache) && isKey(cache, ['doc:' id])
    d = cache(['doc:' id]);
    return;
end
d = ndi.v2.getDocument(container, id);
if ~isempty(cache), cache(['doc:' id]) = d; end
end

function v = getOr(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s(1).(name))
    v = s(1).(name);
end
end

function t = tol(x)
t = [NaN NaN];
if isstruct(x) && ~isempty(x)
    if isfield(x, 'minus') && ~isempty(x.minus), t(1) = double(x.minus); end
    if isfield(x, 'plus') && ~isempty(x.plus), t(2) = double(x.plus); end
end
end

function e = endOf(v)
% the value's `end` cell (a reserved word: a JSON reader may rename it)
e = struct();
for n = {'end', 'xEnd', 'x_end', 'end_'}
    if isstruct(v) && isfield(v, n{1}) && ~isempty(v(1).(n{1}))
        e = v(1).(n{1});
        return;
    end
end
end
