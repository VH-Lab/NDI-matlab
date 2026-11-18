classdef TestIngestedArchiveBodies < matlab.unittest.TestCase
%TESTINGESTEDARCHIVEBODIES ndi.migrate.internal.ingestedArchiveBodies: the NDI
%   second pass turns each v1 ingested mfdaq channel group (carried by pass 1
%   as an opaque_body of its segment files) into one sampled_body whose
%   channel list is covariates (Decided by Jess Haley, 2026-11-01 [ingested
%   archives are sampled bodies], [evenly spaced time is a covariate], [clock
%   only on the time reference], [uneven time is a keyed time value]; and
%   Jess Haley, 2026-11-12, [uneven time rewritten from the epoch start];
%   Jess Haley, 2026-11-17, [scale carries the reader's unit]). The segments and channel_list.bin are
%   written by NDI's own writers (ndi.compress, ndi.file.type.
%   mfdaq_epoch_channel), as ndi.daq.reader.mfdaq/ingest_epochfiles does.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needSchema(testCase)
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no V_eta schema set (did-schema #88, `entity`) where did2.schema.cache looks');
            testCase.assumeTrue(~isempty(which('ndi.compress.compress_ephys')), ...
                'NDI-compress is not installed');
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname();
            mkdir(fullfile(testCase.Dir, 'files'));
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)

        function testAGroupBecomesASampledBodyWithItsChannelList(testCase)
            [structs, v1] = testCase.archive(true, true);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_seen, 1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.group_bodies_described, 1);
            b = out{2};
            testCase.verifyEqual(b.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(b.base.id, 'body_ai', 'the body keeps its id');
            dims = b.data.dimensions;
            testCase.verifyEqual(numel(dims), 2);
            testCase.verifyEqual(char(dims(1).term.node), 'om:Time');
            testCase.verifyEqual(double(dims(1).n), 160);
            testCase.verifyEqual(double(dims(1).chunk), 100, 'chunk = the v1 segment length');
            testCase.verifyEqual(char(dims(2).term.node), 'NCIT:C44170');
            testCase.verifyEqual(double(dims(2).n), 3);
            covs = b.data.covariates;
            vars = arrayfun(@(c) char(c.variable.name), covs, 'UniformOutput', false);
            t = covs(strcmp(vars, 'time'));
            testCase.verifyEqual(double(t.origin.value), 0);
            testCase.verifyEqual(double(t.spacing.value), 1/10000, 'AbsTol', 1e-15);
            ch = covs(strcmp(vars, 'channel number'));
            testCase.verifyEqual(double(ch.count(:))', [1 2 3]);
            sc = covs(strcmp(vars, 'Unit Conversion Factor'));
            testCase.verifyEqual(double(sc.quantity.value(:))', [0.195 0.195 0.195]);
            % this archive names no v1 daqreader: the scale has no unit, and
            % the gap is listed ([scale carries the reader's unit])
            testCase.verifyFalse(isfield(sc, 'unit') && ~isempty(sc.unit));
            testCase.verifyEqual(rep.scale_with_unit, 0);
            testCase.verifyEqual(rep.scale_without_unit, 1);
            testCase.verifyEqual(numel(rep.scale_gaps), 1, 'one entry per converted archive');
            g = rep.scale_gaps{1};
            testCase.verifyEqual(numel(g), 1);
            testCase.verifyEqual(g.document_id, 'body_ai');
            testCase.verifyEqual(g.field, 'data.covariates(4).unit');
            testCase.verifyTrue(contains(g.reason, 'daqreader'), g.reason);
            testCase.verifyEqual(char(covs(4).variable.node), 'NCIT:C70774', ...
                'the field the gap names is the scale');
            off = covs(strcmp(vars, 'signal offset configuration'));
            testCase.verifyEqual(double(off.quantity.value(:))', [-2 -2 -2]);
            testCase.verifyFalse(isfield(off, 'unit') && ~isempty(off.unit), 'the offset has no unit');
            testCase.verifyEqual(char(b.data_body.conditions(1).term.node), 'EMPTY:0000370');
            % [time channel is a per-channel covariate]: always written,
            % unitless, NaN carried
            tc = covOf(b, 'EMPTY:0000374');
            testCase.assertNotEmpty(tc, 'no time-channel covariate');
            testCase.verifyTrue(all(isnan(double(tc.quantity.value(:)))), 'the v1 time_channel NaN');
            testCase.verifyFalse(isfield(tc, 'unit') && ~isempty(tc.unit), 'unitless');
            testCase.verifyEqual(rep.time_channel_covariates, 1);
            testCase.verifyEqual(numel(b.files.file_info), 2, 'the members are unchanged');
            testCase.verifyEqual(rep.members_seen, 4, 'the ai and ti members');
            testCase.verifyEqual(rep.members_schema_named, 4, 'pass 1 names them body_data_<k>');
            testCase.verifyEqual(rep.members_renamed, 0);
            % the evenly spaced time group is the covariate now; the
            % channel list keeps its time-channel row, so it stays
            testCase.verifyEqual(removed, {'body_ti'});
            testCase.verifyEqual(rep.channel_list_kept, 1);
            % the converted set validates against the real schema
            keep = ~cellfun(@(s) any(strcmp(s.base.id, removed)), out);
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAChannelListWhollyCarriedIsRemoved(testCase)
            [structs, v1] = testCase.archive(false, true);
            [~, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(removed, {'body_cl'});
            testCase.verifyEqual(rep.channel_list_removed, 1);
            testCase.verifyEqual(rep.channel_list_rebuilt_exactly, 1);
            % [channel name is an identifier]: standard names `ai<n>` are
            % not written
            testCase.verifyEqual(rep.channel_names_seen, 3, 'the denominator');
            testCase.verifyEqual(rep.channel_names_nonstandard, 0);
            testCase.verifyEqual(rep.channel_name_covariates, 0);
            testCase.verifyEqual(rep.channel_names_written, 0);
        end

        function testNonStandardChannelNamesAreAnIdentifierCovariate(testCase)
            % [channel name is an identifier] (Jess Haley, 2026-11-17): "a
            % channel's v1 name is a covariate along the channel dimension
            % of its channel group's body, variable NCIT:C25364
            % "Identifier", one text value per channel", written where a v1
            % name is not the standard `<prefix><number>`. The v1 list is
            % written by NDI's own writer (ndi.file.type.mfdaq_epoch_channel,
            % which keeps the reader's name and reads the number from it);
            % with the names carried it rebuilds exactly and is removed
            o = struct('names', {{'A-001', 'A-002', 'ai3'}});
            [structs, v1] = testCase.archive(false, true, 0, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            nm = covOf(out{2}, 'NCIT:C25364');
            testCase.assertNotEmpty(nm, 'no name covariate');
            testCase.verifyEqual(char(nm.variable.name), 'Identifier');
            testCase.verifyEqual(double(nm.along), 1, 'along the channel dimension');
            testCase.verifyEqual(cellstr(nm.text(:))', {'A-001', 'A-002', 'ai3'}, ...
                'one text value per channel, every channel''s v1 name');
            testCase.verifyEqual(char(out{2}.data.covariates(4).variable.node), 'NCIT:C70774', ...
                'the scale is still the 4th covariate (the gap''s field)');
            testCase.verifyEqual(rep.channel_names_seen, 3, 'the denominator');
            testCase.verifyEqual(rep.channel_names_nonstandard, 2);
            testCase.verifyEqual(rep.channel_name_covariates, 1);
            testCase.verifyEqual(rep.channel_names_written, 3);
            % the readers rebuild the v1 list exactly, so it is removed
            testCase.verifyEqual(removed, {'body_cl'}, rep.first_channel_list_kept_reason);
            testCase.verifyEqual(rep.channel_list_rebuilt_exactly, 1);
            want = ndi.file.type.mfdaq_epoch_channel( ...
                fullfile(testCase.Dir, 'files', 'u_cl')).channel_information;
            got = ndi.vintage.ingestedChannelList({jsondecode(jsonencode(out{2}))});
            testCase.verifyTrue(isequaln(got(:), want(:)), 'the readers'' rebuild is the v1 list');
            keep = ~cellfun(@(s) any(strcmp(s.base.id, removed)), out);
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testANonStandardEventNameKeepsTheList(testCase)
            % the name covariate lives on a channel group's body: an event
            % channel's non-standard name has no v2 home, so a list holding
            % one does not rebuild exactly and is kept (a check that cannot
            % fail proves nothing)
            o = struct('events', true, 'wired', true, 'eventName', 'Stim-1');
            [structs, v1] = testCase.archive(false, true, 0, o);
            [~, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.event_archives_unpacked, 1, rep.first_event_kept_reason);
            testCase.verifyFalse(ismember('body_cl', removed));
            testCase.verifyEqual(rep.channel_list_kept, 1);
            testCase.verifyTrue(contains(rep.first_channel_list_kept_reason, 'name'), ...
                rep.first_channel_list_kept_reason);
        end

        function testATimeChannelLinkIsCarriedAndTheListRebuilt(testCase)
            % [time channel is a per-channel covariate]: NaN and dangling
            % values carried exactly; the list is rebuilt with them
            o = struct('timeChannel', [1 2 NaN]);
            [structs, v1] = testCase.archive(false, true, 0, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            tc = covOf(out{2}, 'EMPTY:0000374');
            testCase.verifyTrue(isequaln(double(tc.quantity.value(:))', [1 2 NaN]));
            testCase.verifyEqual(removed, {'body_cl'}, rep.first_channel_list_kept_reason);
            res = did2.convert.v1_to_v2(out(2), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testRenamesMembersNamedByNdi(testCase)
            % [migrated body members renamed]: a member named
            % `ai_group1_seg.nbf_<n>` becomes body_data_<n-1>
            [structs, v1] = testCase.archive(false, true);
            structs{2}.files.file_info(1).name = 'ai_group1_seg.nbf_1';
            structs{2}.files.file_info(2).name = 'ai_group1_seg.nbf_2';
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual({out{2}.files.file_info.name}, {'body_data_0', 'body_data_1'});
            testCase.verifyEqual(memberUids(out{2}), {'u_ai_1', 'u_ai_2'}, 'the bytes are the same');
            testCase.verifyEqual(rep.members_renamed, 2);
        end

        function testDigitalScaleIsUnitlessAndNoGap(testCase)
            % [digital scale is unitless]: "the scale of a `di` or `do` group
            % has no unit and is not a gap"
            o = struct('reader', struct('class', 'ndi.daq.reader.mfdaq.intan', 'ndr', ''), ...
                'prefix', 'di', 'scale', 1);
            [structs, v1] = testCase.archive(false, true, 0, o);
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            b = out{2};
            testCase.verifyEqual(char(b.data_body.conditions(1).term.node), 'EMPTY:0000372');
            sc = scaleOf(b);
            testCase.verifyFalse(isfield(sc, 'unit') && ~isempty(sc.unit), 'no unit');
            testCase.verifyEqual(rep.scale_unitless_digital, 1);
            testCase.verifyEqual(rep.scale_without_unit, 0, 'not a gap');
            testCase.verifyEmpty(rep.scale_gaps{1}, 'no gap listed');
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testEventsFileIsUnpackedIntoObservations(testCase)
            % [event channels are time-valued observations], [event channel
            % observes its wired device], [unpacked event bodies are
            % uncompressed], [unpacked events file is removed]
            o = struct('events', true, 'wired', true);
            [structs, v1, ~, ev] = testCase.archive(false, true, 2, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.event_archives_seen, 1);
            testCase.verifyEqual(rep.event_archives_unpacked, 1, rep.first_event_kept_reason);
            testCase.verifyEqual(rep.event_channels_seen, 2);
            testCase.verifyEqual(rep.event_channels_unpacked, 2);
            testCase.verifyEqual(rep.event_bodies_removed, 1);
            testCase.verifyEqual(rep.event_bodies_left, 0);
            testCase.verifyTrue(ismember('body_ev', removed), 'the evmktx body is removed');
            testCase.verifyTrue(ismember('body_cl', removed), rep.first_channel_list_kept_reason);
            added = out(numel(structs) + 1:end);
            testCase.verifyEqual(numel(added), 6, 'event: observation + body; marker: time value + body, observation + body');
            cls = cellfun(@(d) d.document_class.class_name, added, 'UniformOutput', false);
            E = ndi.vintage.ingestedEventChannels(added, added);
            testCase.assertEqual({E.type}, {'event', 'marker'}, strjoin(cls, ', '));
            testCase.verifyEqual([E.number], [1 2]);
            obsE = added{strcmp(cellfun(@(d) d.base.id, added, 'UniformOutput', false), E(1).statement_id)};
            testCase.verifyEqual(edgeOf(obsE, 'entity_id'), {'stim_1'}, 'the wired device');
            testCase.verifyEqual(edgeOf(obsE, 'acquisition_system_id'), {'sys_1'});
            testCase.verifyEqual(edgeOf(obsE, 'time_reference_id'), {'tr_1'});
            testCase.verifyEqual(char(obsE.statement.variable.node), 'NCIT:C25499');
            obsM = added{strcmp(cellfun(@(d) d.base.id, added, 'UniformOutput', false), E(2).statement_id)};
            testCase.verifyEqual(char(obsM.statement.variable.node), 'NCIT:C25162');
            % the bodies: little-endian float64, seconds from the epoch start
            testCase.verifyEqual(floatsOf(testCase.Dir, E(1).times), ev.T{1}(:) - 2);
            testCase.verifyEqual(floatsOf(testCase.Dir, E(2).times), ev.T{2}(:) - 2);
            testCase.verifyEqual(floatsOf(testCase.Dir, E(2).values), ev.D{2}(:));
            testCase.verifyFalse(isfield(E(1).times.data_body, 'compression') && ...
                ~isempty(E(1).times.data_body.compression), 'no compression block');
            testCase.verifyEqual(char(E(1).times.data_body.format.node), 'EDAM:format_2333');
            % the channel list the readers rebuild is the v1 one
            groups = out(cellfun(@(d) strcmp(d.base.id, 'body_ai'), out));
            ci = ndi.vintage.ingestedChannelList(groups, E);
            testCase.verifyEqual({ci.name}, {'ai1', 'ai2', 'ai3', 'e1', 'mk2'});
            keep = ~cellfun(@(s) any(strcmp(s.base.id, removed)), out);
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testUnwiredEventsAreLeftPacked(testCase)
            % no `connected to` relation wires the channels: their entity is
            % not known, so the file stays as it is, counted
            o = struct('events', true, 'wired', false);
            [structs, v1] = testCase.archive(false, true, 0, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.event_archives_kept, 1);
            testCase.verifyEqual(rep.event_kept_unwired, 1, rep.first_event_kept_reason);
            testCase.verifyEqual(rep.event_bodies_left, 1);
            testCase.verifyFalse(ismember('body_ev', removed));
            testCase.verifyFalse(ismember('body_cl', removed), ...
                'the event rows have no other home, so channel_list.bin stays');
            testCase.verifyEqual(numel(out), numel(structs), 'nothing added');
        end

        function testUnevenTimeBecomesAKeyedTimeValue(testCase)
            % Decided by Jess Haley, 2026-11-03 [uneven time is a keyed time
            % value]: one standalone `time` value (data_body true) whose
            % sampled_body holds the timestamps; each channel group's time
            % covariate is `key` to it
            [structs, v1] = testCase.archive(true, false);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.time_not_evenly_spaced, 1);
            testCase.verifyEqual(rep.uneven_time_converted, 1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.group_bodies_described, 1);
            testCase.verifyEmpty(removed, 'the time body is kept, as the time value''s body');
            testCase.verifyEqual(rep.channel_list_kept, 1);
            testCase.verifyEqual(numel(out), numel(structs) + 1, 'one document added');
            testCase.verifyEqual(numel(rep.added_ids), 1);
            value = out{end};
            testCase.verifyEqual(value.base.id, rep.added_ids{1});
            testCase.verifyEqual(value.document_class.class_name, 'time');
            testCase.verifyTrue(logical(value.value.data_body));
            testCase.verifyTrue(ismember(value.base.id, rep.changed_groups{1}));
            % the time body: the time value's sampled_body, one time dimension
            tb = out{cellfun(@(x) strcmp(x.base.id, 'body_ti'), out)};
            testCase.verifyEqual(tb.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(edgeOf(tb, 'owner_id'), {value.base.id});
            testCase.verifyEqual(numel(tb.data.dimensions), 1);
            testCase.verifyEqual(char(tb.data.dimensions(1).term.node), 'om:Time');
            testCase.verifyEqual(double(tb.data.dimensions(1).n), 160);
            testCase.verifyEqual(double(tb.data.dimensions(1).chunk), 100);
            testCase.verifyEqual(numel(tb.files.file_info), 2, 'the members are unchanged');
            % the epoch starts at 0: pass 1's files, no file written
            testCase.verifyEqual(rep.uneven_time_rebased, 0);
            testCase.verifyEqual(rep.written_files, {{}});
            testCase.verifyEqual(memberUids(tb), {'u_ti_1', 'u_ti_2'});
            testCase.verifyEqual(numel(dir(fullfile(testCase.Dir, 'files'))) - 2, 5, ...
                'no file added to the store');
            % the channel group: its time is a key to the time value
            b = out{2};
            testCase.verifyEqual(b.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(edgeOf(b, 'key_id'), {value.base.id});
            covs = b.data.covariates;
            vars = arrayfun(@(c) char(c.variable.name), covs, 'UniformOutput', false);
            t = covs(strcmp(vars, 'time'));
            testCase.verifyEqual(double(t.key), 0);
            testCase.verifyEqual(double(t.along), 0);
            testCase.verifyTrue(~isfield(t, 'origin') || isempty(t.origin));
            testCase.verifyEqual(double(b.data.dimensions(1).n), 160);
            % the converted set validates against the real schema
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
            testCase.verifyEqual(numel(res.migrated), numel(out));
        end

        function testUnevenTimeNotFromZeroIsRewrittenFromTheStart(testCase)
            % [clock only on the time reference]: the body's times are
            % seconds from the epoch's start; v1's are on the epoch's clock.
            % [uneven time rewritten from the epoch start] (Jess Haley,
            % 2026-11-12): an epoch starting at t0 = 5 converts, its times
            % rewritten as t - t0 into new files; the epoch's start stays on
            % the recording's time references
            [structs, v1, tv1] = testCase.archive(true, false, 5);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.time_not_evenly_spaced, 1);
            testCase.verifyEqual(rep.uneven_time_converted, 1);
            testCase.verifyEqual(rep.uneven_time_rebased, 1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.unconvertible, 0);
            testCase.verifyEqual(rep.archives_seen, 1, 'the denominator is kept');
            testCase.verifyEqual(rep.documents_inspected, numel(structs));
            testCase.verifyEmpty(removed);
            testCase.verifyEqual(numel(out), numel(structs) + 1, 'one document added');
            value = out{end};
            testCase.verifyEqual(value.document_class.class_name, 'time');
            % the time body: owned by the value, NEW member files in the store
            tb = out{cellfun(@(x) strcmp(x.base.id, 'body_ti'), out)};
            testCase.verifyEqual(tb.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(edgeOf(tb, 'owner_id'), {value.base.id});
            testCase.verifyEqual(double(tb.data.dimensions(1).n), 160);
            testCase.verifyEqual(double(tb.data.dimensions(1).chunk), 100);
            uids = memberUids(tb);
            testCase.verifyEqual(numel(uids), 2);
            testCase.verifyFalse(any(ismember(uids, {'u_ti_1', 'u_ti_2'})), 'new files');
            testCase.verifyEqual(numel(rep.written_files), 1);
            testCase.verifyEqual(sort(rep.written_files{1}), ...
                sort(fullfile(testCase.Dir, 'files', uids)));
            testCase.verifyTrue(isfile(fullfile(testCase.Dir, 'files', 'u_ti_1')) && ...
                isfile(fullfile(testCase.Dir, 'files', 'u_ti_2')), 'the v1 files are kept');
            stored = [readTime(fullfile(testCase.Dir, 'files', uids{1})); ...
                readTime(fullfile(testCase.Dir, 'files', uids{2}))];
            testCase.verifyEqual(size(stored), [100 + 60, 1], 'one v1 segment per file');
            testCase.verifyEqual(stored, tv1 - 5, 'AbsTol', 1e-9, 'stored = v1 times - t0');
            testCase.verifyEqual(stored(1), 0, 'AbsTol', 1e-12, 'from the epoch''s start');
            % read on the epoch's clock as ndi.daq.reader.mfdaq does: the
            % stored seconds plus the start the time reference states (pass
            % 1 writes the v1 t0_t1(1) there, unchanged by this step)
            t0ref = v1{1}.daqreader_epochdata_ingested.epochtable.t0_t1(1);
            testCase.verifyEqual(t0ref + stored, tv1, 'AbsTol', 1e-9, 'the v1 clock times');
            % the channel group keys to the value, as when t0 is 0
            b = out{2};
            testCase.verifyEqual(edgeOf(b, 'key_id'), {value.base.id});
            covs = b.data.covariates;
            vars = arrayfun(@(c) char(c.variable.name), covs, 'UniformOutput', false);
            testCase.verifyEqual(double(covs(strcmp(vars, 'time')).key), 0);
            % the converted set validates against the real schema
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
            testCase.verifyEqual(numel(res.migrated), numel(out));
        end

        function testIntanAmplifierScaleIsInVoltsFromMicrovolts(testCase)
            % Decided by Jess Haley, 2026-11-17 [scale carries the reader's
            % unit]: "the per-channel scale covariate (NCIT:C70774) has the
            % canonical unit (volt for a voltage output) with the reader's
            % output unit as `source_unit` (e.g. microvolt for the Intan
            % amplifier)"; the offset has no unit
            o = struct('reader', struct('class', 'ndi.daq.reader.mfdaq.intan', 'ndr', ''));
            [structs, v1] = testCase.archive(true, true, 0, o);
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            sc = scaleOf(out{2});
            testCase.verifyEqual(double(sc.quantity.value(:))', 0.195e-6 * [1 1 1], 'AbsTol', 1e-18);
            testCase.verifyEqual(double(sc.quantity.source_value(:))', [0.195 0.195 0.195], ...
                'the v1 scale, verbatim');
            testCase.verifyEqual(char(sc.unit.node), 'om:volt');
            testCase.verifyEqual(char(sc.source_unit.node), 'om:microvolt');
            off = covOf(out{2}, 'AFO:AFQ_0000202');
            testCase.verifyFalse(isfield(off, 'unit') && ~isempty(off.unit), 'the offset has no unit');
            testCase.verifyEqual(rep.scale_with_unit, 1);
            testCase.verifyEqual(rep.scale_without_unit, 0);
            testCase.verifyEmpty(rep.scale_gaps{1});
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testNdrIntanReaderIsTheIntanUnit(testCase)
            % ndi.daq.reader.mfdaq.ndr with an NDR reader string of
            % ndr.reader.intan_rhd ("intan", "RHD", "intanRHD", any case)
            o = struct('reader', struct('class', 'ndi.daq.reader.mfdaq.ndr', 'ndr', 'rhd'));
            [structs, v1] = testCase.archive(true, true, 0, o);
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            sc = scaleOf(out{2});
            testCase.verifyEqual(char(sc.source_unit.node), 'om:microvolt');
            testCase.verifyEqual(rep.scale_with_unit, 1);
        end

        function testIntanAuxiliaryScaleIsInVolts(testCase)
            % Intan auxiliary inputs: "aux_input_data = 37.4e-6 *
            % aux_input_data; % units = volts"
            o = struct('reader', struct('class', 'ndi.daq.reader.mfdaq.intan', 'ndr', ''), ...
                'prefix', 'ax', 'scale', 3.74e-05);
            [structs, v1] = testCase.archive(true, true, 0, o);
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            b = out{2};
            testCase.verifyEqual(char(b.data_body.conditions(1).term.node), 'EMPTY:0000375');
            sc = scaleOf(b);
            testCase.verifyEqual(double(sc.quantity.value(:))', 3.74e-05 * [1 1 1], 'AbsTol', 1e-18);
            testCase.verifyEqual(double(sc.quantity.source_value(:))', 3.74e-05 * [1 1 1]);
            testCase.verifyEqual(char(sc.unit.node), 'om:volt');
            testCase.verifyEqual(char(sc.source_unit.node), 'om:volt');
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAReaderThatDefinesNoUnitIsAGap(testCase)
            % CED Spike2: the unit is per channel in the file, not the
            % reader's: no unit, and the gap names the reader
            o = struct('reader', struct('class', 'ndi.daq.reader.mfdaq.cedspike2', 'ndr', ''));
            [structs, v1] = testCase.archive(true, true, 0, o);
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            sc = scaleOf(out{2});
            testCase.verifyEqual(double(sc.quantity.value(:))', [0.195 0.195 0.195]);
            testCase.verifyFalse(isfield(sc, 'unit') && ~isempty(sc.unit));
            testCase.verifyFalse(isfield(sc.quantity, 'source_value') && ...
                ~isempty(sc.quantity.source_value));
            testCase.verifyEqual(rep.scale_with_unit, 0);
            testCase.verifyEqual(rep.scale_without_unit, 1);
            g = rep.scale_gaps{1};
            testCase.verifyEqual(g.field, 'data.covariates(4).unit');
            testCase.verifyTrue(contains(g.reason, 'ndi.daq.reader.mfdaq.cedspike2'), g.reason);
            % the gap is one did2.convert.migrationReport accepts
            did2.convert.migrationReport('begin');
            testCase.addTeardown(@() did2.convert.migrationReport('end'));
            did2.convert.migrationReport('gap', g.document_id, g.class, g.field, g.reason);
            listed = did2.convert.migrationReport('gaps', 'body_ai');
            testCase.verifyEqual({listed.field}, {'data.covariates(4).unit'});
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testBytesNotHereLeaveTheArchive(testCase)
            [structs, v1] = testCase.archive(true, true);
            delete(fullfile(testCase.Dir, 'files', '*'));
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.bytes_not_here, 1);
            testCase.verifyEmpty(removed);
            testCase.verifyEqual(out, structs, 'nothing changed');
        end
    end

    methods
        function [s, v1, t, ev] = archive(testCase, withTime, evenTime, t0, o)
            % an epoch of 160 samples at 10 kHz, 3 analog inputs in
            % segments of 100 (NDI's ephys compressor fits a predictor, so
            % a segment needs more samples than its order), and
            % (WITHTIME) the time channel t1, its v1 times T; the epoch
            % starts at T0 (0). O (optional): O.reader {class, ndr}, the v1
            % daqreader the archive depends on (none by default); O.prefix
            % 'ai' (default), 'ax' (auxiliary inputs) or 'di' (digital
            % inputs); O.scale (0.195); O.timeChannel, the three channels'
            % v1 time_channel (NaN); O.events, an events file with event
            % channel e1 and marker channel mk2 (EV: its T and D), O.wired a
            % `connected to` relation wiring them to the device stim_1;
            % O.names, the three channels' v1 names (`<prefix><n>`);
            % O.eventName, the event channel's v1 name ('e1')
            if nargin < 4; t0 = 0; end
            if nargin < 5; o = struct(); end
            if ~isfield(o, 'prefix'); o.prefix = 'ai'; end
            if ~isfield(o, 'scale'); o.scale = 0.195; end
            if ~isfield(o, 'reader'); o.reader = []; end
            if ~isfield(o, 'timeChannel'); o.timeChannel = NaN(1, 3); end
            if ~isfield(o, 'events'); o.events = false; end
            if ~isfield(o, 'wired'); o.wired = false; end
            if ~isfield(o, 'names')
                o.names = arrayfun(@(n) sprintf('%s%d', o.prefix, n), 1:3, 'UniformOutput', false);
            end
            if ~isfield(o, 'eventName'); o.eventName = 'e1'; end
            ev = [];
            types = struct('ai', 'analog_in', 'ax', 'auxiliary_in', 'di', 'digital_in');
            sr = 10000;
            ch = struct('name', o.names, 'type', types.(o.prefix), ...
                'time_channel', num2cell(o.timeChannel), 'sample_rate', sr, 'offset', -2, ...
                'scale', o.scale);
            if strcmp(o.prefix, 'di'); [ch.offset] = deal(0); end
            if o.events
                ch(end+1) = struct('name', o.eventName, 'type', 'event', 'time_channel', NaN, ...
                    'sample_rate', NaN, 'offset', 0, 'scale', 1);
                ch(end+1) = struct('name', 'mk2', 'type', 'marker', 'time_channel', NaN, ...
                    'sample_rate', NaN, 'offset', 0, 'scale', 1);
            end
            if withTime
                ch(end+1) = struct('name', 't1', 'type', 'time', 'time_channel', NaN, ...
                    'sample_rate', sr, 'offset', 0, 'scale', 1);
            end
            files = fullfile(testCase.Dir, 'files');
            ec = ndi.file.type.mfdaq_epoch_channel(ch);
            [ok, msg] = ec.writeToFile(fullfile(files, 'u_cl'));
            testCase.assertTrue(logical(ok), msg);
            data = int16(round(1000 * sin((1:160)' * [0.05 0.11 0.23])));
            segs = {data(1:100, :), data(101:160, :)};
            for k = 1:2
                stem = tempname();
                if strcmp(o.prefix, 'di')
                    ndi.compress.compress_digital(double(segs{k} > 0), stem);
                else
                    ndi.compress.compress_ephys(double(segs{k}), 16, stem, ...
                        'data_format', ndi.compress.datatypestring('int16'), ...
                        'data_is_unsigned', false);
                end
                movefile([stem '.nbf.tgz'], fullfile(files, sprintf('u_ai_%d', k)));
            end
            uids = {'u_cl', 'u_ai_1', 'u_ai_2'};
            t = [];
            obs = owner();
            s = {obs, ...
                body('body_ai', [o.prefix '_group1_seg.nbf_#'], {'u_ai_1', 'u_ai_2'}), ...
                body('body_cl', 'channel_list.bin', {'u_cl'})};
            if o.events
                % as ndi.daq.reader.mfdaq/ingest_epochfiles writes the file:
                % times on the epoch's clock (from T0)
                ev = struct('T', {{t0 + [0.001; 0.0052; 0.0101], t0 + [0.002; 0.009]}}, ...
                    'D', {{ones(3, 1), [7; 2]}});
                stem = tempname();
                ndi.compress.compress_eventmarktext({'event', 'marker'}, [1 2], ev.T, ev.D, stem);
                movefile([stem '.nbf.tgz'], fullfile(files, 'u_ev'));
                s{end+1} = body('body_ev', 'evmktx_group1_seg.nbf_#', {'u_ev'});
                uids{end+1} = 'u_ev';
                if o.wired
                    s{end+1} = wiring();
                end
            end
            if withTime
                t = t0 + (0:159)' / sr;
                if ~evenTime; t(50) = t(50) + 0.3 / sr; end
                tsegs = {t(1:100), t(101:160)};
                for k = 1:2
                    stem = tempname();
                    ndi.compress.compress_time(tsegs{k}, stem);
                    movefile([stem '.nbf.tgz'], fullfile(files, sprintf('u_ti_%d', k)));
                end
                s{end+1} = body('body_ti', 'ti_group1_seg.nbf_#', {'u_ti_1', 'u_ti_2'});
                uids = [uids, {'u_ti_1', 'u_ti_2'}];
            end
            locs = cellfun(@(u) struct('delete_original', 0, 'uid', u, ...
                'location', '/gone', 'parameters', '', 'location_type', 'file', ...
                'ingest', 1), uids);
            fi = struct('name', uids, 'locations', num2cell(locs));
            v1 = {struct('base', struct('id', 'arch_1'), ...
                'document_class', struct('class_name', 'daqreader_mfdaq_epochdata_ingested'), ...
                'daqreader_mfdaq_epochdata_ingested', struct('parameters', ...
                    struct('sample_analog_segment', 100, 'sample_digital_segment', 100)), ...
                'daqreader_epochdata_ingested', struct('epochtable', ...
                    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [t0; t0 + 159/sr])), ...
                'files', struct('file_list', {{'channel_list.bin'}}, 'file_info', fi))};
            if ~isempty(o.reader)
                % the v1 daqreader document the archive's daqreader_id names
                % (ndi.daq.reader/newdocument; daqreader_ndr adds the NDR
                % reader string)
                rd = struct('base', struct('id', 'reader_1'), ...
                    'document_class', struct('class_name', 'daqreader'), ...
                    'daqreader', struct('ndi_daqreader_class', o.reader.class));
                if ~isempty(o.reader.ndr)
                    rd.document_class.class_name = 'daqreader_ndr';
                    rd.daqreader_ndr = struct('ndr_reader_string', o.reader.ndr, ...
                        'ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr');
                end
                v1{1}.depends_on = struct('name', 'daqreader_id', 'value', 'reader_1');
                % as JSON text, as did2.convert.readers hand the bodies over
                v1{end+1} = jsonencode(rd);
            end
        end
    end
end

function ids = edgeOf(b, name)
ids = {};
deps = b.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    if strcmp(char(deps{k}.name), name)
        v = '';
        if isfield(deps{k}, 'document_id'); v = char(deps{k}.document_id); end
        if isempty(v) && isfield(deps{k}, 'value'); v = char(deps{k}.value); end
        ids{end+1} = v; %#ok<AGROW>
    end
end
end

function c = covOf(b, node)
covs = b.data.covariates;
if isstruct(covs); covs = num2cell(covs); end
c = [];
for k = 1:numel(covs)
    v = covs{k}.variable;
    if isfield(v, 'node') && strcmp(char(v.node), node); c = covs{k}; return; end
end
end

function c = scaleOf(b)
c = covOf(b, 'NCIT:C70774');
end

function uids = memberUids(b)
fi = b.files.file_info;
if isstruct(fi); fi = num2cell(fi); end
uids = cellfun(@(f) char(f.locations(1).uid), fi, 'UniformOutput', false);
end

function t = readTime(path)
% NDI's own expander, as the reader reads a time segment
stem = tempname();
copyfile(path, [stem '.nbf.tgz']);
c = onCleanup(@() delete([stem '.nbf.tgz']));
t = ndi.compress.expand_time(stem);
end

function obs = owner()
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
obs = did2.build.statement('observation', 'el_1', ...
    struct('node', 'GO:0001508', 'name', 'action potential'), [], ...
    'DataBody', true, 'TimeReferenceIds', {'tr_1'}, 'Id', 'obs_1', ...
    'AcquisitionSystemId', 'sys_1', ...
    'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'time');
end

function rel = wiring()
% the stimulator stim_1 `connected to` the system sys_1 on e1 and mk2, as
% did2.convert.resolveEpochProbemap mkWiring writes it
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
rel = did2.build.directedRelation('stim_1', 'sys_1', ...
    struct('node', 'RO:0002170', 'name', 'connected to'), ...
    'TimeReferenceIds', {'tr_1'}, ...
    'Fields', struct('conditions', {did2.build.list( ...
        did2.build.condition(struct('node', 'EMPTY:0000376', 'name', 'event channel'), 'Matrix', 1), ...
        did2.build.condition(struct('node', 'EMPTY:0000377', 'name', 'marker channel'), 'Matrix', 2))}), ...
    'Id', 'rel_1', 'SessionId', 'sess_1', 'Validate', false);
end

function x = floatsOf(dir, b)
% an unpacked body's member body_data_0, read as little-endian float64
fi = b.files.file_info;
fid = fopen(fullfile(dir, 'files', char(fi(1).locations(1).uid)), 'r', 'ieee-le');
x = fread(fid, Inf, 'float64');
fclose(fid);
end

function b = body(id, filename, uids)
% as did2.convert.resolveEpochProbemap's archiveBodies writes it
b = did2.build.opaqueBody({'obs_1'}, struct('node', 'EDAM:format_2333', ...
    'name', 'Binary format'), 'Chunks', numel(uids), ...
    'Fields', struct('filename', filename), ...
    'Notes', sprintf(['The ingested recording of epoch e1: v1 attached ' ...
        'file series %s, carried as attached (%d member(s)).'], filename, numel(uids)), ...
    'Id', id, 'SessionId', 'sess_1', 'Validate', false);
fi = struct('name', {}, 'locations', {});
for m = 1:numel(uids)
    fi(end+1) = struct('name', sprintf('body_data_%d', m - 1), 'locations', ...
        struct('delete_original', 0, 'uid', uids{m}, 'location', '/not/here', ...
        'parameters', '', 'location_type', 'file', 'ingest', 1)); %#ok<AGROW>
end
b.files.file_info = fi;
end
