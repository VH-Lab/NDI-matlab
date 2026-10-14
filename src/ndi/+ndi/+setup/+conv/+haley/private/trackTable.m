function T = trackTable(file)
%TRACKTABLE The track table in FILE (<bodyPart>.mat), loaded once per file:
%   the tables are up to GBs and every session of a folder, and stages 10
%   and 11, read the same one.
persistent cacheFile cacheStamp cacheTable
info = dir(file);
if ~isempty(cacheFile) && strcmp(cacheFile, file) && isequal(cacheStamp, info.datenum)
    T = cacheTable;
    return;
end
S = load(file);
f = fieldnames(S);
T = S.(f{1});
cacheFile = file; cacheStamp = info.datenum; cacheTable = T;
end
