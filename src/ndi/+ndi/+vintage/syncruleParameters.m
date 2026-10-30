function params = syncruleParameters(ruleDoc, ndi_session_obj, objClass)
%SYNCRULEPARAMETERS Rebuild an ndi.time.syncrule `parameters` struct, either vintage.
%
%   PARAMS = ndi.vintage.syncruleParameters(RULEDOC, NDI_SESSION_OBJ, OBJCLASS)
%
%   THIS IS THE ONE PIECE OF THE V_eta READ PATH THAT IS NOT A RENAME, and
%   the migrator says so in its own header rather than leaving it to be
%   discovered (DID-matlab +migrators_j/syncrule.m):
%
%       "`ndi.time.syncrule`'s constructor rebuilds a live rule object from
%        varargin{2}.document_properties.syncrule.parameters (syncrule.m:21).
%        On a converted document that path is gone -- by design, it is what
%        'parameters DECLARED not bagged' means. That is an NDI-SIDE reader
%        change, not something a migrator can carry."
%
%   This is that reader change. V_eta does three different things to one v1
%   `parameters` bag:
%
%     RENAMED into typed fields on `clock_alignment_configuration` (since
%     did-schema #73 item 22, `method_parameters` entries named by
%     `variable` -- `method.parameters` since #88; all forms are read)
%         epochclocktype           -> clock (an ontology_term; the name half)
%         number_fullpath_matches  -> minimum_matching_file_paths
%         syncfilename             -> sync_file_name
%         minEmbeddedFileOverlap   -> minimum_embedded_file_overlap
%
%     LINKED to the two rigs, in one of two shapes (both are read):
%       the current shape (did-schema `V_eta_go_forward_class_audit.md`,
%       Jess Haley 2026-10-27 [sync configuration links its rigs] and
%       [sync rule direction is recorded]): role-named edges straight to
%       the two `acquisition_system` documents, the trigger channels as
%       method parameters
%         daqsystem1_name / daqsystem1 <- from_acquisition_system_id's
%                                         acquisition_system `name`
%         daqsystem2_name / daqsystem2 <- to_acquisition_system_id's
%         daqsystem_ch1, daqsystem_ch2 <- the method parameters labelled
%                                         'from trigger channel' / 'to
%                                         trigger channel' (Jess Haley
%                                         2026-10-30 [trigger channels
%                                         named by their link]), or, in a
%                                         session migrated before DID-matlab
%                                         wrote those labels, by the v1
%                                         names ('daqsystem ch1' / '... ch2')
%         The pair is ORDERED: a filefind rule maps daqsystem1's clock to
%         daqsystem2's (+time/+syncrule/filefind.m `apply`), so from is 1
%         and to is 2.
%       the earlier shape, read when the configuration has no
%       from/to edge: two `acquisition_channels` documents, one per device
%         daqsystem1_name / daqsystem1 <- acquisition_channels_1.base.name
%                                         (current schema: its
%                                         acquisition_system's `name`)
%         daqsystem_ch1                <- its `channels` array, re-serialised
%         (and _2 likewise), 1 and 2 being the edge positions.
%
%     DROPPED
%         errorOnFailure. "throw-or-return-quietly is runtime behaviour, not
%         a fact about the experiment" (repair 5). But `isvalidparameters`
%         REQUIRES it and `setparameters` errors without it, so this
%         supplies NDI's own documented default of `true`
%         (+ndi/+time/+syncrule/commonTriggersOverlappingEpochs.m:33 and :39,
%         randomPulses.m:31 and :37). That is the only value invented here,
%         and it is invented from NDI's default rather than chosen.
%
%   ANYTHING ELSE MISSING IS AN ERROR, NOT A DEFAULT. A parameter the
%   migrator should have carried and did not is a data problem, and filling
%   it in silently would produce a rule that runs and synchronises wrongly.
%   Only the one deliberately-dropped field gets a fallback.
%
%   OBJCLASS decides WHICH parameters to build, because each subclass
%   validates a different set and MATLAB's `hasAllFields` is asked for an
%   exact list. Building a superset would risk failing a validator that
%   also checks sizes.
%
%   Errors:
%       NDI:vintage:syncruleUnknownClass    no parameter set known for OBJCLASS
%       NDI:vintage:syncruleMissingField    a required parameter cannot be recovered
%       NDI:vintage:syncruleChannelsNotFound  an acquisition_channels edge does not resolve
%       NDI:vintage:syncruleSystemNotFound    a from/to acquisition_system edge does not resolve
%
%   See also: ndi.time.syncrule, ndi.vintage.map, ndi.vintage.objectClass.

arguments
    ruleDoc
    ndi_session_obj
    objClass (1,:) char
end

[entry, vintage] = ndi.vintage.entryFor(ruleDoc);

if isempty(entry) || ~strcmp(vintage, 'V_eta')
    % v1: the bag is on the document, exactly where it always was.
    params = ruleDoc.document_properties.syncrule.parameters;
    return;
end

props = ruleDoc.document_properties;
cfg = struct();
blockName = props.document_class.class_name;
if isfield(props, blockName) && isstruct(props.(blockName))
    cfg = props.(blockName);
end

% ---- the two rigs ------------------------------------------------------
% The current shape first: `from_acquisition_system_id` (v1 daqsystem1) and
% `to_acquisition_system_id` (v1 daqsystem2), the trigger channels as method
% parameters. A configuration with neither edge is read the earlier way,
% through its `acquisition_channels` documents: a numbered pair
% (`acquisition_channels_1`/`_2`) or one repeated name
% (`acquisition_channels_id` twice, did-schema T15), 1 and 2 being positions.
fromId = ruleDoc.dependency_value('from_acquisition_system_id', 'ErrorIfNotFound', 0);
toId   = ruleDoc.dependency_value('to_acquisition_system_id', 'ErrorIfNotFound', 0);
if ~isempty(fromId) || ~isempty(toId)
    name1 = systemName(fromId, 'from_acquisition_system_id', ndi_session_obj);
    name2 = systemName(toId, 'to_acquisition_system_id', ndi_session_obj);
    ch1 = triggerChannel(cfg, 1);
    ch2 = triggerChannel(cfg, 2);
else
    channelIds = ndi.vintage.edge_n(ruleDoc, 'acquisition_channels', ...
        'ErrorIfNotFound', 0);
    [name1, ch1] = deviceHalf(channelIds, ndi_session_obj, 1);
    [name2, ch2] = deviceHalf(channelIds, ndi_session_obj, 2);
end

% ---- the typed fields -------------------------------------------------
clockName = '';
if isfield(cfg, 'clock') && isstruct(cfg.clock)
    % the ndi.time.clocktype string, by node first, then by name (Decided by
    % Jess Haley, 2026-10-26 [clock terms get nodes]: the stored name becomes
    % the label once did-schema fills the clock nodes)
    clockName = ndi.v2.vocabHandle('clock', cfg.clock);
end

params = struct();
switch objClass
    case {'ndi.time.syncrule.commonTriggersOverlappingEpochs', ...
          'ndi.time.syncrule.randomPulses'}
        params.daqsystem1_name = require(name1, 'daqsystem1_name', objClass);
        params.daqsystem2_name = require(name2, 'daqsystem2_name', objClass);
        params.daqsystem_ch1   = require(ch1,   'daqsystem_ch1',   objClass);
        params.daqsystem_ch2   = require(ch2,   'daqsystem_ch2',   objClass);
        params.epochclocktype  = require(clockName, 'epochclocktype', objClass);
        if strcmp(objClass, 'ndi.time.syncrule.commonTriggersOverlappingEpochs')
            params.minEmbeddedFileOverlap = requireNumber(cfg, ...
                'minimum_embedded_file_overlap', 'minEmbeddedFileOverlap', objClass);
        end
        % THE ONE INVENTED VALUE, when the configuration does not carry it
        % (DID-matlab writes it as a method parameter since [small unread
        % settings] (3)). See the header.
        params.errorOnFailure = logicalParameter(cfg, 'errorOnFailure', true);

    case 'ndi.time.syncrule.filefind'
        params.number_fullpath_matches = requireNumber(cfg, ...
            'minimum_matching_file_paths', 'number_fullpath_matches', objClass);
        params.syncfilename = require(charField(cfg, 'sync_file_name'), ...
            'syncfilename', objClass);
        params.daqsystem1 = require(name1, 'daqsystem1', objClass);
        params.daqsystem2 = require(name2, 'daqsystem2', objClass);

    case 'ndi.time.syncrule.filematch'
        % filematch names NO devices. On did-schema #88 DID-matlab's
        % migrator converts it (PRED and 20211116 carry one each, e2e run
        % 39675528253), with the count as the method parameter labelled
        % 'minimum matching file paths' -- see spellingKey.
        params.number_fullpath_matches = requireNumber(cfg, ...
            'minimum_matching_file_paths', 'number_fullpath_matches', objClass);

    otherwise
        error('NDI:vintage:syncruleUnknownClass', ...
            ['no V_eta parameter reconstruction is defined for syncrule ' ...
             'class "%s". Its `parameters` set has to be declared here ' ...
             'before a migrated document can build one -- guessing would ' ...
             'produce a rule that runs and synchronises wrongly.'], objClass);
end
end

% ===================== helpers =============================================

function name = systemName(id, edgeName, ndi_session_obj)
%SYSTEMNAME The name of the acquisition_system a from/to edge names ('' if none).
name = '';
if isempty(id)
    return;
end
docs = ndi_session_obj.database_search( ...
    ndi.query('base.id', 'exact_string', id, ''));
if numel(docs) ~= 1
    error('NDI:vintage:syncruleSystemNotFound', ...
        ['%s names acquisition_system document %s and %d document(s) ' ...
         'match; the device name lives on it'], edgeName, id, numel(docs));
end
name = ndi.vintage.objectName(docs{1});
end

function v = triggerChannel(cfg, n)
%TRIGGERCHANNEL The n-th trigger channel string ('' if the configuration has none).
%   The two trigger channels are method parameters named by the link they
%   belong to: 'from trigger channel' goes with from_acquisition_system_id
%   (v1 daqsystem_ch1), 'to trigger channel' with to_acquisition_system_id
%   (v1 daqsystem_ch2) (did-schema V_eta_go_forward_class_audit.md, Jess
%   Haley 2026-10-30 [trigger channels named by their link]). A session
%   migrated before DID-matlab wrote those labels holds them under the v1
%   names, which jParameterList writes as 'daqsystem ch1' / 'daqsystem ch2';
%   those are read too, so a session migrated either way opens. The new
%   label wins when both are present.
names = {{'from trigger channel', 'daqsystem_ch1'}, ...
         {'to trigger channel',   'daqsystem_ch2'}};
v = '';
for k = 1:numel(names{n})
    v = charField(cfg, names{n}{k});
    if ~isempty(v)
        return;
    end
end
end

function v = logicalParameter(cfg, name, default)
%LOGICALPARAMETER A true/false method parameter, or DEFAULT when absent.
%   DID-matlab's jParameterList writes a v1 logical as a quantity (1 or 0);
%   a `logical` entry is read too.
v = default;
e = methodParameter(cfg, name);
if isempty(e)
    return;
end
[x, ~, kind] = ndi.v2.entryValue(e);
if any(strcmp(kind, {'quantity', 'count', 'logical'})) && isscalar(x)
    v = logical(x);
end
end

function [deviceName, channelSpec] = deviceHalf(channelIds, ndi_session_obj, n)
%DEVICEHALF Resolve the n-th channel group to a device name + channel spec.
arguments
    channelIds
    ndi_session_obj
    n (1,1) {mustBeNumeric}
end
deviceName = '';
channelSpec = '';
edgeName = sprintf('acquisition_channels (%d)', n);
if numel(channelIds) < n || isempty(channelIds{n})
    return;
end
id = channelIds{n};
docs = ndi_session_obj.database_search( ...
    ndi.query('base.id', 'exact_string', id, ''));
if numel(docs) ~= 1
    error('NDI:vintage:syncruleChannelsNotFound', ...
        ['%s names acquisition_channels document %s and %d document(s) ' ...
         'match; the device name and channels live on it'], ...
        edgeName, id, numel(docs));
end
p = docs{1}.document_properties;
% THE DEVICE NAME IS ON `base.name`, NOT BEHIND AN EDGE. The migrator
% deliberately does not emit `acquisition_system_id` -- resolving name to
% id needs the migrated-id graph, which a per-document migrator does not
% have -- so it carries the name where a name belongs
% (+migrators_j/private/jAcquisitionChannels.m).
if isfield(p, 'base') && isfield(p.base, 'name')
    deviceName = p.base.name;
end
% ...EXCEPT ON A DOCUMENT BUILT TO THE CURRENT SCHEMA. did-schema #73 item 54
% keeps a device's name on its acquisition_system (`acquisition_system.name`)
% and `base.name` is did_v1-only, so such a channel group names no device
% itself and reaches it through `acquisition_system_id`.
if isempty(deviceName)
    sysDoc = linkedDoc(docs{1}, ndi_session_obj, 'acquisition_system_id');
    if ~isempty(sysDoc)
        deviceName = ndi.vintage.objectName(sysDoc);
    end
end
if isfield(p, 'acquisition_channels') && isstruct(p.acquisition_channels) ...
        && isfield(p.acquisition_channels, 'channels')
    channelSpec = channelsToSpec(p.acquisition_channels.channels);
end
end

function spec = channelsToSpec(channels)
%CHANNELSTOSPEC The inverse of jAcquisitionChannels/parseChannelSpec.
%   Each entry is {type (an ontology_term), numbers}. v1 wrote e.g. 'dep1';
%   channel-TYPE GROUPS are separated by ';' and numbers within a group by
%   ',' (+ndi/+daq/daqsystemstring.m:15-19).
%
%   The DEVICE PREFIX is deliberately not re-emitted. v1 stores the device
%   in `daqsystem<N>_name` and the bare spec in `daqsystem_ch<N>`; the
%   'DEVICE:CT###' form is the alternative spelling the parser also
%   accepts, not what the pair-form documents carry.
spec = '';
if isempty(channels)
    return;
end
parts = {};
for k = 1:numel(channels)
    if iscell(channels)
        c = channels{k};
    else
        c = channels(k);
    end
    % the v1 prefix, read BY NODE (ndi.vintage.channelPrefix; Jess Haley
    % 2026-10-22 [channel types]): 'ai' whether the stored type is
    % {EMPTY:0000370, 'analog input channel'} or the bare 'ai'; a read mode
    % with no term ('dep') keeps its name
    t = '';
    if isfield(c, 'type')
        t = char(ndi.vintage.channelPrefix(c.type));
    end
    nums = [];
    if isfield(c, 'numbers')
        nums = c.numbers;
    end
    numTxt = strjoin(arrayfun(@(x) num2str(x), nums(:)', ...
        'UniformOutput', false), ',');
    parts{end+1} = [t numTxt]; %#ok<AGROW>
end
spec = strjoin(parts, ';');
end

function v = charField(s, name)
v = '';
if isstruct(s) && isfield(s, name)
    v = s.(name);
    return;
end
e = methodParameter(s, name);
if ~isempty(e)
    [x, sv, kind] = ndi.v2.entryValue(e);
    if strcmp(kind, 'text')
        v = x;
    elseif strcmp(kind, 'quantity')
        v = char(sv);
    end
end
end

function d = linkedDoc(doc, ndi_session_obj, edgeName)
%LINKEDDOC The one document an edge names, or [] if it names none.
arguments
    doc
    ndi_session_obj
    edgeName {mustBeText}
end
d = [];
id = doc.dependency_value(edgeName, 'ErrorIfNotFound', 0);
if isempty(id)
    return;
end
hits = ndi_session_obj.database_search(ndi.query('base.id', 'exact_string', id, ''));
if numel(hits) == 1
    d = hits{1};
end
end

function e = methodParameter(cfg, name)
%METHODPARAMETER A knob held in the method's parameters, or [] if absent.
%   `method.parameters` since did-schema #88 (V_eta_method_plan.md);
%   `method_parameters` before it -- a session migrated against either
%   schema is read.
%   did-schema #73 item 22 turned the typed fields into `parameter[]`
%   entries named by `variable`. Until that variable is bound it is a LABEL
%   ({name}, no node), so an entry is matched by the V_eta field name or by
%   the v1 parameter name it came from.

arguments
    cfg
    name {mustBeText}
end
e = [];
if ~isstruct(cfg)
    return;
end
if isfield(cfg, 'method') && isstruct(cfg.method) && isfield(cfg.method, 'parameters')
    mp = cfg.method.parameters;          % did-schema #88: method {term, parameters}
elseif isfield(cfg, 'method_parameters')
    mp = cfg.method_parameters;          % #73 item 22, before #88
else
    mp = [];
end
if isempty(mp)
    return;
end
v1Names = struct('minimum_matching_file_paths', 'number_fullpath_matches', ...
    'sync_file_name', 'syncfilename', ...
    'minimum_embedded_file_overlap', 'minEmbeddedFileOverlap');
wanted = {name};
if isfield(v1Names, name)
    wanted{end+1} = v1Names.(name);
end
for k = 1:numel(mp)
    if iscell(mp), c = mp{k}; else, c = mp(k); end
    if isfield(c, 'variable') && isstruct(c.variable) && isfield(c.variable, 'name') ...
            && any(strcmp(spellingKey(c.variable.name), cellfun(@spellingKey, wanted, ...
                'UniformOutput', false)))
        e = c;
        return;
    end
end
end

function k = spellingKey(name)
%SPELLINGKEY A parameter label compared without case, spaces or underscores:
%   DID-matlab's #88 syncrule migrator labels the count 'minimum matching file
%   paths' (+migrators_j/syncrule.m, jLabel), the V_eta field name is
%   minimum_matching_file_paths, and v1 called it number_fullpath_matches.
k = lower(regexprep(char(name), '[\s_]', ''));
end

function v = require(v, whatV1Called, objClass)
%REQUIRE Fail loudly, naming the parameter, rather than returning empty.
if isempty(v)
    error('NDI:vintage:syncruleMissingField', ...
        ['cannot rebuild `%s` for a %s from this ' ...
         'clock_alignment_configuration. Only `errorOnFailure` has a ' ...
         'documented default; every other parameter is experiment data ' ...
         'and inventing one would produce a rule that synchronises ' ...
         'wrongly.'], whatV1Called, objClass);
end
end

function v = requireNumber(cfg, etaName, whatV1Called, objClass)
if isstruct(cfg) && isfield(cfg, etaName) && ~isempty(cfg.(etaName))
    v = cfg.(etaName);
    return;
end
e = methodParameter(cfg, etaName);
[x, ~, kind] = ndi.v2.entryValue(e);
if any(strcmp(kind, {'quantity', 'count'}))
    v = x;
    return;
end
error('NDI:vintage:syncruleMissingField', ...
    ['cannot rebuild `%s` for a %s: the configuration carries no ' ...
     '`%s`, as a field or as a method parameter.'], ...
    whatV1Called, objClass, etaName);
end
