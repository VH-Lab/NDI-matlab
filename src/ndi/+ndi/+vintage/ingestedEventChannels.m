function E = ingestedEventChannels(statements, bodies)
%INGESTEDEVENTCHANNELS The event, marker and text channels of a migrated ingested epoch, from their observations.
%
%   E = ndi.vintage.ingestedEventChannels(STATEMENTS, BODIES) finds, among
%   STATEMENTS (the epoch's statements on the reader's acquisition system)
%   and BODIES (the data bodies they own, and the bodies of the values those
%   key to), each unpacked event, marker or text channel. Both are cells of
%   ndi.document or of document_properties structs.
%
%   Decided by Jess Haley, 2026-11-17 [event channels are time-valued
%   observations] (did-schema did_v2_go_forward_class_audit.md): "the event,
%   marker and text channels of an ingested `evmktx_group<g>_seg.nbf_1` file
%   are unpacked, one observation per channel ...: an event channel is a
%   `time` value (the event times, seconds from the epoch start, in a
%   `sampled_body`); a marker channel is a `label` value (one code per
%   event ...) keyed to a `time` value of the event times; a text channel is
%   a `text` value keyed the same way"; and [channel list rows get v2 homes]:
%   each "recording its channel type and number as a condition (e.g. "marker
%   channel", EMPTY:0000377, count 1)". A channel's observation is the
%   statement with such a condition (by node: EMPTY:0000376 event channel,
%   EMPTY:0000377 marker channel, EMPTY:0000410 text channel; [channel
%   types]). ndi.migrate.internal.ingestedArchiveBodies writes them.
%
%   E is a struct array, one entry per channel, in STATEMENTS order:
%     type         'event', 'marker' or 'text'
%     number       the channel number (the condition's count)
%     statement_id the observation's id
%     values       the body holding the channel's values: for an event
%                  channel its times, for a marker channel its codes, for a
%                  text channel its entries ([] when not found)
%     times        the body holding the event times: the values body for an
%                  event channel; for a marker or text channel the body of
%                  the `time` value its time covariate keys to ([] when not
%                  found)
%   The bodies are as given (ndi.document or struct).
%
%   See also ndi.vintage.ingestedEventData, ndi.vintage.ingestedArchive,
%            ndi.vintage.ingestedChannelList.

arguments
    statements cell
    bodies cell = {}
end

E = struct('type', {}, 'number', {}, 'statement_id', {}, 'values', {}, 'times', {});
[types, abbrev] = ndi.daq.reader.mfdaq.channel_types();
bodyProps = cellfun(@propsOf, bodies, 'UniformOutput', false);
for k = 1:numel(statements)
    p = propsOf(statements{k});
    [type, number] = eventChannelOf(p, types, abbrev);
    if isempty(type); continue; end
    id = idOf(p);
    values = []; times = [];
    vb = ownedBy(bodyProps, id);
    if ~isempty(vb)
        values = bodies{vb(1)};
        if strcmp(type, 'event')
            times = values;
        else
            keys = edgeValues(bodyProps{vb(1)}, 'key_id');
            if ~isempty(keys)
                tb = ownedBy(bodyProps, keys{1});
                if ~isempty(tb); times = bodies{tb(1)}; end
            end
        end
    end
    E(end+1) = struct('type', type, 'number', number, 'statement_id', id, ...
        'values', {values}, 'times', {times}); %#ok<AGROW>
end
end

% =====================================================================

function [type, number] = eventChannelOf(p, types, abbrev)
type = ''; number = [];
cs = ndi.v2.blockOf(p, 'statement', 'conditions', []);
if isstruct(cs); cs = num2cell(cs); end
if ~iscell(cs); return; end
for c = 1:numel(cs)
    cc = cs{c};
    if ~isstruct(cc) || ~isfield(cc, 'variable') || ~isstruct(cc.variable) ...
            || ~isfield(cc.variable, 'node')
        continue;
    end
    node = char(cc.variable.node);
    if ~any(strcmp(node, {'EMPTY:0000376', 'EMPTY:0000377', 'EMPTY:0000410', 'NCIT:C25704'}))
        continue;
    end
    n = [];
    old = ndi.v2.oldNumericForm(cc);
    if ~isempty(old)
        % the old numeric shape is not read (did-schema
        % did_v2_numeric_shape_plan.md section 9 step 4, [no migrated
        % database is kept], Jess Haley, 2026-11-19)
        ndi.v2.refuseOldNumericShape('An event channel''s number', old);
    end
    if isfield(cc, 'count') && ~isempty(cc.count)
        n = double(cc.count);
    elseif isfield(cc, 'numeric') && ~isempty(cc.numeric)
        n = double(cc.numeric);
    end
    if ~isscalar(n); continue; end
    ab = char(ndi.vintage.channelPrefix(cc.variable));
    i = find(strcmp(abbrev, ab), 1);
    if isempty(i); continue; end
    type = types{i};
    number = n;
    return;
end
end

function idx = ownedBy(bodyProps, id)
idx = [];
for b = 1:numel(bodyProps)
    if any(strcmp(edgeValues(bodyProps{b}, 'owner_id'), id))
        idx(end+1) = b; %#ok<AGROW>
    end
end
end

function p = propsOf(d)
if isstruct(d); p = d; else; p = d.document_properties; end
end

function id = idOf(p)
id = '';
if isfield(p, 'base') && isfield(p.base, 'id'); id = char(p.base.id); end
end

function vals = edgeValues(p, name)
vals = {};
if ~isfield(p, 'depends_on') || isempty(p.depends_on); return; end
deps = p.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value)
        vals{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        vals{end+1} = char(d.document_id); %#ok<AGROW>
    end
end
end
