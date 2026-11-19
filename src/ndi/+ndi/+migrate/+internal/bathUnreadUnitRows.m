function rows = bathUnreadUnitRows(v1Body)
%BATHUNREADUNITROWS The mixture rows of a v1 stimulus_bath whose unit the generic stage does not read.
%
%   ROWS = ndi.migrate.internal.bathUnreadUnitRows(V1BODY) reads the bath's
%   `stimulus_bath.mixture_table` (a CSV with the header
%   ontologyName,name,value,ontologyUnit,unitName, names possibly quoted) and
%   returns, as 'name: value unit', each row whose unit name is "osm" or
%   "saturation" (edge blanks aside), then each ingredient row (not one named
%   pH, osm or osmolarity, which are the formulation's own fields) that states
%   a finite number in a unit that is not molar with a known SI prefix
%   (ndi.migrate.internal.bathPrefixedValue). {} when none, or when the table
%   is not text.
%
%   Decided by Jess Haley, 2026-11-03 [Dab bath units are Dabrowska's]
%   (did-schema docs/plans/did_v2_go_forward_class_audit.md): the Dabrowska
%   bath rows stated in "osm" (an amount; per litre or per kg is not stated)
%   and "saturation" (not a unit) are not read by the generic stage; it
%   carries those baths as v1 ([canonical absent only as needs info],
%   carry-155), and the Dabrowska dataset map states their meaning. The same
%   test as DID-matlab did2.convert.resolveDeferredBaths (unreadUnitRows).
%
%   Jess Haley, 2026-11-12 [bath concentration prefixes convert to molar]
%   (the same document): a bath concentration in a molar unit with a known SI
%   prefix gets its canonical value in M; a spelling that cannot be parsed is
%   carried for mapping. So an ingredient row in such a spelling (mg/ml, %,
%   a word) carries the bath too, as DID-matlab's resolveDeferredBaths does
%   (unparsedConcentrationRows, VH-Lab/DID-matlab PR #456).
%
%   See also ndi.migrate.local, ndi.migrate.internal.stimulusBathToBath,
%            ndi.migrate.internal.bathPrefixedValue.

UNREAD = {'osm', 'saturation'};
rows = {};
unparsed = {};
if ~(isstruct(v1Body) && isfield(v1Body, 'stimulus_bath') && isstruct(v1Body.stimulus_bath) ...
        && isfield(v1Body.stimulus_bath, 'mixture_table'))
    return;
end
raw = v1Body.stimulus_bath.mixture_table;
if ~(ischar(raw) || (isstring(raw) && isscalar(raw)))
    return;
end
lines = regexp(char(raw), '\r?\n', 'split');
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line); continue; end
    cols = csvFields(line);
    if numel(cols) < 5 || isempty(cols{1}); continue; end
    if strcmpi(cols{1}, 'ontologyName'); continue; end      % the header row
    if any(strcmp(strtrim(cols{5}), UNREAD))
        rows{end+1} = sprintf('%s: %s %s', cols{2}, cols{3}, strtrim(cols{5})); %#ok<AGROW>
        continue;
    end
    % [bath concentration prefixes convert to molar]: an ingredient amount in
    % a unit that cannot be read as molar (DID-matlab
    % unparsedConcentrationRows); pH / osm / osmolarity rows are the
    % formulation's own fields, and a row with no unit is written with a gap
    if any(strcmpi(strtrim(cols{2}), {'pH', 'osm', 'osmolarity'}))
        continue;
    end
    value = str2double(cols{3});
    u = strtrim(cols{5});
    if ~isfinite(value) || isempty(u)
        continue;
    end
    [~, ok] = ndi.migrate.internal.bathPrefixedValue(value, u, 'molar');
    if ~ok
        unparsed{end+1} = sprintf('%s: %s %s', cols{2}, num2str(value, 17), u); %#ok<AGROW>
    end
end
rows = [rows, unparsed];
end

function cols = csvFields(line)
% split one CSV line on commas outside double quotes ("" inside is one ")
cols = {};
cur = '';
inQuote = false;
k = 1;
while k <= numel(line)
    ch = line(k);
    if inQuote
        if ch == '"'
            if k < numel(line) && line(k + 1) == '"'
                cur(end+1) = '"'; %#ok<AGROW>
                k = k + 1;
            else
                inQuote = false;
            end
        else
            cur(end+1) = ch; %#ok<AGROW>
        end
    elseif ch == '"'
        inQuote = true;
    elseif ch == ','
        cols{end+1} = strtrim(cur); %#ok<AGROW>
        cur = '';
    else
        cur(end+1) = ch; %#ok<AGROW>
    end
    k = k + 1;
end
cols{end+1} = strtrim(cur);
end
