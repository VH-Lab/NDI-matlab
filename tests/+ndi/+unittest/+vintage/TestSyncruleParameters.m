classdef TestSyncruleParameters < matlab.unittest.TestCase
%TESTSYNCRULEPARAMETERS ndi.vintage.syncruleParameters on the did-schema #88
%   clock_alignment_configuration a migrated file-based syncrule becomes.
%
%   e2e run 39675528253 (PRED and 20211116): opening a migrated session
%   failed in ndi.time.syncgraph with NDI:vintage:syncruleMissingField
%   ("configuration carries no `minimum_matching_file_paths`"), although the
%   count was there. DID-matlab's #88 syncrule migrator writes it as a method
%   parameter labelled 'minimum matching file paths' (+migrators_j/syncrule.m,
%   jLabel), with spaces; the reader compared the label to
%   'minimum_matching_file_paths' / 'number_fullpath_matches' exactly.
%
%   The rigs, both shapes (Jess Haley 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md [sync configuration links its rigs],
%   [sync rule direction is recorded]): the current configuration links
%   `from_acquisition_system_id` (v1 daqsystem1) and
%   `to_acquisition_system_id` (v1 daqsystem2) with the trigger channels as
%   method parameters; the earlier one reaches each rig through an
%   `acquisition_channels` document. Both rebuild the same v1 parameters.

    methods (Test)

        function testTheSpacedLabelIsRead(testCase)
            % the shape read back from PRED's migrated database
            doc = configDoc('minimum matching file paths', 2);
            params = ndi.vintage.syncruleParameters(doc, [], ...
                'ndi.time.syncrule.filematch');
            testCase.verifyEqual(params.number_fullpath_matches, 2);
        end

        function testTheFieldNameAndTheV1NameStillRead(testCase)
            for name = {'minimum_matching_file_paths', 'number_fullpath_matches'}
                doc = configDoc(name{1}, 3);
                params = ndi.vintage.syncruleParameters(doc, [], ...
                    'ndi.time.syncrule.filematch');
                testCase.verifyEqual(params.number_fullpath_matches, 3, name{1});
            end
        end

        function testAnUnrelatedLabelIsStillAnError(testCase)
            % the reader still refuses to invent the count
            doc = configDoc('minimum embedded file overlap', 2);
            testCase.verifyError(@() ndi.vintage.syncruleParameters(doc, [], ...
                'ndi.time.syncrule.filematch'), 'NDI:vintage:syncruleMissingField');
        end

        function testFilefindFromToEdgesAreRead(testCase)
            entries = {param('minimum matching file paths', 'count', 1), ...
                param('sync file name', 'text', 'sync.txt')};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.filefind');
            testCase.verifyEqual(params.daqsystem1, 'intan1');
            testCase.verifyEqual(params.daqsystem2, 'vhvis1');
            testCase.verifyEqual(params.number_fullpath_matches, 1);
            testCase.verifyEqual(params.syncfilename, 'sync.txt');
        end

        function testFromIsDaqsystem1AndToIsDaqsystem2(testCase)
            % the direction is recorded: swapping the edges swaps the names
            entries = {param('minimum matching file paths', 'count', 1), ...
                param('sync file name', 'text', 'sync.txt')};
            doc = linkedConfigDoc(entries, 'sys_b', 'sys_a');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.filefind');
            testCase.verifyEqual(params.daqsystem1, 'vhvis1');
            testCase.verifyEqual(params.daqsystem2, 'intan1');
        end

        function testTriggerChannelsAreMethodParameters(testCase)
            % a channel-based rule: the channels are the parameters
            % DID-matlab's jParameterList writes ('daqsystem ch1', text);
            % a session migrated before [trigger channels named by their
            % link] holds these labels and must still open
            entries = {param('daqsystem ch1', 'text', 'dep1'), ...
                param('daqsystem ch2', 'text', 'mk1'), ...
                param('minimum embedded file overlap', 'quantity', 2), ...
                param('errorOnFailure', 'quantity', 0)};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b', 'dev_local_time');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.commonTriggersOverlappingEpochs');
            testCase.verifyEqual(params.daqsystem1_name, 'intan1');
            testCase.verifyEqual(params.daqsystem2_name, 'vhvis1');
            testCase.verifyEqual(params.daqsystem_ch1, 'dep1');
            testCase.verifyEqual(params.daqsystem_ch2, 'mk1');
            testCase.verifyEqual(params.epochclocktype, 'dev_local_time');
            testCase.verifyEqual(params.minEmbeddedFileOverlap, 2);
            testCase.verifyEqual(params.errorOnFailure, false);
        end

        function testTriggerChannelsNamedByTheirLink(testCase)
            % Jess Haley 2026-10-30 [trigger channels named by their link]:
            % the labels match the from / to edges
            entries = {param('from trigger channel', 'text', 'dep1'), ...
                param('to trigger channel', 'text', 'mk1'), ...
                param('minimum embedded file overlap', 'quantity', 2)};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b', 'dev_local_time');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.commonTriggersOverlappingEpochs');
            testCase.verifyEqual(params.daqsystem1_name, 'intan1');
            testCase.verifyEqual(params.daqsystem2_name, 'vhvis1');
            testCase.verifyEqual(params.daqsystem_ch1, 'dep1');
            testCase.verifyEqual(params.daqsystem_ch2, 'mk1');
        end

        function testTriggerChannelLabelsAreSpellingTolerant(testCase)
            % compared without case, spaces or underscores, as every
            % other method parameter here
            entries = {param('From_Trigger_Channel', 'text', 'dep1'), ...
                param('to_trigger_channel', 'text', 'mk1')};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b', 'dev_local_time');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.randomPulses');
            testCase.verifyEqual(params.daqsystem_ch1, 'dep1');
            testCase.verifyEqual(params.daqsystem_ch2, 'mk1');
        end

        function testTheNewTriggerLabelWinsOverTheOld(testCase)
            entries = {param('daqsystem ch1', 'text', 'old1'), ...
                param('from trigger channel', 'text', 'dep1'), ...
                param('daqsystem ch2', 'text', 'old2'), ...
                param('to trigger channel', 'text', 'mk1')};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b', 'dev_local_time');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.randomPulses');
            testCase.verifyEqual(params.daqsystem_ch1, 'dep1');
            testCase.verifyEqual(params.daqsystem_ch2, 'mk1');
        end

        function testAMissingTriggerChannelIsStillAnError(testCase)
            % only one of the two: the reader still refuses to invent one
            entries = {param('from trigger channel', 'text', 'dep1')};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b', 'dev_local_time');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            testCase.verifyError(@() ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.randomPulses'), 'NDI:vintage:syncruleMissingField');
        end

        function testErrorOnFailureDefaultsWhenAbsent(testCase)
            entries = {param('daqsystem ch1', 'text', 'dep1'), ...
                param('daqsystem ch2', 'text', 'mk1')};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_b', 'dev_local_time');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.randomPulses');
            testCase.verifyEqual(params.errorOnFailure, true);
        end

        function testAnUnresolvedSystemEdgeIsAnError(testCase)
            entries = {param('minimum matching file paths', 'count', 1), ...
                param('sync file name', 'text', 'sync.txt')};
            doc = linkedConfigDoc(entries, 'sys_a', 'sys_missing');
            session = mockSession({systemDoc('sys_a', 'intan1')});
            testCase.verifyError(@() ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.filefind'), 'NDI:vintage:syncruleSystemNotFound');
        end

        function testTheAcquisitionChannelsShapeStillReads(testCase)
            % the earlier shape: no from/to edge, two acquisition_channels
            % each naming its acquisition_system
            entries = {param('minimum matching file paths', 'count', 1), ...
                param('sync file name', 'text', 'sync.txt')};
            doc = configWithEdges(entries, ...
                {'acquisition_channels_id', 'ch_a'; 'acquisition_channels_id', 'ch_b'}, '');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1'), ...
                channelsDoc('ch_a', 'sys_a'), channelsDoc('ch_b', 'sys_b')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.filefind');
            testCase.verifyEqual(params.daqsystem1, 'intan1');
            testCase.verifyEqual(params.daqsystem2, 'vhvis1');
        end

        function testTheSystemSOwnNameWinsOverBaseName(testCase)
            % [carried v1 validates against NDI templates] (Jess Haley,
            % 2026-10-27): the device name is read from the linked
            % acquisition_system's own `name` first, base.name after
            entries = {param('minimum matching file paths', 'count', 1), ...
                param('sync file name', 'text', 'sync.txt')};
            doc = configWithEdges(entries, ...
                {'acquisition_channels_id', 'ch_a'; 'acquisition_channels_id', 'ch_b'}, '');
            session = mockSession({systemDoc('sys_a', 'intan1'), systemDoc('sys_b', 'vhvis1'), ...
                channelsDoc('ch_a', 'sys_a', 'stale_a'), channelsDoc('ch_b', 'sys_b', 'stale_b')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.filefind');
            testCase.verifyEqual(params.daqsystem1, 'intan1');
            testCase.verifyEqual(params.daqsystem2, 'vhvis1');
        end

        function testBaseNameStillReadsWithNoSystemEdge(testCase)
            % a channel group migrated before: no acquisition_system_id, the
            % device name on base.name
            entries = {param('minimum matching file paths', 'count', 1), ...
                param('sync file name', 'text', 'sync.txt')};
            doc = configWithEdges(entries, ...
                {'acquisition_channels_id', 'ch_a'; 'acquisition_channels_id', 'ch_b'}, '');
            session = mockSession({channelsDoc('ch_a', '', 'intan1'), ...
                channelsDoc('ch_b', '', 'vhvis1')});
            params = ndi.vintage.syncruleParameters(doc, session, ...
                'ndi.time.syncrule.filefind');
            testCase.verifyEqual(params.daqsystem1, 'intan1');
            testCase.verifyEqual(params.daqsystem2, 'vhvis1');
        end

    end
end

function e = param(label, kind, value)
e = struct('variable', struct('name', label));
switch kind
    case 'quantity'
        e.quantity = struct('value', value, 'source_value', num2str(value));
    otherwise
        e.(kind) = value;
end
end

function doc = linkedConfigDoc(entries, fromId, toId, clockName)
if nargin < 4, clockName = ''; end
doc = configWithEdges(entries, ...
    {'from_acquisition_system_id', fromId; 'to_acquisition_system_id', toId}, clockName);
end

function doc = configWithEdges(entries, edges, clockName)
p = struct();
p.document_class = struct('class_name', 'clock_alignment_configuration', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
deps = struct('name', 'session_id', 'value', 'sess_1');
for k = 1:size(edges, 1)
    deps(end+1) = struct('name', edges{k, 1}, 'value', edges{k, 2}); %#ok<AGROW>
end
p.depends_on = deps;
p.base = struct('id', 'cfg_1', 'creation_timestamp', '2026-01-01T00:00:00.000Z');
p.clock_alignment_configuration = struct('clock', struct('node', '', 'name', clockName), ...
    'method', struct('parameters', {entries}));
doc = ndi.document(p);
end

function doc = systemDoc(id, name)
p = struct();
p.document_class = struct('class_name', 'acquisition_system', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
p.depends_on = struct('name', 'session_id', 'value', 'sess_1');
p.base = struct('id', id, 'creation_timestamp', '2026-01-01T00:00:00.000Z');
p.acquisition_system = struct('name', name);
doc = ndi.document(p);
end

function doc = channelsDoc(id, systemId, baseName)
%CHANNELSDOC An acquisition_channels document; SYSTEMID '' omits the
%   acquisition_system_id edge, BASENAME (optional) sets base.name.
p = struct();
p.document_class = struct('class_name', 'acquisition_channels', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
if isempty(systemId)
    p.depends_on = struct('name', 'session_id', 'value', 'sess_1');
else
    p.depends_on = struct('name', {'session_id', 'acquisition_system_id'}, ...
        'value', {'sess_1', systemId});
end
p.base = struct('id', id, 'creation_timestamp', '2026-01-01T00:00:00.000Z');
if nargin >= 3
    p.base.name = baseName;
end
p.acquisition_channels = struct('channels', {{}});
doc = ndi.document(p);
end

function s = mockSession(docs)
%MOCKSESSION The one call syncruleParameters makes: a search by base.id.
s = struct('database_search', @(q) byId(docs, q));
end

function hits = byId(docs, q)
id = q.searchstructure(1).param1;
hits = {};
for k = 1:numel(docs)
    if strcmp(docs{k}.document_properties.base.id, id)
        hits{end+1} = docs{k}; %#ok<AGROW>
    end
end
end

function doc = configDoc(label, count)
p = struct();
p.document_class = struct('class_name', 'clock_alignment_configuration', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
p.depends_on = struct('name', 'session_id', 'value', 'sess_1');
p.base = struct('id', 'cfg_1', 'creation_timestamp', '2026-01-01T00:00:00.000Z');
p.clock_alignment_configuration = struct('method', struct('parameters', ...
    struct('variable', struct('name', label), 'count', count)));
doc = ndi.document(p);
end
