function d = timeReference(t, sourceText, tz, tolerance, duration, sid)
%TIMEREFERENCE An absolute (UTC) time reference for a source wall-clock time.
%
%   D = timeReference(T, SOURCETEXT, TZ, TOLERANCE, DURATION, SID) builds an
%   absolute_time_reference at the wall-clock datetime T, read in the IANA
%   time zone TZ, with SOURCETEXT -- the time exactly as the source wrote it
%   -- as its `source_value`. TOLERANCE is [minus plus] seconds ([] = exact):
%   a hand-written time to the minute is [60 60] and approximate, never
%   given seconds it did not have. DURATION is seconds ([] = an instant).

arguments
    t (1,1) datetime
    sourceText {mustBeText}
    tz {mustBeText}
    tolerance
    duration
    sid {mustBeText}
end
t.TimeZone = tz;
u = t;
u.TimeZone = 'UTC';
d = did2.build.absoluteTimeReference(char(u, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''), ...
    'SourceValue', char(sourceText), 'SourceTimezone', char(tz), ...
    'Approximate', ~isempty(tolerance), 'Tolerance', tolerance, ...
    'Duration', duration, 'SessionId', char(sid));
end
