classdef TestIngestedV2Shapes < matlab.unittest.TestCase
%TESTINGESTEDV2SHAPES The readers of migrated ingested data read the shapes the 2026-11-17 decisions give.
%
%   NDI's readers of a migrated ingested epoch (ndi.vintage.ingestedArchive,
%   ndi.daq.reader.mfdaq) read both the shape migration writes today and the
%   one Jess Haley's decisions of 2026-11-17 give (did-schema
%   did_v2_go_forward_class_audit.md), readers first:
%
%     [time channel is a per-channel covariate]  a channel's time channel is
%         the "time channel" covariate (EMPTY:0000374) of its group's body,
%         NaN and dangling values carried; NaN when the body has none
%     [event channels are time-valued observations], [channel list rows get
%         v2 homes]  each event or marker channel is its own observation,
%         its channel type and number a condition; an event channel's body
%         holds its times, a marker channel's its codes, keyed to a `time`
%         value whose body holds the times
%     [unpacked event bodies are uncompressed]  little-endian float64
%     [ingested body members use the schema's names]  body_data_0, ...
%     [channel name is an identifier]  a channel's v1 name is the text
%         covariate of its group's body, variable NCIT:C25364 "Identifier",
%         one value per channel; `<prefix><number>` when the body has none
%   and Jess Haley's decisions of 2026-11-19 (did-schema
%   did_v2_standing_wiring_plan.md):
%     [time channel row is notation]  a time channel's own row is rebuilt
%         from the groups that name it (`t<n>`, time_channel n, the groups'
%         sample rate, offset 0, scale 1), so the v1 lists here hold the
%         time row NDI's Intan reader writes (`t1`, intan.m getchannelsepoch)
%     [text channel entries are a JSON array]  a text channel's entries are
%         read back as NDI-compress's expander gives them
%
%   The channel list a reader rebuilds without `channel_list.bin` must be the
%   list NDI's ingest wrote (ndi.file.type.mfdaq_epoch_channel), row for row:
%   these tests build the v1 list with NDI's own writer and the v2 bodies with
%   DID-matlab's builders, and compare. The whole read on a migrated Intan
%   session is TestReadTimeseriesEquivalence.

    methods (TestClassSetup)
        function needBuilders(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.sampledBody')) && ...
                ~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no DID-matlab v2 builders and schema set');
        end
    end

    methods (Test)

        function testTodaysShapeHasNoTimeChannel(testCase)
            % a group body without the time-channel covariate (the second
            % pass before [time channel is a per-channel covariate]) reads
            % NaN, as before
            ch = v1Rows('ai', 'analog_in', 1:3, NaN(1, 3), 20000, 32768, 0.195);
            want = ndi.file.type.mfdaq_epoch_channel(ch).channel_information;
            got = ndi.vintage.ingestedChannelList({groupBody('ai', 1, ch, false)});
            testCase.verifyTrue(isequaln(got, want), describe(got, want));
        end

        function testTheTimeChannelCovariateIsRead(testCase)
            % Intan: analog and digital inputs on time channel 1, auxiliary
            % on 2 (a time channel the ingest never writes, VH-Lab/NDI-matlab#1249);
            % a NaN is carried
            ai = v1Rows('ai', 'analog_in', 1:2, [1 1], 20000, 32768, 0.195);
            ax = v1Rows('ax', 'auxiliary_in', 1:3, [2 2 NaN], 5000, 0, 3.74e-05);
            di = v1Rows('di', 'digital_in', 1:2, [1 1], 20000, 0, 1);
            t1 = v1Rows('t', 'time', 1, 1, 20000, 0, 1);
            v1list = ndi.file.type.mfdaq_epoch_channel([ai, ax, di, t1]).channel_information;
            % [time channel row is notation]: t1 from the groups that name
            % it (ai, di at 20 kHz), and t2, which the auxiliary inputs name
            % but the ingest never writes: no group is all t2, so no rate
            t2 = v1Rows('t', 'time', 2, 2, NaN, 0, 1);
            want = ndi.file.type.mfdaq_epoch_channel([ai, ax, di, t1, t2]).channel_information;
            bodies = {groupBody('di', 1, di, true), groupBody('ai', 1, ai, true), ...
                groupBody('ax', 1, ax, true)};
            got = ndi.vintage.ingestedChannelList(bodies);
            testCase.verifyTrue(isequaln(got, want), describe(got, want));
            testCase.verifyNotEqual(numel(got), numel(v1list), ...
                'the dangling t2 is rebuilt: such a v1 list does not compare exactly, so the second pass keeps it');
            % as the database gives the documents back (JSON: NaN is null)
            back = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
            got2 = ndi.vintage.ingestedChannelList(back);
            testCase.verifyTrue(isequaln(got2, want), describe(got2, want));
        end

        function testTheNewNumericShapeReadsTheSame(testCase)
            % did-schema did_v2_numeric_shape_plan.md ([one shape for
            % measured numbers], Jess Haley, 2026-11-17): the group bodies
            % written by DID-matlab's builders in the new numeric shape (the
            % time axis's spacing a plain number, the offset, scale and time
            % channel flat `numeric`) rebuild the same channel list
            testCase.assumeTrue(~isempty(which('did2.build.numericShape')), ...
                'no DID-matlab builders that write the new numeric shape');
            ai = v1Rows('ai', 'analog_in', 1:2, [1 1], 20000, 32768, 0.195);
            ax = v1Rows('ax', 'auxiliary_in', 1:3, [2 2 NaN], 5000, 0, 3.74e-05);
            t = [v1Rows('t', 'time', 1, 1, 20000, 0, 1), v1Rows('t', 'time', 2, 2, NaN, 0, 1)];
            want = ndi.file.type.mfdaq_epoch_channel([ai, ax, t]).channel_information;
            prev = did2.build.numericShape('new');
            testCase.addTeardown(@() did2.build.numericShape(prev));
            bodies = {groupBody('ai', 1, ai, true), groupBody('ax', 1, ax, true)};
            txt = jsonencode(bodies{1});
            testCase.verifyTrue(contains(txt, '"numeric"') && ~contains(txt, '"quantity"'), ...
                'the fixture is in the new numeric shape');
            got = ndi.vintage.ingestedChannelList(bodies);
            testCase.verifyTrue(isequaln(got, want), describe(got, want));
            back = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
            got2 = ndi.vintage.ingestedChannelList(back);
            testCase.verifyTrue(isequaln(got2, want), describe(got2, want));
        end

        function testTheOldNumericShapeIsRefused(testCase)
            % the same group bodies written in the old numeric shape (the
            % spacing a {value, source_value} block, the offset and scale a
            % `quantity`) are not read ([no migrated database is kept], Jess
            % Haley, 2026-11-19): the database is migrated again from v1
            % The old shape is written by hand from the builder's new-shape
            % body: DID-matlab's builders write only what did-schema
            % declares, and did-schema removed the old list shape (numeric
            % shape plan section 9 step 4, did-schema #373), so the refusal is
            % checked whatever the schema declares.
            testCase.assumeTrue(~isempty(which('did2.build.numericShape')), ...
                'no DID-matlab builders that write the new numeric shape');
            ai = v1Rows('ai', 'analog_in', 1:2, [1 1], 20000, 32768, 0.195);
            prev = did2.build.numericShape('new');
            testCase.addTeardown(@() did2.build.numericShape(prev));
            bodies = {oldShapeBody(groupBody('ai', 1, ai, true))};
            txt = jsonencode(bodies{1});
            testCase.verifyTrue(contains(txt, '"quantity"') && ~contains(txt, '"numeric"') ...
                && ~contains(txt, '"source_origin"'), 'the fixture is in the old numeric shape');
            testCase.verifyError(@() ndi.vintage.ingestedChannelList(bodies), ...
                'ndi:v2:oldNumericShapeReMigrate');
        end

        function testTheNameCovariateIsRead(testCase)
            % [channel name is an identifier] (Jess Haley, 2026-11-17): the
            % names NDI's writer kept (it reads each number from the name)
            % come back from the Identifier covariate, by node; an empty
            % entry is the standard name
            ai = v1Rows('ai', 'analog_in', 1:3, [1 1 1], 20000, 32768, 0.195);
            [ai.name] = deal('A-001', 'A-002', 'ai3');
            t1 = v1Rows('t', 'time', 1, 1, 20000, 0, 1);
            want = ndi.file.type.mfdaq_epoch_channel([ai, t1]).channel_information;
            b = groupBody('ai', 1, ai, true, {'A-001', 'A-002', ''});
            got = ndi.vintage.ingestedChannelList({b});
            testCase.verifyTrue(isequaln(got, want), describe(got, want));
            back = ndi.vintage.ingestedChannelList({jsondecode(jsonencode(b))});
            testCase.verifyTrue(isequaln(back, want), describe(back, want));
            % a text covariate with another variable is not a name (a check
            % that cannot fail proves nothing)
            b2 = groupBody('ai', 1, ai, true, {'A-001', 'A-002', ''}, ...
                struct('node', 'NCIT:C42614', 'name', 'Name'));
            got2 = ndi.vintage.ingestedChannelList({b2});
            testCase.verifyEqual({got2.name}, {'ai1', 'ai2', 'ai3', 't1'});
        end

        function testEventAndMarkerRowsComeFromTheirObservations(testCase)
            ai = v1Rows('ai', 'analog_in', 1:2, [1 1], 20000, 0, 1);
            ev = struct('name', {'e1', 'mk2', 'mk1'}, 'type', {'event', 'marker', 'marker'}, ...
                'time_channel', NaN, 'sample_rate', NaN, 'offset', 0, 'scale', 1);
            t1 = v1Rows('t', 'time', 1, 1, 20000, 0, 1);
            want = ndi.file.type.mfdaq_epoch_channel([ai, t1, ev]).channel_information;
            [st, bodies] = eventDocs();
            E = ndi.vintage.ingestedEventChannels(st, bodies);
            testCase.verifyEqual({E.type}, {'event', 'marker', 'marker'});
            testCase.verifyEqual([E.number], [1 2 1]);
            testCase.verifyEqual(E(1).times.base.id, 'b_e1', 'an event channel''s body is its times');
            testCase.verifyEqual(E(2).values.base.id, 'b_mk2');
            testCase.verifyEqual(E(2).times.base.id, 'b_t_mk2', ...
                'a marker channel''s times are the body of the time value it keys to');
            got = ndi.vintage.ingestedChannelList({groupBody('ai', 1, ai, true)}, E);
            testCase.verifyTrue(isequaln(got, want), describe(got, want));
        end

        function testARecordingObservationIsNoEventChannel(testCase)
            obs = statementDoc('obs_1', 'voltage', {});
            testCase.verifyEmpty(ndi.vintage.ingestedEventChannels({obs}, {}));
        end

        function testEventDataIsWhatTheExpanderGives(testCase)
            [T, D] = ndi.vintage.ingestedEventData('event', [0.1 0.5 0.7]);
            testCase.verifyEqual(T, [0.1; 0.5; 0.7]);
            testCase.verifyEqual(D, ones(3, 1));
            [T, D] = ndi.vintage.ingestedEventData('marker', [0.1; 0.5], [7 2]);
            testCase.verifyEqual(T, [0.1; 0.5]);
            testCase.verifyEqual(D, [7; 2]);
            % [text channel entries are a JSON array] (Jess Haley,
            % 2026-11-19): a text channel's entries, a 1xN cell of character
            % rows as ndi.compress.vector2eventmarktext builds them
            [T, D] = ndi.vintage.ingestedEventData('text', [0.1; 0.5], {'go'; ''});
            testCase.verifyEqual(T, [0.1; 0.5]);
            testCase.verifyEqual(D, {'go', char(zeros(1, 0))});
            bytes = ndi.vintage.ingestedTextEntries('encode', {'go', ['caf' char(233)], ''});
            testCase.verifyEqual(char(bytes), ['["go","caf' char([195 169]) '",""]'], ...
                'one UTF-8 JSON array of strings');
            testCase.verifyEqual(ndi.vintage.ingestedTextEntries('decode', bytes), ...
                {'go', ['caf' char(233)], char(zeros(1, 0))});
            testCase.verifyError(@() ndi.vintage.ingestedEventData('time', 1, []), ...
                'NDI:daq:reader:ingestedEventType');
        end

    end
end

% =====================================================================

function ch = v1Rows(prefix, type, nums, tc, sr, off, sc)
% the rows NDI's ingest hands ndi.file.type.mfdaq_epoch_channel
ch = struct('name', {}, 'type', {}, 'time_channel', {}, 'sample_rate', {}, ...
    'offset', {}, 'scale', {});
for k = 1:numel(nums)
    ch(end+1) = struct('name', sprintf('%s%d', prefix, nums(k)), 'type', type, ...
        'time_channel', tc(k), 'sample_rate', sr, 'offset', off, 'scale', sc); %#ok<AGROW>
end
end

function b = groupBody(prefix, g, ch, withTimeChannel, names, nameVariable)
% a channel group's sampled_body as ndi.migrate.internal.ingestedArchiveBodies
% writes it; NAMES (optional), the name covariate's entries ([channel name is
% an identifier]), under NAMEVARIABLE (NCIT:C25364 "Identifier")
if nargin < 5; names = {}; end
if nargin < 6; nameVariable = struct('node', 'NCIT:C25364', 'name', 'Identifier'); end
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
nodes = struct('ai', 'EMPTY:0000370', 'ax', 'EMPTY:0000375', 'di', 'EMPTY:0000372');
timeTerm = struct('node', 'om:Time', 'name', 'time');
channelTerm = struct('node', 'NCIT:C44170', 'name', 'Channel');
nums = NaN(1, numel(ch));
for k = 1:numel(ch)
    [~, nums(k)] = ndi.fun.channelname2prefixnumber(ch(k).name);
