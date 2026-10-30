function series = epochSeries(observations, docById)
%EPOCHSERIES A derived element's per-epoch series, read from the migrated shape.
%
%   SERIES = ndi.vintage.epochSeries(OBSERVATIONS, DOCBYID)
%
%   OBSERVATIONS is a cell of candidate documents (ndi.document objects or
%   their document_properties structs): the observations whose `entity_id`
%   is the element. DOCBYID is a function handle, ID -> that document's
%   properties struct, or [] when it is not in the database.
%
%   SERIES is a struct array, one entry per observation that is an epoch
%   series, with fields
%       epoch_id     the v1 epoch id string (the epoch entity's
%                    local_identifier)
%       epoch_clock  1-by-1 cell of ndi.time.clocktype
%       t0_t1        1-by-1 cell of [t0 t1], on that clock
%       observation  the observation (as given in OBSERVATIONS)
%       epoch_doc_id the epoch entity's id
%   in the shape ndi.element/loadaddedepochs builds its table from.
%
%   ---------------------------------------------------------------------
%   THE SHAPE (Decided by Jess Haley, 2026-10-22 [epoch dissolution before
%   merge], did-schema V_eta_epoch_plan.md): a v1 element_epoch DISSOLVES.
%   What it held is now
%
%       observation          entity_id = the element, base.id = the v1
%                            element_epoch id, data_body true
%         time_reference_id -> relative_time_reference
%                                value.clock  the v1 epoch_clock
%                                value.start  t0      value.end  t1
%                                referent_id -> entity, type epoch,
%                                               local_identifier = the v1
%                                               epochid string
%         <- owner_id of its data body (the .vhsb), see
%            ndi.vintage.epochSeriesBody
%
%   built by did2.convert.resolveEpochProbemap. The v1 epoch id string is
%   gone from the document ([epoch] signature 2026-08-08: "epochid is
%   DROPPED") and is read back through the epoch entity, which is why this
%   needs DOCBYID and is not a field lookup.
%
%   AN OBSERVATION THAT IS NOT AN EPOCH SERIES IS SKIPPED, NOT AN ERROR:
%   every observation of the element is offered, and only the ones anchored
%   by a relative_time_reference with a clock and a start, onto an epoch
%   entity, are series. The epoch is recognised by its type -- the name
%   'epoch' (did2.convert.epochMint today) or the term EMPTY:0000383
%   'recording epoch' (Decided by Jess Haley, 2026-10-22, L3) -- so the
%   rename of the type name does not silently empty every epoch table.
%
%   See also ndi.vintage.addedEpoch, ndi.vintage.epochSeriesBody,
%            ndi.element/loadaddedepochs.

arguments
    observations
    docById (1,1) function_handle
end

series = struct('epoch_id', {}, 'epoch_clock', {}, 't0_t1', {}, ...
    'observation', {}, 'epoch_doc_id', {});
if isempty(observations)
    return;
end
if ~iscell(observations)
    observations = {observations};
end
for i = 1:numel(observations)
    props = propsOf(observations{i});
    if isempty(props)
        continue;
    end
    trIds = edgeValues(props, 'time_reference_id');
    for t = 1:numel(trIds)
        tr = docById(trIds{t});
        [ok, clockName, t0, t1, referentId] = readRelative(tr);
        if ~ok
            continue;
        end
        ep = docById(referentId);
        epochId = epochLocalId(ep);
        if isempty(epochId)
            continue;
        end
        series(end+1) = struct('epoch_id', epochId, ... %#ok<AGROW>
            'epoch_clock', {{ndi.time.clocktype(clockName)}}, ...
            't0_t1', {{[t0 t1]}}, ...
            'observation', {observations{i}}, ...
            'epoch_doc_id', referentId);
        break;   % one anchor names the series' epoch
    end
end
end

% ---------------------------------------------------------------------

function props = propsOf(d)
props = [];
if isa(d, 'ndi.document') || isa(d, 'did.document')
    props = d.document_properties;
elseif isstruct(d) && isscalar(d)
    props = d;
end
end

function [ok, clockName, t0, t1, referentId] = readRelative(tr)
ok = false; clockName = ''; t0 = []; t1 = []; referentId = '';
if isempty(tr) || ~isstruct(tr) || ~isfield(tr, 'relative_time_reference')
    return;
end
blk = tr.relative_time_reference;
if ~isstruct(blk) || ~isfield(blk, 'value') || ~isstruct(blk.value)
    return;
end
v = blk.value;
if ~isfield(v, 'clock') || ~isstruct(v.clock) || ~isfield(v, 'start')
    return;
end
% the ndi.time.clocktype string, read by node first and then by name
% (ndi.v2.vocabHandle 'clock'): the stored name becomes the label
% ("device local time") once did-schema fills the clock nodes (Decided by
% Jess Haley, 2026-10-26 [clock terms get nodes])
clockName = ndi.v2.vocabHandle('clock', v.clock);
if isempty(clockName)
    return;
end
t0 = secondsOf(v.start);
if isempty(t0)
    return;
end
t1 = [];
if isfield(v, 'end'); t1 = secondsOf(v.end); end
if isempty(t1) && isfield(v, 'duration')
    d = secondsOf(v.duration);
    if ~isempty(d); t1 = t0 + d; end
end
if isempty(t1)
    return;
end
ids = edgeValues(tr, 'referent_id');
if isempty(ids)
    return;
end
referentId = ids{1};
clockName = char(clockName);
ok = true;
end

function s = secondsOf(cellValue)
s = [];
if isstruct(cellValue) && ~isempty(cellValue) && isfield(cellValue, 'seconds') ...
        && ~isempty(cellValue(1).seconds) && isnumeric(cellValue(1).seconds)
    s = double(cellValue(1).seconds);
end
end

function id = epochLocalId(ep)
id = '';
if isempty(ep) || ~isstruct(ep) || ~isfield(ep, 'entity') || ~isstruct(ep.entity)
    return;
end
e = ep.entity;
if ~isfield(e, 'type') || ~isstruct(e.type)
    return;
end
name = ''; node = '';
if isfield(e.type, 'name'); name = char(e.type.name); end
if isfield(e.type, 'node'); node = char(e.type.node); end
if ~(strcmpi(name, 'epoch') || strcmpi(name, 'recording epoch') ...
        || strcmp(node, 'EMPTY:0000383'))
    return;
end
if isfield(e, 'local_identifier') && ~isempty(e.local_identifier)
    id = char(e.local_identifier);
end
end

function vals = edgeValues(props, name)
vals = {};
if ~isfield(props, 'depends_on') || isempty(props.depends_on)
    return;
end
deps = props.depends_on;
if isstruct(deps)
    deps = num2cell(deps);
end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    % an ndi.document writes `value`; did2.build writes `document_id`
    if isfield(d, 'value') && ~isempty(d.value)
        vals{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        vals{end+1} = char(d.document_id); %#ok<AGROW>
    end
end
end
