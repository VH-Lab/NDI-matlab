function [text, note, r] = correctedText(cfg, r, session, rowId, column, text)
%CORRECTEDTEXT A source cell after the spec's named corrections.
%
%   [TEXT, NOTE, R] = correctedText(CFG, R, SESSION, ROWID, COLUMN, TEXT)
%   applies every correction in CFG.corrections naming this cell (its
%   `session`, `row` -- the row's id column value -- and `column`) through
%   applyCorrection, the ONE correction function: applied only while the
%   source still reads the correction's `was`, and recorded either way in
%   R.corrected / R.notCorrected. NOTE is the text the document carries,
%   "Corrected from <was>: <reason> (correction <key>)", '' when none was
%   applied. The source's own value is never put in `source_value` once
%   corrected: `source_value` holds the value USED, the note what it was.

arguments
    cfg (1,1) struct
    r (1,1) struct
    session {mustBeText}
    rowId {mustBeText}
    column {mustBeText}
    text {mustBeText}
end
note = '';
if ~isfield(cfg, 'corrections') || isempty(cfg.corrections)
    return;
end
c = cfg.corrections;
if isstruct(c), c = num2cell(c); end
for k = 1:numel(c)
    x = c{k};
    if ~strcmp(fieldText(x, 'session'), session) || ~strcmp(fieldText(x, 'row'), rowId) ...
            || ~strcmp(fieldText(x, 'column'), column)
        continue;
    end
    [text, applied, n, line] = applyCorrection(x, text, sprintf('%s %s', session, rowId));
    text = char(string(text));
    if applied
        r.corrected{end+1} = line;
        note = n;
    else
        r.notCorrected{end+1} = line;
    end
end
end

function s = fieldText(x, name)
arguments
    x (1,1) struct
    name {mustBeText}
end
s = '';
if isfield(x, name) && ~isempty(x.(name))
    s = strtrim(char(string(x.(name))));
end
end
