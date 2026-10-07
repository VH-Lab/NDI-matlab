function [keep, info] = timeFilter(container, docs, filt, tolerant, cache)
%TIMEFILTER Which documents' times meet the time filters in FILT.
%
%   [KEEP, INFO] = ndi.v2.timeFilter(CONTAINER, DOCS, FILT, TOLERANT, CACHE)
%   reads the time references (time_reference_id) of the statement or
%   relation documents DOCS, in batches (ndi.v2.timesOf, CACHE shared), and
%   keeps a document when any of its references meets every time filter in
%   FILT -- a struct with any of:
%
%     at        t           the time covers instant t
%     during    [t1 t2]     the time overlaps the window; a date ('2023-11-16')
%                           or a month ('2023-11') is the whole of it
%     before    t           it ends before t
%     after     t           it starts after t
%     duration  '>=3h'      how long it lasted: > >= < <= and a number with
%                           s, min, h or d (seconds when no unit)
%
%   A time t is a datetime (with a zone, used as is; without one, read in
%   the reference's own zone) or text: '2023-11-16T14:00', '2023-11-16
%   14:00', '2023-11-16'; text ending in Z or an offset (+08:00) is that
%   zone, other text is read in the zone the lab wrote the reference in
%   (its source_timezone). A reference whose zone is not recorded cannot be
%   compared with such text, and is counted, not matched.
%
%   TOLERANT (default false): a time also matches when its tolerance makes
%   a match possible (a transfer stated at 14:03 that may have been up to 5
%   min earlier is 'at' 14:00).
%
%   A reference that only orders the time against its anchor ("before the
%   seeding", no offset) is a bound: 'before' and 'after' use it when it
%   decides them; 'at', 'during' and 'duration' cannot, and do not match.
%   A reference that cannot be resolved (its anchor not reachable, or with
%   no time of its own) does not match.
%
%   INFO counts what could not be compared: unresolved (references with no
%   time), nozone (text with no zone to read it in), bound (bounds that
%   could not decide), and, for messages, docs (DOCS with no time at all).

if nargin < 4 || isempty(tolerant), tolerant = false; end
if nargin < 5 || ~isa(cache, 'containers.Map'), cache = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
names = intersect({'at', 'during', 'before', 'after', 'duration'}, fieldnames(filt), 'stable');
names = names(cellfun(@(n) ~isempty(filt.(n)), names));
keep = true(1, numel(docs));
info = struct('unresolved', 0, 'nozone', 0, 'bound', 0, 'docs', 0);
if isempty(names), return; end
refs = cell(1, numel(docs));
for i = 1:numel(docs)
    refs{i} = ndi.v2.edgeIds(ndi.v2.props(docs{i}), 'time_reference_id');
end
all_ = unique([refs{:}]);
times = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(all_), times = ndi.v2.timesOf(container, all_, cache); end
for i = 1:numel(docs)
    if isempty(refs{i})
        info.docs = info.docs + 1;
        keep(i) = false;
        continue;
    end
    ok = false;
    for r = 1:numel(refs{i})
        if ~isKey(times, refs{i}{r})
            info.unresolved = info.unresolved + 1;
            continue;
        end
        [m, why] = meets(times(refs{i}{r}), filt, names, tolerant);
        if ~isempty(why), info.(why) = info.(why) + 1; end
        if m, ok = true; break; end
    end
    keep(i) = ok;
end
end

% -------------------------------------------------------------------------

function [m, why] = meets(t, filt, names, tolerant)
% does the one time T meet every filter
m = false; why = '';
if isnat(t.start)
    why = 'unresolved';
    return;
end
isBound = strcmp(t.resolved_by, 'relation');
s = t.start; e = t.end;
if isnat(e), e = s; end
tolS = zeroNaN(t.tolerance); tolE = zeroNaN(t.end_tolerance);
if all(tolE == 0), tolE = tolS; end
if ~tolerant, tolS = [0 0]; tolE = [0 0]; end
for k = 1:numel(names)
    n = names{k};
    switch n
        case 'duration'
            if isBound, why = 'bound'; return; end
            [op, secs] = parseDuration(filt.duration);
            lo = seconds((e - tolE(1)) - (s + tolS(2)));
            hi = seconds((e + tolE(2)) - (s - tolS(1)));
            if ~tolerant, lo = seconds(e - s); hi = lo; end
            if ~any(applyOp([lo hi], secs, op)), return; end
        otherwise
            [q, ok] = queryTime(filt.(n), n, t.timezone);
            if ~ok, why = 'nozone'; return; end
            if isBound
                [decided, yes] = boundDecides(t, n, q);
                if ~decided, why = 'bound'; return; end
                if ~yes, return; end
                continue;
            end
            sLo = s - seconds(tolS(1)); eHi = e + seconds(tolE(2));
            sHi = s + seconds(tolS(2)); eLo = e - seconds(tolE(1));
            switch n
                case 'at',     hit = sLo <= q(1) && q(1) <= eHi;
                case 'during', hit = sLo <= q(2) && eHi >= q(1);
                case 'before', hit = eLo < q(1);
                case 'after',  hit = sHi > q(1);
            end
            if ~hit, return; end
    end
end
m = true;
end

function [decided, yes] = boundDecides(t, n, q)
% a time known only as before / after / within its anchor (t.start, t.end
% are the anchor's): decide 'before' and 'after' when the bound does
decided = false; yes = false;
rel = lower(t.relation);
aS = t.start; aE = t.end;
if isnat(aE), aE = aS; end
switch n
    case 'before'
        if any(strcmp(rel, {'before', 'intervalbefore', 'intervalmeets', 'meets'}))
            if aS <= q(1), decided = true; yes = true; end      % it ended before the anchor began
        elseif any(strcmp(rel, {'during', 'intervalduring', 'intervalin', 'inside', 'intervalstarts', 'intervalfinishes'}))
            if aE < q(1), decided = true; yes = true; elseif aS >= q(1), decided = true; end
        elseif any(strcmp(rel, {'after', 'intervalafter', 'intervalmetby', 'metby'}))
            if aE >= q(1), decided = true; end                  % it began after the anchor ended
        end
    case 'after'
        if any(strcmp(rel, {'after', 'intervalafter', 'intervalmetby', 'metby'}))
            if aE >= q(1), decided = true; yes = true; end
        elseif any(strcmp(rel, {'during', 'intervalduring', 'intervalin', 'inside', 'intervalstarts', 'intervalfinishes'}))
            if aS > q(1), decided = true; yes = true; elseif aE <= q(1), decided = true; end
        elseif any(strcmp(rel, {'before', 'intervalbefore', 'intervalmeets', 'meets'}))
            if aS <= q(1), decided = true; end
        end
end
end

function [q, ok] = queryTime(v, n, tz)
% a filter's time(s) as UTC datetimes: q(1) (and q(2) for 'during')
ok = true;
if strcmp(n, 'during')
    if iscell(v) && numel(v) == 2
        [a, ok1] = oneTime(v{1}, tz, 'start'); [b, ok2] = oneTime(v{2}, tz, 'end');
    elseif isa(v, 'datetime') && numel(v) == 2
        [a, ok1] = oneTime(v(1), tz, 'start'); [b, ok2] = oneTime(v(2), tz, 'end');
    else
        [a, ok1] = oneTime(v, tz, 'start'); [b, ok2] = oneTime(v, tz, 'end');
    end
    q = [a b]; ok = ok1 && ok2;
else
    [q, ok] = oneTime(v, tz, 'start');
end
end

function [d, ok] = oneTime(v, tz, edge)
% one time as UTC. A date or a month of text is its first (EDGE 'start')
% or last (EDGE 'end') instant.
ok = true;
if isa(v, 'datetime')
    d = v;
    if isempty(d.TimeZone)
        if isempty(tz), ok = false; d = NaT('TimeZone', 'UTC'); return; end
        d.TimeZone = tz;
    end
    d.TimeZone = 'UTC';
    return;
end
v = strtrim(char(v));
zoned = ~isempty(regexp(v, '(Z|[+-]\d\d:?\d\d)$', 'once'));
if ~zoned && isempty(tz)
    ok = false; d = NaT('TimeZone', 'UTC'); return;
end
whole = '';
if ~isempty(regexp(v, '^\d{4}-\d{2}$', 'once')), whole = 'month'; v = [v '-01']; end
if ~isempty(regexp(v, '^\d{4}-\d{2}-\d{2}$', 'once')) && isempty(whole), whole = 'day'; end
if zoned
    z = regexp(v, '(Z|[+-]\d\d:?\d\d)$', 'match', 'once');
    v = strtrim(v(1:end - numel(z)));
    if strcmp(z, 'Z'), zone = 'UTC'; else, zone = z; end
else
    zone = tz;
end
fmts = {'yyyy-MM-dd''T''HH:mm:ss.SSS', 'yyyy-MM-dd''T''HH:mm:ss', 'yyyy-MM-dd''T''HH:mm', ...
    'yyyy-MM-dd HH:mm:ss.SSS', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd'};
d = NaT;
for k = 1:numel(fmts)
    try
        d = datetime(v, 'InputFormat', fmts{k}, 'TimeZone', zone);
        break;
    catch
    end
end
if isnat(d)
    error('ndi:v2:timeFilter:badTime', ...
        'Cannot read the time ''%s'': use e.g. ''2023-11-16T14:00'', ''2023-11-16'' or a datetime.', v);
end
if strcmp(edge, 'end')
    if strcmp(whole, 'day'), d = d + days(1) - seconds(1e-3); end
    if strcmp(whole, 'month'), d = d + calmonths(1) - seconds(1e-3); end
end
d.TimeZone = 'UTC';
end

function [op, secs] = parseDuration(v)
% '>=3h' -> '>=', 10800
t = regexp(strtrim(char(v)), '^(>=|<=|>|<|=)?\s*([0-9.eE+-]+)\s*([a-zA-Z]*)$', 'tokens', 'once');
if isempty(t) || isnan(str2double(t{2}))
    error('ndi:v2:timeFilter:badDuration', ...
        'Cannot read the duration ''%s'': use e.g. ''>=3h'', ''<30min'', ''>10s''.', char(v));
end
op = t{1};
if isempty(op), op = '='; end
x = str2double(t{2});
switch lower(t{3})
    case {'', 's', 'sec', 'secs', 'second', 'seconds'}, secs = x;
    case {'m', 'min', 'mins', 'minute', 'minutes'}, secs = 60 * x;
    case {'h', 'hr', 'hrs', 'hour', 'hours'}, secs = 3600 * x;
    case {'d', 'day', 'days'}, secs = 86400 * x;
    otherwise
        error('ndi:v2:timeFilter:badDuration', 'Unknown unit ''%s'' in ''%s'': s, min, h or d.', t{3}, char(v));
end
end

function tf = applyOp(vals, ref, op)
% is any of VALS (the possible range, ends inclusive) OP REF
lo = min(vals); hi = max(vals);
switch op
    case '>',  tf = hi > ref;
    case '>=', tf = hi >= ref;
    case '<',  tf = lo < ref;
    case '<=', tf = lo <= ref;
    case '=',  tf = lo <= ref && ref <= hi;
end
end

function t = zeroNaN(t)
t(isnan(t)) = 0;
end
