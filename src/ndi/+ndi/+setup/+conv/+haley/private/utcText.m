function s = utcText(t, tz)
arguments
    t
    tz {mustBeText}
end
t.TimeZone = tz;
t.TimeZone = 'UTC';
s = char(t, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
end
