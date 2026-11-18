function ci = ingestedChannelList(groups, events)
%INGESTEDCHANNELLIST The v1 channel list of a migrated ingested epoch, rebuilt from its v2 documents.
%
%   CI = ndi.vintage.ingestedChannelList(GROUPS, EVENTS) is the
%   channel_information of ndi.file.type.mfdaq_epoch_channel (fields name,
%   type, time_channel, sample_rate, offset, scale, number, group, dataclass)
%   that the v1 `channel_list.bin` of the epoch held, rebuilt from:
%
%     GROUPS  a cell of document_properties structs: the epoch's channel-group
%             `sampled_body` documents (`data_body.filename`
%             `<p>_group<g>_seg.nbf_#`, p in ai ao ax di do), as
%             ndi.migrate.internal.ingestedArchiveBodies writes them. Any
%             other document in the cell is skipped.
%     EVENTS  a struct array with fields type ('event', 'marker' or 'text')
%             and number: the epoch's event, marker and text channels
%             ([event channels are time-valued observations], Jess Haley,
%             2026-11-17; ndi.vintage.ingestedEventChannels reads them from
%             their observations). [] or omitted when there are none.
%
%   Each channel group's channel is one row:
%     name          the body's name covariate entry when it has one and the
%                   entry is not empty ([channel name is an identifier],
%                   Jess Haley, 2026-11-17: "a channel's v1 name is a
%                   covariate along the channel dimension of its channel
%                   group's body, variable NCIT:C25364 "Identifier", one
%                   text value per channel"; found by node), else its v1
%                   prefix and number (`ai3`), the name NDI's readers give
%     type          the group's channel type (the body's condition, by node)
%     time_channel  the body's per-channel "time channel" covariate
%                   (EMPTY:0000374) when it has one ([time channel is a
%                   per-channel covariate], Jess Haley, 2026-11-17: "one
%                   unitless number per channel, NaN and dangling values
%                   carried exactly"); NaN when it has none (the shape the
%                   second pass wrote before that decision)
%     sample_rate   1 / the time covariate's spacing (to the nearest integer
%                   when within a part in 1e9 of it); NaN when the time is
%                   keyed (an uneven time channel)
%     offset        the offset covariate (AFO:AFQ_0000202)
%     scale         the scale covariate (NCIT:C70774): its `source_value`
%                   (the scale in the reader's own output unit, what NDI's
%                   reader multiplies by) when it has one, else its `value`
%     number        the channel-number covariate
%     group         the file's group
%     dataclass     'digital' for di/do, else 'ephys'
%   Each event, marker or text channel is one row: name its v1 prefix and
%   number (`mk2`), time_channel and sample_rate NaN, offset 0, scale 1,
%   group 1 + floor(number / 100000) and dataclass 'eventmarktext', what
%   NDI's ingest writes for those channels (ndi.file.type.mfdaq_epoch_channel
%   /create_properties; ndi.daq.reader.mfdaq/ingest_epochfiles asks no event
%   channel for a sample rate, and underlying_datatype gives [0 1]). Decided
%   by Jess Haley, 2026-11-18 [event row defaults are notation]: those
%   fields, "when they are NDI's defaults, are notation ... not stored,
%   rebuilt by the round trip; a channel list whose event or marker rows
%   differ from the defaults (CED Spike2 sets an event's time channel to its
%   own number) is kept whole as v1, as today".
%
%   The rows are in the order ndi.file.type.mfdaq_epoch_channel/
%   create_properties writes them: the sampled types in alphabetical order of
%   their type name, each by number; then every event, marker and text row,
%   by number (event before marker before text at an equal number).
%
%   Not rebuilt, so not here: a time channel's own row, and the name of an
%   event, marker or text channel that is not its prefix and number (its
%   name is in its observation's notes; the name covariate lives on a channel
%   group's body). They have no v2 home (did-schema [channel list rows get
%   v2 homes]: the time channel's own row is open), so
%   ndi.migrate.internal.ingestedArchiveBodies removes `channel_list.bin` only
%   when this function rebuilds it exactly, and keeps it otherwise.
%
%   See also ndi.vintage.ingestedArchive, ndi.migrate.internal.ingestedArchiveBodies,
%            ndi.file.type.mfdaq_epoch_channel.

arguments
    groups cell
    events = []
end

ci = struct('name', {}, 'type', {}, 'time_channel', {}, 'sample_rate', {}, ...
    'offset', {}, 'scale', {}, 'number', {}, 'group', {}, 'dataclass', {});