end
covs = {did2.build.covariate(timeTerm, 0, 'Origin', 0, 'Spacing', 1 / ch(1).sample_rate, ...
        'Unit', struct('node', 'om:second-Time', 'name', 'second')), ...
    did2.build.covariate(struct('node', '', 'name', 'channel number'), 1, 'Count', nums), ...
    did2.build.covariate(struct('node', 'AFO:AFQ_0000202', 'name', 'signal offset configuration'), ...
        1, 'Value', [ch.offset]), ...
    did2.build.covariate(struct('node', 'NCIT:C70774', 'name', 'Unit Conversion Factor'), ...
        1, 'Value', [ch.scale])};
if withTimeChannel
    covs{end+1} = did2.build.covariate(struct('node', 'EMPTY:0000374', 'name', 'time channel'), ...
        1, 'Value', [ch.time_channel]);
end
if ~isempty(names)
    covs{end+1} = did2.build.covariate(nameVariable, 1, 'Text', names);
end
b = did2.build.sampledBody({'obs_1'}, did2.build.list( ...
        did2.build.dimension(timeTerm, 100), did2.build.dimension(channelTerm, numel(ch))), ...
    'Covariates', did2.build.list(covs{:}), ...
    'Conditions', did2.build.condition(channelTerm, 'Term', ...
        struct('node', nodes.(prefix), 'name', prefix)), ...
    'DatumOrder', 'F', 'Fields', struct('filename', sprintf('%s_group%d_seg.nbf_#', prefix, g)), ...
    'Id', sprintf('b_%s%d', prefix, g), 'SessionId', 'sess_1', 'Validate', false);
