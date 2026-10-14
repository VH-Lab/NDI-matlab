function t = wallClock(t, tz)
% The source's wall-clock time with no zone attached: a value that already
% carries a zone is first expressed in TZ.
if ~isempty(t.TimeZone)
    t.TimeZone = tz;
    t.TimeZone = '';
end
end
