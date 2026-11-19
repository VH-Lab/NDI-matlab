function k = earliestByContent(stamps, ids)
%EARLIESTBYCONTENT The position of the earliest-stamped document, chosen by
%   content and never by the order the documents were read in.
%
%   K = ndi.migrate.internal.earliestByContent(STAMPS, IDS), STAMPS and IDS
%   cellstrs of equal length (a document's timestamp and its base.id), returns
%   the index of the document whose timestamp is the earliest. Equal instants
%   are broken by the smaller id (character order). K is empty when STAMPS is.
%
%   THE RULE. When the second pass mints one document from several contributing
%   v1 documents and must give it ONE value that those documents disagree on
%   (the session cohort's creation timestamp, from the stimulus presentations
%   that made it; a strain group's representative, from the Strain documents
%   that collapsed into it), the value is taken from the contributor this
%   function picks. Database order is not data (NDI-matlab #1235): "the first
%   document read" depends on how the database happened to be written, so two
%   copies of the same dataset would migrate to different values. The earliest
%   timestamp, ties broken by id, depends only on what the documents say.
%
%   Ranking, in order:
%     1. a timestamp that parses as ISO 8601 (YYYY-MM-DD[T ]hh:mm:ss[.fff],
%        then Z, +hh:mm, +hhmm or nothing; nothing is read as UTC, which is
%        what ndi.fun.timestamp writes), earliest instant first;
%     2. a non-empty timestamp that does not parse, in character order;
%     3. an empty timestamp;
%   and within any tie, the smaller id.
%
%   See also ndi.migrate.local, ndi.migrate.internal.subjectStrainAssembly.

arguments
    stamps cell
    ids cell
end

n = numel(stamps);
k = [];
if n == 0
    return;
end
if numel(ids) ~= n
    error('ndi:migrate:earliestByContent:size', ...
        'earliestByContent needs one id per timestamp (%d stamps, %d ids).', ...
        n, numel(ids));
end

rankClass = zeros(1, n);   % 1 parsed, 2 unparsed, 3 empty
instant = zeros(1, n);     % seconds, for class 1
text = cell(1, n);         % the timestamp text, for class 2
idText = cell(1, n);
for j = 1:n
    s = strtrim(charOf(stamps{j}));
    idText{j} = charOf(ids{j});
    text{j} = s;
    if isempty(s)
        rankClass(j) = 3;
        continue;
    end
    [ok, t] = parseIso(s);
    if ok
        rankClass(j) = 1;
        instant(j) = t;
    else
        rankClass(j) = 2;
    end
end

k = 1;
for j = 2:n
    if precedes(j, k)
        k = j;
    end
end

    function tf = precedes(a, b)
        % true when document A ranks strictly before document B
        if rankClass(a) ~= rankClass(b)
            tf = rankClass(a) < rankClass(b);
            return;
        end
        if rankClass(a) == 1 && instant(a) ~= instant(b)
            tf = instant(a) < instant(b);
            return;
        end
        if rankClass(a) == 2 && ~strcmp(text{a}, text{b})
            tf = textBefore(text{a}, text{b});
            return;
        end
        tf = textBefore(idText{a}, idText{b});
    end
end

function [ok, t] = parseIso(s)
% seconds since the datenum epoch, UTC; OK false when S is not ISO 8601
ok = false;
t = 0;
tok = regexp(s, ['^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)' ...
    '(Z|[+-]\d{2}:?\d{2})?$'], 'tokens', 'once');
if isempty(tok)
    return;
end
v = str2double(tok(1:6));
if any(isnan(v))
    return;
end
offset = 0;
if numel(tok) >= 7 && ~isempty(tok{7}) && ~strcmp(tok{7}, 'Z')
    z = strrep(tok{7}, ':', '');
    sgn = 1;
    if z(1) == '-'; sgn = -1; end
    offset = sgn * (str2double(z(2:3)) * 3600 + str2double(z(4:5)) * 60);
end
t = datenum(v(1), v(2), v(3)) * 86400 + v(4) * 3600 + v(5) * 60 + v(6) - offset;
ok = true;
end

function tf = textBefore(a, b)
% character order (the order sort() gives a cellstr)
if strcmp(a, b)
    tf = false;
    return;
end
[~, o] = sort({a, b});
tf = o(1) == 1;
end

function s = charOf(v)
s = '';
if ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
end
end