end

function b = oldShapeBody(b)
% the body B (new numeric shape) with its covariates in the OLD shape, by
% hand: a flat origin/spacing becomes the {value, source_value} block, a
% `numeric` the `quantity` {value, source_value} wrapper (did-schema
% did_v2_numeric_shape_plan.md section 4, "Today")
covs = b.data.covariates;
if ~iscell(covs); covs = num2cell(covs); end
for k = 1:numel(covs)
    e = covs{k};
    o = struct();
    for f = reshape(fieldnames(e), 1, [])
        if ~any(strcmp(f{1}, {'numeric', 'source_numeric', 'tolerance', 'origin', 'spacing', ...
                'source_origin', 'source_spacing'})) && ~isempty(e.(f{1}))
            o.(f{1}) = e.(f{1});
        end
    end
    if isfield(e, 'origin') && ~isempty(e.origin)
        o.origin = struct('value', e.origin, 'source_value', e.origin);
        o.spacing = struct('value', e.spacing, 'source_value', e.spacing);
    end
    if isfield(e, 'numeric') && ~isempty(e.numeric)
        o.quantity = struct('value', e.numeric, 'source_value', e.numeric);
    end
    covs{k} = o;
end
b.data.covariates = covs;
end

function d = statementDoc(id, kind, conds)
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
args = {};
if ~isempty(conds); args = {'Conditions', did2.build.list(conds{:})}; end
d = did2.build.statement('observation', 'probe_1', struct('node', '', 'name', kind), [], ...
    'ValueKind', kind, 'DataBody', true, 'TimeReferenceIds', {'tr_1'}, ...
    'AcquisitionSystemId', 'sys_1', 'Id', id, 'SessionId', 'sess_1', 'Validate', false, args{:});
