function [v, applied, note, line] = applyCorrection(x, have, where)
%APPLYCORRECTION One of the spec's named corrections, applied to one source value.
%
%   [V, APPLIED, NOTE, LINE] = applyCorrection(X, HAVE, WHERE) applies the spec
%   correction X (its `key`, `column`, `value`, `was` and `reason`) to HAVE,
%   the value the source holds now, at WHERE (text naming the cell, for the
%   report: 'session_0001 worm0001'). Tenet T14, "A correction is named and
%   travels with the value" (the Haley import's decision #111, where this
%   function comes from):
%
%     * it is applied ONLY while the source still reads `was`, so a source
%       fixed upstream is not corrected twice: V is X.value, typed as HAVE is,
%       and APPLIED is true;
%     * otherwise it is refused: V is HAVE unchanged, APPLIED false;
%     * NOTE is the one form a document carries it in, '' when refused:
%       "Corrected from <was>: <reason> (correction <key>)". The rejected value
%       is never put in `source_value` (that is the source's form of the value
%       USED);
%     * LINE is the report line either way (the caller files it under its
%       checks' `corrected` or `correctionNotApplied`).
%
%   `was` is compared by HAVE's type: text (trimmed, exact), a number (to
%   1e-9, relative), a datetime (to the minute; `was` is 'yyyy-MM-ddTHH:mm',
%   or two of them, [earliest latest], when the source reads a different time
%   in each row, as a fill-down does). An empty or null `was` means the source
%   cell is blank (NaN, NaT or ''). A correction with no `was` is refused: it
%   cannot be checked. A null `value` is a blank (NaN, NaT or '').

arguments
    x (1,1) struct
    have
    where {mustBeText}
end
key = char(string(x.key));
col = '';
if isfield(x, 'column'), col = char(string(x.column)); end
v = have;
applied = false;
note = '';
if ~isfield(x, 'was')
    line = sprintf('%s: %s %s: the correction names no `was`, so it cannot be checked; left as it is', ...
        key, where, col);
    return;
end
was = x.was;
newValue = [];
if isfield(x, 'value'), newValue = x.value; end
if isdatetime(have)
    [match, wasText] = sameTime(have, was);
    new = NaT;
    if ~isempty(newValue)
        new = datetime(char(newValue), 'InputFormat', 'yyyy-MM-dd''T''HH:mm');
        if ~isempty(have.TimeZone), new.TimeZone = have.TimeZone; end
    end
    haveText = timeText(have);
    newText = timeText(new);
elseif isnumeric(have) || islogical(have)
    have = double(have);
    if isempty(was)
        match = isnan(have);
        wasText = 'blank';
    else
        w = double(was);
        match = ~isnan(have) && abs(have - w) <= 1e-9 * max(1, abs(w));
        wasText = sprintf('%g', w);
    end
    new = NaN;
    if ~isempty(newValue), new = double(newValue); end
    haveText = sprintf('%g', have);
    newText = sprintf('%g', new);
else
    h = cellText(have);
    if isempty(was)
        match = isempty(h);
        wasText = 'blank';
    else
        wasText = strtrim(char(string(was)));
        match = strcmp(h, wasText);
    end
    new = '';
    if ~isempty(newValue), new = char(string(newValue)); end
    haveText = h;
    newText = new;
end
if ~match
    line = sprintf('%s: %s %s reads "%s", not "%s"; left as it is', key, where, col, haveText, wasText);
    return;
end
v = new;
applied = true;
note = sprintf('Corrected from %s: %s (correction %s)', wasText, strtrim(char(string(x.reason))), key);
line = sprintf('%s: %s %s "%s" -> "%s"', key, where, col, haveText, newText);
end

function [match, wasText] = sameTime(have, was)
% HAVE (to the minute) against WAS: one time, or [earliest latest]
arguments
    have (1,1) datetime
    was
end
if isempty(was)
    match = isnat(have);
    wasText = 'blank';
    return;
end
was = cellstr(string(was));
t = datetime(was, 'InputFormat', 'yyyy-MM-dd''T''HH:mm');
if ~isempty(have.TimeZone), t.TimeZone = have.TimeZone; end
h = dateshift(have, 'start', 'minute');
if isscalar(t)
    match = ~isnat(h) && h == t;
    wasText = was{1};
else
    match = ~isnat(h) && h >= min(t) && h <= max(t);
    wasText = sprintf('%s to %s', was{1}, was{end});
end
end

function s = timeText(t)
arguments
    t (1,1) datetime
end
if isnat(t)
    s = 'blank';
else
    s = char(t, 'yyyy-MM-dd''T''HH:mm');
end
end

function s = cellText(v)
% a source cell as trimmed text ('' for a missing one)
arguments
    v
end
if iscell(v)
    if isempty(v), v = ''; else, v = v{1}; end
end
if isstring(v) && any(ismissing(v)), v = ''; end
s = strtrim(char(string(v)));
end
