function d = utcReference(t0, tz, sid, options)
%UTCREFERENCE An absolute (UTC) time reference from a source's wall-clock time.
%
%   D = ndi.setup.V2.utcReference(T0, TZ, SID) builds an
%   absolute_time_reference (did2.build.absoluteTimeReference) for the
%   wall-clock datetime T0, read in the IANA time zone TZ ('America/New_York',
%   'UTC'), in the session SID. The reference holds the instant in UTC and
%   keeps the source's own form beside it: `source_value` (T0 as the source
%   wrote it) and `source_timezone` TZ. A T0 that already carries a time zone
%   is first expressed in TZ.
%
%   Options:
%     'Format'       the precision the source wrote T0 at, as a datetime
%                    format: `source_value` is T0 in it, so a hand-written
%                    time to the minute is never given seconds it did not
%                    have (default 'yyyy-MM-dd''T''HH:mm:ss')
%     'SourceText'   the source's own text for T0, used verbatim as
%                    `source_value` instead of 'Format' ('' = use 'Format')
%     'Tolerance'    [minus plus] seconds: the time is approximate within
%                    it; [] = exact (the default). 'estimated' = approximate
%                    with NO known bound (a time the source filled in by rule).
%                    A hand-written time to the minute is [60 60].
%     'End'          the wall-clock end of a WINDOW from T0 (default NaT: an
%                    instant). Its `duration` is the elapsed seconds, read in
%                    TZ, so a window across a daylight-saving change is an
%                    hour shorter or longer than the clocks say.
%     'EndFormat'    'Format' for the end (default: 'Format')
%     'EndTolerance' 'Tolerance' for the end. The duration's bound follows:
%                    shortest when the start is late and the end early
%                    (minus = start.plus + end.minus), longest the other way
%                    round; approximate when either end is.
%     'Duration'     seconds, for an instant with a known length and no end
%                    time (a recording's start and its length); ignored
%                    with 'End'
%
%   This is the Haley import's rule (decisions #54d, #87), made public for
%   every V2 import: ndi.setup.conv.haley and ndi.setup.conv.template both
%   build their absolute times here.
%
%   See also did2.build.absoluteTimeReference, did2.build.relativeTimeReference.

arguments
    t0 (1,1) datetime
    tz {mustBeTextScalar, mustBeNonzeroLengthText}
    sid {mustBeTextScalar}
    options.Format {mustBeTextScalar} = 'yyyy-MM-dd''T''HH:mm:ss'
    options.SourceText {mustBeTextScalar} = ''
    options.Tolerance = []
    options.End (1,1) datetime = NaT
    options.EndFormat {mustBeTextScalar} = ''
    options.EndTolerance = []
    options.Duration = []
end
tz = char(tz);
t0 = wallClock(t0, tz);
[a0, tol0] = bound(options.Tolerance);
source = char(options.SourceText);
if isempty(source)
    source = char(t0, char(options.Format));
end
args = {'SourceValue', source, 'SourceTimezone', tz, 'Approximate', a0, 'Tolerance', tol0};
t1 = options.End;
if ~isnat(t1)
    t1 = wallClock(t1, tz);
    fmt1 = char(options.EndFormat);
    if isempty(fmt1), fmt1 = char(options.Format); end
    [a1, tol1] = bound(options.EndTolerance);
    s0 = tol0; if isempty(s0), s0 = [0 0]; end
    e1 = tol1; if isempty(e1), e1 = [0 0]; end
    durTol = [s0(2) + e1(1), s0(1) + e1(2)];
    if all(durTol == 0), durTol = []; end
    args = [args, {'Duration', elapsed(t0, t1, tz), ...
        'DurationApproximate', ~isempty(durTol) || a0 || a1, 'DurationTolerance', durTol, ...
        'End', utcText(t1, tz), 'EndSourceValue', char(t1, fmt1), 'EndSourceTimezone', tz, ...
        'EndApproximate', a1, 'EndTolerance', tol1}];
elseif ~isempty(options.Duration)
    args = [args, {'Duration', options.Duration}];
end
d = did2.build.absoluteTimeReference(utcText(t0, tz), 'SessionId', char(sid), args{:});
end

function t = wallClock(t, tz)
% the wall-clock time with no zone attached; one that carries a zone is
% first expressed in TZ
arguments
    t (1,1) datetime
    tz (1,:) char
end
if ~isempty(t.TimeZone)
    t.TimeZone = tz;
    t.TimeZone = '';
end
end

function [approx, tol] = bound(tol)
arguments
    tol
end
if ischar(tol) || isstring(tol)     % 'estimated': approximate, bound unknown
    approx = true;
    tol = [];
else
    approx = ~isempty(tol);
end
end

function s = elapsed(t0, t1, tz)
% seconds from wall-clock T0 to T1, both read in TZ
arguments
    t0 (1,1) datetime
    t1 (1,1) datetime
    tz (1,:) char
end
a = t0; b = t1;
a.TimeZone = tz;
b.TimeZone = tz;
s = seconds(b - a);
end

function s = utcText(t, tz)
arguments
    t (1,1) datetime
    tz (1,:) char
end
t.TimeZone = tz;
t.TimeZone = 'UTC';
s = char(t, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
end
