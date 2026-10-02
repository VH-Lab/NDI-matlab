function [T, rule] = transferTime(protocol, folder, behaviourStart, lawnStart, behaviourVideo)
%TRANSFERTIME When an assay plate's worms were moved onto it (decision #52).
%
%   [T, RULE] = ndi.setup.conv.haley.transferTime(PROTOCOL, FOLDER,
%   BEHAVIOURSTART, LAWNSTART, BEHAVIOURVIDEO) returns the transfer time T of
%   one assay plate as wall-clock time (no time zone; NaT when the plate was
%   never filmed). The source does not record it, so it is read off the
%   plate's videos with PROTOCOL, the spec's `transfer_protocol` section:
%
%     contrast video AFTER the worms went on (worms first): T = the lawn
%       clip's start (LAWNSTART), when it is at most an hour before
%       BEHAVIOURSTART; otherwise BEHAVIOURSTART
%     contrast video BEFORE the worms (lawn first), or no rule: T =
%       BEHAVIOURSTART, the plate's first behaviour video start
%
%   T is approximate either way. FOLDER is the source folder
%   (foragingConcentration, ...); BEHAVIOURVIDEO is the plate's video file
%   names without extension -- a char, or a cellstr such as {first behaviour
%   video, lawn clip} -- which a protocol `exceptions` entry names by any one
%   of them (e.g. 2023-04-04_16-10-14_2 is that plate's lawn clip). RULE is a struct: method (how the
%   worms were moved, '' with no rule), contrast_video ('before_worms',
%   'after_worms' or ''), source ('rule', 'exception' or 'none'), and used
%   ('lawn clip' or 'behaviour video').
%
%   Rules match by `source_folder` and, when given, `from_date` / `to_date`
%   (inclusive, yyyy-MM-dd) against BEHAVIOURSTART's day; an exception
%   overrides the contrast-video order of the rule that matched.

rule = struct('method', '', 'contrast_video', '', 'source', 'none', 'used', 'behaviour video');
T = behaviourStart;
if isnat(behaviourStart)
    return;
end
day = dateshift(behaviourStart, 'start', 'day');
for r = asCell(getOr(protocol, 'rules', {}))
    x = r{1};
    if ~strcmp(char(x.source_folder), folder)
        continue;
    end
    if isfield(x, 'from_date') && day < datetime(x.from_date, 'InputFormat', 'yyyy-MM-dd')
        continue;
    end
    if isfield(x, 'to_date') && day > datetime(x.to_date, 'InputFormat', 'yyyy-MM-dd')
        continue;
    end
    rule.method = char(getOr(x, 'method', ''));
    rule.contrast_video = char(x.contrast_video);
    rule.source = 'rule';
    break;
end
for e = asCell(getOr(protocol, 'exceptions', {}))
    x = e{1};
    if any(strcmp(char(x.video), cellstr(behaviourVideo)))
        rule.contrast_video = char(x.contrast_video);
        rule.source = 'exception';
    end
end
if strcmp(rule.contrast_video, 'after_worms') && ~isnat(lawnStart) ...
        && lawnStart <= behaviourStart && behaviourStart - lawnStart <= hours(1)
    T = lawnStart;
    rule.used = 'lawn clip';
end
end

function v = getOr(s, name, default)
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end

function c = asCell(x)
if iscell(x)
    c = x(:)';
elseif isstruct(x)
    c = num2cell(x(:)');
else
    c = {};
end
end
