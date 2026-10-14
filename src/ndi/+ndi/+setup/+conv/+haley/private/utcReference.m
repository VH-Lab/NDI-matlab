function d = utcReference(t0, tol0, fmt0, t1, tol1, fmt1, hasEnd, tz, sid)
% A window from T0 (wall clock) to T1 (when HASEND), each with its bound
% [minus plus] seconds ([] = exact) and the precision it was written at (FMT,
% so source_value does not invent seconds a hand-written time never had). The
% duration's bound follows: it is shortest when the start is late and the end
% early (minus = start.plus + end.minus), longest the other way round.
% A bound of 'estimated' is an approximate time with NO known bound (a time
% the source filled in by rule, decision #54d): approximate, no tolerance, and
% a duration it touches is approximate with no tolerance too.
[a0, tol0] = bound(tol0);
args = {'SourceValue', char(t0, fmt0), 'SourceTimezone', tz, ...
    'Approximate', a0, 'Tolerance', tol0};
if hasEnd
    [a1, tol1] = bound(tol1);
    s0 = tol0; if isempty(s0), s0 = [0 0]; end
    e1 = tol1; if isempty(e1), e1 = [0 0]; end
    durTol = [s0(2) + e1(1), s0(1) + e1(2)];
    if all(durTol == 0), durTol = []; end
    args = [args, {'Duration', elapsed(t0, t1, tz), ...
        'DurationApproximate', ~isempty(durTol) || a0 || a1, 'DurationTolerance', durTol, ...
        'End', utcText(t1, tz), 'EndSourceValue', char(t1, fmt1), 'EndSourceTimezone', tz, ...
        'EndApproximate', a1, 'EndTolerance', tol1}];
end
d = did2.build.absoluteTimeReference(utcText(t0, tz), 'SessionId', sid, args{:});
end

function [approx, tol] = bound(tol)
if ischar(tol) || isstring(tol)     % 'estimated': approximate, bound unknown
    approx = true;
    tol = [];
else
    approx = ~isempty(tol);
end
end

function s = elapsed(t0, t1, tz)
% seconds from wall-clock T0 to T1, both read in TZ: a window across a
% daylight-saving change is an hour shorter or longer than the clocks say
a = t0; b = t1;
if isempty(a.TimeZone), a.TimeZone = tz; end
if isempty(b.TimeZone), b.TimeZone = tz; end
s = seconds(b - a);
end
