function t = parseUtc(s)
%PARSEUTC A V2 `utc` timestamp string as a datetime in UTC (NaT when empty or unreadable).

t = NaT('TimeZone', 'UTC');
if isempty(s), return; end
s = char(s);
fmts = {'yyyy-MM-dd''T''HH:mm:ss.SSSXXX', 'yyyy-MM-dd''T''HH:mm:ssXXX', ...
    'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'yyyy-MM-dd''T''HH:mm:ss''Z''', ...
    'yyyy-MM-dd''T''HH:mm:ss.SSS', 'yyyy-MM-dd''T''HH:mm:ss'};
for k = 1:numel(fmts)
    try
        t = datetime(s, 'InputFormat', fmts{k}, 'TimeZone', 'UTC');
        return;
    catch
    end
end
try
    t = datetime(s, 'TimeZone', 'UTC');
catch
end
end
