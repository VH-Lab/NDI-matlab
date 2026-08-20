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
%     RENAMED into typed fields on `clock_alignment_configuration`
%         epochclocktype           -> clock (an ontology_term; the name half)
%         number_fullpath_matches  -> minimum_matching_file_paths
%         syncfilename             -> sync_file_name
%         minEmbeddedFileOverlap   -> minimum_embedded_file_overlap
%
%     MOVED OUT into two `acquisition_channels` documents, one per device.
%         daqsystem1_name / daqsystem1 <- acquisition_channels_1.base.name
%         daqsystem_ch1                <- its `channels` array, re-serialised
%         (and _2 likewise). The pair is UNORDERED by construction -- the
%         migrator's own note: the rule is symmetric and both consumers
%         accept either order -- so 1 and 2 here are just the edge indices.
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
if isfield(props, entry.eta_class) && isstruct(props.(entry.eta_class))
    cfg = props.(entry.eta_class);
end

% ---- the two device documents ----------------------------------------
[name1, ch1] = deviceHalf(ruleDoc, ndi_session_obj, 1);
[name2, ch2] = deviceHalf(ruleDoc, ndi_session_obj, 2);

% ---- the typed fields -------------------------------------------------
clockName = '';
if isfield(cfg, 'clock') && isstruct(cfg.clock) && isfield(cfg.clock, 'name')
    clockName = cfg.clock.name;
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
        % THE ONE INVENTED VALUE. See the header.
        params.errorOnFailure = true;

    case 'ndi.time.syncrule.filefind'
        params.number_fullpath_matches = requireNumber(cfg, ...
            'minimum_matching_file_paths', 'number_fullpath_matches', objClass);
        params.syncfilename = require(charField(cfg, 'sync_file_name'), ...
            'syncfilename', objClass);
        params.daqsystem1 = require(name1, 'daqsystem1', objClass);
        params.daqsystem2 = require(name2, 'daqsystem2', objClass);

    case 'ndi.time.syncrule.filematch'
        % filematch names NO devices, so the migrator PASSES IT THROUGH as
        % a v1 `syncrule` and this branch is not reached on real data. It
        % is here so an unexpected converted filematch fails on the
        % missing count rather than on a missing case.
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

function [deviceName, channelSpec] = deviceHalf(ruleDoc, ndi_session_obj, n)
%DEVICEHALF Resolve `acquisition_channels_<n>` to a device name + channel spec.
deviceName = '';
channelSpec = '';
edgeName = sprintf('acquisition_channels_%d', n);
id = ruleDoc.dependency_value(edgeName, 'ErrorIfNotFound', 0);
if isempty(id)
    return;
end
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
    t = '';
    if isfield(c, 'type')
        if isstruct(c.type) && isfield(c.type, 'name')
            t = c.type.name;
        elseif ischar(c.type)
            t = c.type;
        end
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
end
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
if ~isstruct(cfg) || ~isfield(cfg, etaName) || isempty(cfg.(etaName))
    error('NDI:vintage:syncruleMissingField', ...
        ['cannot rebuild `%s` for a %s: the configuration carries no ' ...
         '`%s`.'], whatV1Called, objClass, etaName);
end
v = cfg.(etaName);
end
