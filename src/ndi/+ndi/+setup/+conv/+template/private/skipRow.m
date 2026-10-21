function r = skipRow(r, where, why)
%SKIPROW Count a source item a stage did not turn into documents, with why.
%
%   R = skipRow(R, WHERE, WHY): a skip is a decision (the source says
%   nothing, so nothing is written -- missing is not a value), never an
%   error. It is counted and listed, never silently dropped.

arguments
    r (1,1) struct
    where {mustBeText}
    why {mustBeText}
end
r.skipped = r.skipped + 1;
r.skippedList{end+1} = sprintf('%s: %s', char(where), char(why));
end