end

function [st, bodies] = eventDocs()
% an event channel e1 and marker channels mk2 and mk1, unpacked
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
timeTerm = struct('node', 'om:Time', 'name', 'time');
ev = struct('node', 'EMPTY:0000376', 'name', 'event channel');
mk = struct('node', 'EMPTY:0000377', 'name', 'marker channel');
st = {statementDoc('obs_rec', 'voltage', {}), ...
    statementDoc('obs_e1', 'time', {did2.build.condition(ev, 'Count', 1)}), ...
    statementDoc('obs_mk2', 'label', {did2.build.condition(mk, 'Count', 2)}), ...
    statementDoc('obs_mk1', 'label', {did2.build.condition(mk, 'Count', 1)})};
bodies = {did2.build.sampledBody({'obs_e1'}, did2.build.dimension(timeTerm, 3), ...
        'ByteOrder', 'little', 'Id', 'b_e1', 'SessionId', 'sess_1', 'Validate', false)};
for n = [2 1]
    tv = sprintf('tv_mk%d', n);
    bodies{end+1} = did2.build.sampledBody({sprintf('obs_mk%d', n)}, ...
        did2.build.dimension(timeTerm, 2), ...
        'Covariates', did2.build.covariate(timeTerm, 0, 'Key', 0), 'KeyIds', {tv}, ...
        'ByteOrder', 'little', 'Id', sprintf('b_mk%d', n), 'SessionId', 'sess_1', ...
        'Validate', false); %#ok<AGROW>
    bodies{end+1} = did2.build.sampledBody({tv}, did2.build.dimension(timeTerm, 2), ...
        'ByteOrder', 'little', 'Id', sprintf('b_t_mk%d', n), 'SessionId', 'sess_1', ...
        'Validate', false); %#ok<AGROW>
end
end

function s = describe(got, want)
s = sprintf('rebuilt %d row(s): %s; v1 %d row(s): %s', numel(got), ...
    strjoin(arrayfun(@(r) sprintf('%s/%g', r.name, r.time_channel), got, 'UniformOutput', false), ' '), ...
    numel(want), ...
    strjoin(arrayfun(@(r) sprintf('%s/%g', r.name, r.time_channel), want, 'UniformOutput', false), ' '));
end