[types, abbrev] = ndi.daq.reader.mfdaq.channel_types();
for k = 1:numel(groups)
    p = groups{k};
    if ~isstruct(p) || ~isfield(p, 'data_body') || ~isstruct(p.data_body) ...
            || ~isfield(p.data_body, 'filename')
        continue;
    end
    tok = regexp(char(p.data_body.filename), '^(ai|ao|ax|di|do)_group(\d+)_seg\.nbf_#$', ...
        'tokens', 'once');
    if isempty(tok) || ~isfield(p, 'data') || ~isstruct(p.data) ...
            || ~isfield(p.data, 'covariates')
        continue;
    end
    ab = channelPrefixOf(p, tok{1});
    type = types{find(strcmp(abbrev, ab), 1)};
    covs = asCell(p.data.covariates);
    nums = []; off = []; sc = []; tc = []; names = {}; sr = NaN;
    for c = 1:numel(covs)
        cv = covs{c};
        if ~isstruct(cv) || ~isfield(cv, 'variable'); continue; end
        v = cv.variable;
        nm = ''; node = '';
        if isstruct(v) && isfield(v, 'name'); nm = char(v.name); end
        if isstruct(v) && isfield(v, 'node'); node = char(v.node); end
        if isTimeTerm(v) && isfield(cv, 'spacing') && isstruct(cv.spacing) ...
                && isfield(cv.spacing, 'value')
            sr = 1 / double(cv.spacing.value);
            % the spacing is stored as 1/rate: an integer rate comes back
            % as that integer, not one bit off it
            if abs(sr - round(sr)) <= 1e-9 * abs(sr); sr = round(sr); end
        elseif strcmp(nm, 'channel number')
            nums = double(cv.count(:)');
        elseif strcmp(node, 'AFO:AFQ_0000202')
            off = numbersOf(cv, 'value');
        elseif strcmp(node, 'NCIT:C70774')
            % [scale carries the reader's unit] (Jess Haley, 2026-11-17):
            % where the reader defines its output unit, `value` is in volts
            % per count and `source_value` is the v1 scale in the reader's
            % output unit, which is what NDI's reader multiplies by
            sc = numbersOf(cv, 'source_value');
            if isempty(sc); sc = numbersOf(cv, 'value'); end
        elseif strcmp(node, 'EMPTY:0000374')
            % [time channel is a per-channel covariate]
            tc = numbersOf(cv, 'value');
        elseif strcmp(node, 'NCIT:C25364') && isfield(cv, 'text')
            % [channel name is an identifier]
            names = textsOf(cv.text);
        end
    end
    n = numel(nums);
    if isempty(tc) || numel(tc) ~= n
        tc = NaN(1, n);
    end
    if numel(off) ~= n || numel(sc) ~= n
        continue;   % not a channel group the second pass wrote
    end
    if any(strcmp(ab, {'di', 'do'})); dc = 'digital'; else; dc = 'ephys'; end
    if numel(names) ~= n
        names = repmat({''}, 1, n);
    end
    for r = 1:n
        nm = names{r};
        if isempty(nm); nm = sprintf('%s%d', ab, nums(r)); end
        ci(end+1) = struct('name', nm, 'type', type, ...
            'time_channel', tc(r), 'sample_rate', sr, 'offset', off(r), 'scale', sc(r), ...
            'number', nums(r), 'group', str2double(tok{2}), 'dataclass', dc); %#ok<AGROW>
    end
end
% the sampled types alphabetically by type name, each by number (a stable
% sort: by number, then by type)
if ~isempty(ci)
    [~, o] = sort([ci.number]);
    ci = ci(o);
    [~, o] = sort({ci.type});
    ci = ci(o);
end

% the event, marker and text channels, after them, by number
emt = ci([]);
if isstruct(events)
    for k = 1:numel(events)
        t = char(events(k).type);
        ab = abbrev{strcmp(types, t)};
        num = double(events(k).number);
        emt(end+1) = struct('name', sprintf('%s%d', ab, num), 'type', t, ...
            'time_channel', NaN, 'sample_rate', NaN, 'offset', 0, 'scale', 1, ...
            'number', num, 'group', 1 + floor(num / 100000), ...
            'dataclass', 'eventmarktext'); %#ok<AGROW>
    end
end
if ~isempty(emt)
    [~, o] = sort({emt.type});
    emt = emt(o);
    [~, o] = sort([emt.number]);
    emt = emt(o);
end
ci = [ci, emt];
end

% =====================================================================

function x = numbersOf(cv, field)
% a covariate's numbers, as a row: quantity.<FIELD> (NaN carried; a JSON
% null read back as [] is NaN), or the flat `numeric` / `source_numeric` of
% the new numeric shape
x = [];
if isfield(cv, 'quantity') && isstruct(cv.quantity) && isfield(cv.quantity, field)
    x = cv.quantity.(field);
else
    flat = struct('value', 'numeric', 'source_value', 'source_numeric');
    if isfield(cv, flat.(field)); x = cv.(flat.(field)); end
end
if iscell(x)
    y = NaN(1, numel(x));
    for i = 1:numel(x)
        if isnumeric(x{i}) && isscalar(x{i}); y(i) = double(x{i}); end
    end
    x = y;
elseif ischar(x) || isstring(x)
    x = str2double(cellstr(x));
end
x = double(x(:)');
end

function c = textsOf(x)
% a text covariate's entries, as a row cellstr (a JSON array of one string
% read back as a char is one entry)
if ischar(x)
    c = {x};
elseif isstring(x)
    c = cellstr(x);
elseif iscell(x)
    c = cell(1, numel(x));
    for i = 1:numel(x)
        if ischar(x{i}) || (isstring(x{i}) && isscalar(x{i}))
            c{i} = char(x{i});
        else
            c{i} = '';
        end
    end
else
    c = {};
end
c = reshape(c, 1, []);
end

function tf = isTimeTerm(t)
tf = false;
if ~isstruct(t); return; end
if isfield(t, 'node') && strcmp(char(t.node), 'om:Time'); tf = true; return; end
tf = isfield(t, 'name') && strcmpi(char(t.name), 'time');
end

function ab = channelPrefixOf(p, filePrefix)
% the channel type the body's condition names (by node: [channel types]);
% the file's prefix when it names none
ab = filePrefix;
if ~isfield(p.data_body, 'conditions'); return; end
cs = asCell(p.data_body.conditions);
for c = 1:numel(cs)
    if isstruct(cs{c}) && isfield(cs{c}, 'term') && ~isempty(cs{c}.term)
        got = char(ndi.vintage.channelPrefix(cs{c}.term));
        if any(strcmp(got, {'ai', 'ao', 'ax', 'di', 'do'}))
            ab = got;
            return;
        end
    end
end
end

function c = asCell(x)
if iscell(x); c = x; elseif isstruct(x); c = num2cell(x); else; c = {}; end
end
