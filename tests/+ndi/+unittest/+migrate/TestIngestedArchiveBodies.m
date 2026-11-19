classdef TestIngestedArchiveBodies < matlab.unittest.TestCase
%TESTINGESTEDARCHIVEBODIES ndi.migrate.internal.ingestedArchiveBodies: the NDI
%   second pass turns each v1 ingested mfdaq channel group (carried by pass 1
%   as an opaque_body of its segment files) into one sampled_body whose
%   channel list is covariates (Decided by Jess Haley, 2026-11-01 [ingested
%   archives are sampled bodies], [evenly spaced time is a covariate], [clock
%   only on the time reference], [uneven time is a keyed time value]; and
%   Jess Haley, 2026-11-12, [uneven time rewritten from the epoch start];
%   Jess Haley, 2026-11-17, [scale carries the reader's unit]; Jess Haley,
%   2026-11-19, [uneven time groups and mismatches], [time channel row is
%   notation], [text channel entries are a JSON array], [time group with
%   several time channels split]). The segments and channel_list.bin are
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
            testCase.verifyEqual(double(t.origin), 0);
            testCase.verifyEqual(double(t.spacing), 1/10000, 'AbsTol', 1e-15);
            ch = covs(strcmp(vars, 'channel number'));
            testCase.verifyEqual(double(ch.count(:))', [1 2 3]);
            sc = covs(strcmp(vars, 'Unit Conversion Factor'));
            testCase.verifyEqual(double(sc.numeric(:))', [0.195 0.195 0.195]);
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
            testCase.verifyEqual(double(off.numeric(:))', [-2 -2 -2]);
            testCase.verifyFalse(isfield(off, 'unit') && ~isempty(off.unit), 'the offset has no unit');
            testCase.verifyEqual(char(b.data_body.conditions(1).term.node), 'EMPTY:0000370');
            % [time channel is a per-channel covariate]: always written,
            % unitless, NaN carried
            tc = covOf(b, 'EMPTY:0000374');
            testCase.assertNotEmpty(tc, 'no time-channel covariate');
            testCase.verifyTrue(all(isnan(double(tc.numeric(:)))), 'the v1 time_channel NaN');
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

        function testATimeChannelLinkIsCarriedAndTheListKept(testCase)
            % [time channel is a per-channel covariate]: NaN and dangling
            % values carried exactly; the list is rebuilt with them
            % ([time channel row is notation], Jess Haley, 2026-11-19): the
            % groups name t1 and t2 and the v1 list holds neither, so the
            % rebuild (which writes their rows) does not match and the list
            % is kept
            o = struct('timeChannel', [1 2 NaN]);
            [structs, v1] = testCase.archive(false, true, 0, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            tc = covOf(out{2}, 'EMPTY:0000374');
            testCase.verifyTrue(isequaln(double(tc.numeric(:))', [1 2 NaN]));
            testCase.verifyEmpty(removed, 'the list is kept');
            testCase.verifyEqual(rep.channel_list_kept, 1);
            testCase.verifySubstring(rep.first_channel_list_kept_reason, 't1, t2');
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
            testCase.verifyEqual(double(sc.numeric(:))', 0.195e-6 * [1 1 1], 'AbsTol', 1e-18);
            testCase.verifyEqual(double(sc.source_numeric(:))', [0.195 0.195 0.195], ...
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
            testCase.verifyEqual(double(sc.numeric(:))', 3.74e-05 * [1 1 1], 'AbsTol', 1e-18);
            testCase.verifyEqual(double(sc.source_numeric(:))', 3.74e-05 * [1 1 1]);
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
            testCase.verifyEqual(double(sc.numeric(:))', [0.195 0.195 0.195]);
            testCase.verifyFalse(isfield(sc, 'unit') && ~isempty(sc.unit));
            testCase.verifyFalse(isfield(sc, 'source_numeric') && ...
                ~isempty(sc.source_numeric));
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

        function testSeveralUnevenTimeGroupsAreEachAKeyedTimeValue(testCase)
            % Decided by Jess Haley, 2026-11-19 [uneven time groups and
            % mismatches] (1): "an ingested archive with several uneven time
            % groups is converted, one `time` value per time group, each
            % channel group keyed to the time group it uses, as the channel
            % list pairs them"
            [structs, v1] = testCase.twoTimeGroups(struct());
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_seen, 1, 'the denominator');
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.time_not_evenly_spaced, 1);
            testCase.verifyEqual(rep.uneven_time_converted, 1);
            testCase.verifyEqual(rep.uneven_time_values, 2, 'one time value per time group');
            testCase.verifyEqual(rep.uneven_time_mismatch_kept, 0);
            testCase.verifyEqual(rep.uneven_time_unpaired_kept, 0);
            testCase.verifyEqual(rep.unconvertible, 0);
            testCase.verifyEqual(numel(out), numel(structs) + 2, 'two time values added');
            testCase.verifyEmpty(removed, 'no time body removed, and the list stays');
            ids = cellfun(@(x) x.base.id, out, 'UniformOutput', false);
            tb1 = out{strcmp(ids, 'body_ti1')};
            tb2 = out{strcmp(ids, 'body_ti2')};
            testCase.verifyEqual(tb1.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(tb2.document_class.class_name, 'sampled_body');
            v1Id = edgeOf(tb1, 'owner_id');
            v2Id = edgeOf(tb2, 'owner_id');
            testCase.verifyNotEqual(v1Id, v2Id, 'each time group its own value');
            testCase.verifyEqual(double(tb1.data.dimensions(1).n), 160);
            testCase.verifyEqual(double(tb2.data.dimensions(1).n), 80);
            % each channel group keyed to the time group its time_channel names
            ai = out{strcmp(ids, 'body_ai')};
            ax = out{strcmp(ids, 'body_ax')};
            testCase.verifyEqual(edgeOf(ai, 'key_id'), v1Id, 'ai1-3 name t1');
            testCase.verifyEqual(edgeOf(ax, 'key_id'), v2Id, 'ax1-2 name t100001');
            values = out(numel(structs) + 1:end);
            testCase.verifyEqual(sort(cellfun(@(x) x.base.id, values, 'UniformOutput', false)), ...
                sort([v1Id, v2Id]));
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.document_class.class_name, 'time'), values)));
            % uneven groups' rates have no v2 home, so the list stays
            testCase.verifyEqual(rep.channel_list_kept, 1);
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
            testCase.verifyEqual(numel(res.migrated), numel(out));
        end

        function testAnEvenTimeGroupBesideAnUnevenOneKeepsItsCovariate(testCase)
            % a channel group whose time channel is evenly spaced keeps the
            % time covariate; its time body is removed; the other is keyed
            [structs, v1] = testCase.twoTimeGroups(struct('axEven', true));
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.uneven_time_values, 1);
            testCase.verifyTrue(ismember('body_ti2', removed), 'the evenly spaced time body');
            testCase.verifyFalse(ismember('body_ti1', removed));
            ids = cellfun(@(x) x.base.id, out, 'UniformOutput', false);
            ax = out{strcmp(ids, 'body_ax')};
            testCase.verifyEmpty(edgeOf(ax, 'key_id'));
            t = covOf(ax, 'om:Time');
            testCase.verifyEqual(double(t.spacing), 1/5000, 'AbsTol', 1e-15);
            ai = out{strcmp(ids, 'body_ai')};
            testCase.verifyEqual(edgeOf(ai, 'key_id'), {out{end}.base.id});
            keep = ~cellfun(@(x) any(strcmp(x.base.id, removed)), out);
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAnUnevenTimeChannelOfAnotherLengthKeepsTheArchive(testCase)
            % [uneven time groups and mismatches] (2): "a time channel whose
            % sample count differs from the data it times is malformed: the
            % archive is kept as v1, counted (e.g. `uneven_time_mismatch_kept`)
            % and reported"
            [structs, v1] = testCase.twoTimeGroups(struct('axTimeN', 79));
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_seen, 1, 'the denominator');
            testCase.verifyEqual(rep.archives_converted, 0);
            testCase.verifyEqual(rep.uneven_time_mismatch_kept, 1);
            testCase.verifyEqual(rep.uneven_time_unpaired_kept, 0);
            testCase.verifyEqual(rep.unconvertible, 1);
            testCase.verifyEmpty(removed);
            testCase.verifyEqual(out, structs, 'kept as pass 1 wrote it');
            testCase.assertNumElements(rep.uneven_time_kept, 1);
            k = rep.uneven_time_kept{1};
            testCase.verifyEqual(k.kind, 'mismatch');
            testCase.verifyEqual(k.archive_id, 'arch_1');
            testCase.verifyEqual(k.group_body_id, 'body_ax');
            testCase.verifyEqual(k.time_body_id, 'body_ti2');
            testCase.verifySubstring(k.reason, 'malformed');
            testCase.verifyEqual(rep.first_uneven_time_kept_reason, k.reason);
        end

        function testAChannelGroupNoTimeChannelPairsWithKeepsTheArchive(testCase)
            % two time channels in the archive, and the auxiliary group names
            % neither (NaN): the channel list does not pair it, so the archive
            % is left, counted
            [structs, v1] = testCase.twoTimeGroups(struct('axTimeChannel', NaN));
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 0);
            testCase.verifyEqual(rep.uneven_time_unpaired_kept, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.uneven_time_mismatch_kept, 0);
            testCase.assertNumElements(rep.uneven_time_kept, 1);
            testCase.verifyEqual(rep.uneven_time_kept{1}.kind, 'unpaired');
            testCase.verifyEmpty(removed);
            testCase.verifyEqual(out, structs);
        end

        function testTheTimeRowIsRebuiltAndTheListRemoved(testCase)
            % Decided by Jess Haley, 2026-11-19 [time channel row is
            % notation]: "a time channel's own `channel_list.bin` row is
            % rebuilt from its time group: number the time group's, sample
            % rate the group's, offset 0, scale 1, name the standard prefix
            % and number; the file is removed only when the rebuild matches
            % exactly". The v1 list as NDI's writer writes it for the Intan
            % reader: t1, time_channel 1 (intan.m), offset 0 and scale 1
            o = struct('timeChannel', [1 1 1], 'timeRowTimeChannel', 1);
            [structs, v1] = testCase.archive(true, true, 0, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(sort(removed), sort({'body_ti', 'body_cl'}), ...
                rep.first_channel_list_kept_reason);
            testCase.verifyEqual(rep.channel_list_rebuilt_exactly, 1);
            testCase.verifyEqual(rep.time_rows_seen, 1, 'the denominator');
            testCase.verifyEqual(rep.time_rows_rebuilt, 1);
            testCase.verifyEqual(rep.channel_list_kept_time_row, 0);
            want = ndi.file.type.mfdaq_epoch_channel( ...
                fullfile(testCase.Dir, 'files', 'u_cl')).channel_information;
            got = ndi.vintage.ingestedChannelList({jsondecode(jsonencode(out{2}))});
            testCase.verifyTrue(isequaln(got(:), want(:)), 'the readers'' rebuild is the v1 list');
            testCase.verifyEqual({got.name}, {'ai1', 'ai2', 'ai3', 't1'});
            keep = ~cellfun(@(x) any(strcmp(x.base.id, removed)), out);
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testANonDefaultTimeRowKeepsTheList(testCase)
            % a v1 time row whose offset is not 0 is not notation: the list
            % is kept whole as v1 and counted (a check that cannot fail
            % proves nothing); the evenly spaced time body still goes
            o = struct('timeChannel', [1 1 1], 'timeRowTimeChannel', 1, 'timeRowOffset', 0.5);
            [~, rep, removed] = testCase.convertArchive(true, true, 0, o);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(removed, {'body_ti'});
            testCase.verifyEqual(rep.channel_list_kept, 1);
            testCase.verifyEqual(rep.time_rows_seen, 1);
            testCase.verifyEqual(rep.time_rows_rebuilt, 0);
            testCase.verifyEqual(rep.channel_list_kept_time_row, 1);
            testCase.verifySubstring(rep.first_channel_list_kept_reason, 'offset');
            % and a time channel a group names that the list does not hold
            % (Intan's auxiliary inputs name t2, VH-Lab/NDI-matlab#1249)
            o = struct('timeChannel', [1 2 1], 'timeRowTimeChannel', 1);
            [~, rep, removed] = testCase.convertArchive(true, true, 0, o);
            testCase.verifyEqual(removed, {'body_ti'});
            testCase.verifyEqual(rep.time_rows_rebuilt, 0, 'ai2 names t2: no group is all t1');
            testCase.verifyEqual(rep.channel_list_kept_time_row, 1);
            testCase.verifySubstring(rep.first_channel_list_kept_reason, 't2');
        end

        function testTextChannelsAreUnpackedAsAJsonArray(testCase)
            % Decided by Jess Haley, 2026-11-19 [text channel entries are a
            % JSON array]: "an unpacked text channel's times are an
            % uncompressed array of 64-bit floats, as for events; its entries
            % are one uncompressed UTF-8 JSON array of strings in the same
            % order, format EDAM format_3464 "JSON""; variable NCIT:C44272
            % "Annotation" ([event channel variable terms]); its entity the
            % wired device ([event channel observes its wired device])
            o = struct('events', true, 'wired', true, 'text', true);
            [structs, v1, ~, ev] = testCase.archive(false, true, 2, o);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.event_archives_unpacked, 1, rep.first_event_kept_reason);
            testCase.verifyEqual(rep.event_channels_seen, 3, 'the denominator');
            testCase.verifyEqual(rep.event_channels_unpacked, 3);
            testCase.verifyEqual(rep.text_channels_seen, 1);
            testCase.verifyEqual(rep.text_channels_unpacked, 1);
            testCase.verifyEqual(rep.event_kept_text_channel, 0);
            testCase.verifyTrue(ismember('body_ev', removed), 'the evmktx body is removed');
            testCase.verifyTrue(ismember('body_cl', removed), rep.first_channel_list_kept_reason);
            added = out(numel(structs) + 1:end);
            testCase.verifyEqual(numel(added), 10, ...
                'event 2, marker 4, text 4 (time value + body, observation + body)');
            E = ndi.vintage.ingestedEventChannels(added, added);
            testCase.assertEqual({E.type}, {'event', 'marker', 'text'});
            testCase.verifyEqual([E.number], [1 2 3]);
            ids = cellfun(@(d) d.base.id, added, 'UniformOutput', false);
            obsT = added{strcmp(ids, E(3).statement_id)};
            testCase.verifyEqual(char(obsT.statement.variable.node), 'NCIT:C44272');
            testCase.verifyEqual(edgeOf(obsT, 'entity_id'), {'stim_1'}, 'the wired device');
            testCase.verifyEqual(edgeOf(obsT, 'acquisition_system_id'), {'sys_1'});
            % the times: little-endian float64, seconds from the epoch start
            testCase.verifyEqual(floatsOf(testCase.Dir, E(3).times), ev.T{3}(:) - 2);
            testCase.verifyEqual(char(E(3).times.data_body.format.node), 'EDAM:format_2333');
            % the entries: one UTF-8 JSON array of strings, in event order
            vb = E(3).values;
            testCase.verifyEqual(char(vb.data_body.format.node), 'EDAM:format_3464');
            testCase.verifyFalse(isfield(vb.data_body, 'compression') && ...
                ~isempty(vb.data_body.compression), 'no compression block');
            testCase.verifyEqual(edgeOf(vb, 'key_id'), edgeOf(E(3).times, 'owner_id'), ...
                'keyed to the time value of its times');
            bytes = bytesOf(testCase.Dir, vb);
            want = unicode2native(jsonencode(ev.D{3}), 'UTF-8');
            testCase.verifyEqual(bytes, uint8(want(:)'), 'the JSON array, UTF-8');
            testCase.verifyEqual(jsondecode(native2unicode(bytes, 'UTF-8')), ...
                {'start'; 'stop now'; ''});
            % read back as NDI's expander gives the channel
            entries = ndi.vintage.ingestedTextEntries('decode', bytes);
            [T, D] = ndi.vintage.ingestedEventData('text', floatsOf(testCase.Dir, E(3).times), entries);
            testCase.verifyEqual(T + 2, ev.T{3}(:));
            testCase.verifyEqual(D, ev.D{3}, 'the entries exactly as expand_eventmarktext gives them');
            % the channel list the readers rebuild is the v1 one
            groups = out(cellfun(@(d) strcmp(d.base.id, 'body_ai'), out));
            ci = ndi.vintage.ingestedChannelList(groups, E);
            testCase.verifyEqual({ci.name}, {'ai1', 'ai2', 'ai3', 'e1', 'mk2', 'tx3'});
            keep = ~cellfun(@(s) any(strcmp(s.base.id, removed)), out);
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAnEventsFileNdiCannotReadStaysPacked(testCase)
            % NDI-compress writes a non-ASCII text entry as UTF-8 bytes but
            % reads it back byte by byte, so its own expander cannot read
            % the file: the events file is left as v1, counted, never an
            % error
            o = struct('events', true, 'wired', true, 'text', true, ...
                'entries', {{'start', ['stop ' char(252)], ''}});
            [structs, v1, ~, ev] = testCase.archive(false, true, 0, o);
            testCase.assumeTrue(isfield(ev, 'unreadable'), ...
                'NDI-compress reads this file back: nothing to test');
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.event_archives_kept, 1);
            testCase.verifyEqual(rep.event_kept_other, 1, rep.first_event_kept_reason);
            testCase.verifySubstring(rep.first_event_kept_reason, 'expander');
            testCase.verifyFalse(ismember('body_ev', removed));
            testCase.verifyFalse(ismember('body_cl', removed));
            testCase.verifyEqual(numel(out), numel(structs));
        end

        function testAnUnwiredTextChannelLeavesTheFilePacked(testCase)
            % a text channel follows the event path: no `connected to`
            % relation wires it, so its entity is not known and the file stays
            o = struct('events', true, 'wired', true, 'text', true, 'wireText', false);
            [~, rep, removed] = testCase.convertArchive(false, true, 0, o);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.event_archives_kept, 1);
            testCase.verifyEqual(rep.event_kept_unwired, 1, rep.first_event_kept_reason);
            testCase.verifySubstring(rep.first_event_kept_reason, 'text channel 3');
            testCase.verifyEqual(rep.text_channels_seen, 1);
            testCase.verifyEqual(rep.text_channels_unpacked, 0);
            testCase.verifyFalse(ismember('body_ev', removed));
            testCase.verifyFalse(ismember('body_cl', removed));
        end

        function testATimeGroupOfSeveralTimeChannelsIsSplit(testCase)
            % Decided by Jess Haley, 2026-11-19 [time group with several time
            % channels split]: "when an ingested archive's one uneven time
            % group file holds several time channels, each time channel
            % becomes its own keyed `time` value, and each channel group keys
            % to the time value of the time channel its rows' v1
            % `time_channel` names". One v1 file ti_group1 holds t1 and t2
            % (NDI's ingest writes both time channels of group 1 into it,
            % ndi.compress.compress_time of the two columns); the epoch
            % starts at 5, so the stored times are t - 5
            [structs, v1, tv1] = testCase.splitTimeGroup(struct('t0', 5));
            nFiles = numel(dir(fullfile(testCase.Dir, 'files'))) - 2;
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_seen, 1, 'the denominator');
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.unconvertible, 0);
            testCase.verifyEqual(rep.time_not_evenly_spaced, 1);
            testCase.verifyEqual(rep.uneven_time_converted, 1);
            testCase.verifyEqual(rep.uneven_time_groups_split, 1);
            testCase.verifyEqual(rep.uneven_time_channels_split, 2);
            testCase.verifyEqual(rep.uneven_time_values, 2, 'one time value per time channel');
            testCase.verifyEqual(rep.uneven_time_split_ambiguous_kept, 0);
            testCase.verifyEqual(rep.uneven_time_rebased, 1);
            testCase.verifyEqual(rep.group_bodies_described, 2, 'the ai and ax groups');
            testCase.verifyEmpty(removed, 'no body removed, and the list stays');
            testCase.verifyEqual(rep.channel_list_kept, 1, ...
                'uneven groups'' rates have no v2 home, so the list stays');
            testCase.verifyEqual(numel(out), numel(structs) + 3, ...
                'two time values and the second channel''s body added');
            testCase.verifyEqual(numel(rep.added_ids), 3);
            ids = cellfun(@(x) x.base.id, out, 'UniformOutput', false);
            % the time bodies: one per time channel, each naming it
            isTi = cellfun(@(x) strcmp(x.document_class.class_name, 'sampled_body') && ...
                strcmp(char(x.data_body.filename), 'ti_group1_seg.nbf_#'), out);
            testCase.assertEqual(nnz(isTi), 2);
            tbs = out(isTi);
            tcs = cellfun(@timeChannelOf, tbs);
            testCase.verifyEqual(sort(tcs), [1 2]);
            tb1 = tbs{tcs == 1};
            tb2 = tbs{tcs == 2};
            testCase.verifyEqual(tb1.base.id, 'body_ti', 'the first channel keeps the id');
            testCase.verifyNotEqual(tb2.base.id, 'body_ti');
            testCase.verifyTrue(ismember(tb2.base.id, rep.added_ids));
            vA = edgeOf(tb1, 'owner_id');
            vB = edgeOf(tb2, 'owner_id');
            testCase.verifyNotEqual(vA, vB, 'each time channel its own value');
            for v = [vA, vB]
                val = out{strcmp(ids, v{1})};
                testCase.verifyEqual(val.document_class.class_name, 'time');
                testCase.verifyTrue(logical(val.value.data_body));
            end
            for tb = {tb1, tb2}
                testCase.verifyEqual(numel(tb{1}.data.dimensions), 1);
                testCase.verifyEqual(double(tb{1}.data.dimensions(1).n), 160);
                testCase.verifyEqual(double(tb{1}.data.dimensions(1).chunk), 100);
            end
            % new files, one per v1 segment, each one column, t - t0
            testCase.verifyEqual(numel(rep.written_files{1}), 4);
            testCase.verifyEqual(numel(dir(fullfile(testCase.Dir, 'files'))) - 2, nFiles + 4);
            testCase.verifyTrue(isfile(fullfile(testCase.Dir, 'files', 'u_ti_1')), 'v1 files kept');
            u1 = memberUids(tb1); u2 = memberUids(tb2);
            testCase.verifyFalse(any(ismember([u1, u2], {'u_ti_1', 'u_ti_2'})), 'new files');
            s1 = [readTime(fullfile(testCase.Dir, 'files', u1{1})); ...
                readTime(fullfile(testCase.Dir, 'files', u1{2}))];
            s2 = [readTime(fullfile(testCase.Dir, 'files', u2{1})); ...
                readTime(fullfile(testCase.Dir, 'files', u2{2}))];
            testCase.verifyEqual(size(s1), [160 1]);
            testCase.verifyEqual(s1, tv1(:, 1) - 5, 'AbsTol', 1e-9, 't1 = column 1 - t0');
            testCase.verifyEqual(s2, tv1(:, 2) - 5, 'AbsTol', 1e-9, 't2 = column 2 - t0');
            % each channel group keyed to the time value its rows name
            ai = out{strcmp(ids, 'body_ai')};
            ax = out{strcmp(ids, 'body_ax')};
            testCase.verifyEqual(edgeOf(ai, 'key_id'), vA, 'ai1-3 name t1');
            testCase.verifyEqual(edgeOf(ax, 'key_id'), vB, 'ax1-2 name t2');
            % the time rows the readers rebuild: t1 and t2, both group 1
            rebuilt = ndi.vintage.ingestedChannelList({jsondecode(jsonencode(ai)), ...
                jsondecode(jsonencode(ax))});
            tr = rebuilt(strcmp({rebuilt.type}, 'time'));
            testCase.verifyEqual({tr.name}, {'t1', 't2'});
            testCase.verifyEqual([tr.group], [1 1]);
            testCase.verifyEqual([tr.time_channel], [1 2]);
            % the converted set validates against the real schema
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
            testCase.verifyEqual(numel(res.migrated), numel(out));

            % THE READERS. The split bodies are one series (in either order),
            % and segment 2 of the v1 file is rebuilt from them, one column
            % per time channel, seconds from the epoch's start (the reader
            % adds the start, ndi.daq.reader.mfdaq)
            wrap = @(b) struct('document_properties', jsondecode(jsonencode(b)));
            M = ndi.vintage.ingestedArchiveSeries({wrap(tb2), wrap(ai), wrap(tb1), wrap(ax)});
            e = M('ti_group1_seg.nbf_#');
            testCase.verifyEqual(e.kind, 'split_time');
            testCase.verifyEqual(e.numbers, [1 2]);
            testCase.verifyEqual(e.chunk, 100);
            testCase.verifyEqual(e.n, 160);
            A = struct('epoch_id', 'e1', 'bodies', M);
            S = fakeBinarySession(testCase.Dir);
            seg2 = ndi.vintage.ingestedSplitTime(S, A, 'ti_group1_seg.nbf_2');
            testCase.verifyEqual(seg2, tv1(101:160, :) - 5, 'AbsTol', 1e-9);
            seg1 = ndi.vintage.ingestedSplitTime(S, A, 'ti_group1_seg.nbf_1');
            testCase.verifyEqual(5 + seg1, tv1(1:100, :), 'AbsTol', 1e-9, 'the v1 clock times');
            testCase.verifyError(@() ndi.vintage.ingestedArchiveFile(S, A, ...
                'ti_group1_seg.nbf_1', '.nbf.tgz'), 'NDI:daq:reader:ingestedSplitTime');
            testCase.verifyError(@() ndi.vintage.ingestedSplitTime(S, A, ...
                'ti_group1_seg.nbf_3'), 'NDI:daq:reader:ingestedFileNotFound');

            % THE ROUND TRIP (DID-matlab): the v1 group file's segments and
            % names rebuilt from the split values, compared with what NDI's
            % ingest wrote into the v1 file (the two columns given to
            % ndi.compress.compress_time). Not with ndi.compress.expand_time
            % of the v1 file: NDI-compress's expand_time adds the residuals
            % compress_time stores as prediction - sample, so it does not
            % give back an unevenly spaced sample (it gives 2 * prediction -
            % sample; measured here in run 44583490586, row 50 of t1: 5.00487
            % read for 5.00493 written). Reading a new file of the split
            % values with it twice-reflects back to the written times, as
            % the rebased single-channel path does
            % (testUnevenTimeNotFromZeroIsRewrittenFromTheStart)
            if isempty(which('did2.convert.roundtrip.ingestedArchiveFiles'))
                return;
            end
            ref = struct('document_class', struct('class_name', 'relative_time_reference'), ...
                'base', struct('id', 'tr_1', 'session_id', 'sess_1'), ...
                'relative_time_reference', struct('value', struct('clock', 'dev_local_time', ...
                    'start', struct('seconds', 5), 'duration', struct('seconds', 159/10000))), ...
                'depends_on', struct('name', {}, 'value', {}));
            batch = [out, {ref}];
            cl = out{strcmp(ids, 'body_cl')};
            R = did2.convert.roundtrip.ingestedArchiveFiles({ai, ax, cl}, batch, ...
                'ReadBody', @(b) timeBodyValues(testCase.Dir, b));
            testCase.assertNumElements(R.split_time, 1);
            st = R.split_time;
            testCase.verifyEqual(st.state, 'rebuilt', st.why);
            testCase.verifyEqual(st.name, 'ti_group1_seg.nbf_#');
            testCase.verifyEqual(st.channels, [1 2]);
            testCase.verifyEqual(st.segments, {'ti_group1_seg.nbf_1', 'ti_group1_seg.nbf_2'});
            orig = struct('member_names', {{'channel_list.bin', 'ai_group1_seg.nbf_1', ...
                'ai_group1_seg.nbf_2', 'ax_group1_seg.nbf_1', 'ax_group1_seg.nbf_2', ...
                'ti_group1_seg.nbf_1', 'ti_group1_seg.nbf_2'}}, ...
                'time_segments', struct('name', {'ti_group1_seg.nbf_1', 'ti_group1_seg.nbf_2'}, ...
                    'data', {tv1(1:100, :), tv1(101:160, :)}));
            C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, orig, 'TimeTolerance', 1e-9);
            testCase.verifyEqual(C.files_compared, 3, 'the denominator');
            testCase.verifyTrue(C.exact, strjoin(arrayfun(@(f) [f.name ': ' ...
                strjoin(f.differences, '; ') ' ' f.why], C.files, 'UniformOutput', false), ' || '));
        end

        function testAChannelGroupNamingTwoSplitTimeValuesKeepsTheArchive(testCase)
            % [time group with several time channels split]: "a channel group
            % whose rows name time channels in two different time values
            % can't be keyed to one, so that archive is kept as v1 and
            % counted, as a sample-count mismatch is"
            [structs, v1] = testCase.splitTimeGroup(struct('axTimeChannel', [1 2]));
            nFiles = numel(dir(fullfile(testCase.Dir, 'files'))) - 2;
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_seen, 1, 'the denominator');
            testCase.verifyEqual(rep.archives_converted, 0);
            testCase.verifyEqual(rep.uneven_time_split_ambiguous_kept, 1, ...
                rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.uneven_time_mismatch_kept, 0);
            testCase.verifyEqual(rep.uneven_time_unpaired_kept, 0);
            testCase.verifyEqual(rep.unconvertible, 1);
            testCase.verifyEqual(rep.uneven_time_groups_split, 0, 'counted for converted archives');
            testCase.verifyEmpty(removed);
            testCase.verifyEqual(out, structs, 'kept as pass 1 wrote it');
            testCase.verifyEqual(numel(dir(fullfile(testCase.Dir, 'files'))) - 2, nFiles, ...
                'no file written');
            testCase.assertNumElements(rep.uneven_time_kept, 1);
            k = rep.uneven_time_kept{1};
            testCase.verifyEqual(k.kind, 'split_ambiguous');
            testCase.verifyEqual(k.archive_id, 'arch_1');
            testCase.verifyEqual(k.group_body_id, 'body_ax');
            testCase.verifyEqual(k.time_body_id, 'body_ti');
            testCase.verifySubstring(k.reason, 'kept as v1');
            testCase.verifyEqual(rep.first_uneven_time_kept_reason, k.reason);
        end

        function testASplitTimeChannelOfAnotherLengthKeepsTheArchive(testCase)
            % [uneven time groups and mismatches] (2) holds for a split
            % channel: the auxiliary group's 150 samples are not t2's 160
            [structs, v1] = testCase.splitTimeGroup(struct('axN', 150));
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 0);
            testCase.verifyEqual(rep.uneven_time_mismatch_kept, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.uneven_time_split_ambiguous_kept, 0);
            testCase.assertNumElements(rep.uneven_time_kept, 1);
            testCase.verifyEqual(rep.uneven_time_kept{1}.time_body_id, 'body_ti');
            testCase.verifyEqual(out, structs);
        end

        function testASplitTimeChannelNoGroupNamesLeavesTheArchive(testCase)
            % both groups name t1: t2's time value would be keyed by nothing,
            % and the readers find a time value only through the groups'
            % key_id, so the archive is left (no decision covers it), counted
            [structs, v1] = testCase.splitTimeGroup(struct('axTimeChannel', [1 1]));
            nFiles = numel(dir(fullfile(testCase.Dir, 'files'))) - 2;
            [out, rep] = ndi.migrate.internal.ingestedArchiveBodies(structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 0);
            testCase.verifyEqual(rep.unconvertible, 1);
            testCase.verifySubstring(rep.first_unconvertible_reason, 'named by no channel group');
            testCase.verifyEqual(rep.uneven_time_split_ambiguous_kept, 0);
            testCase.verifyEmpty(rep.uneven_time_kept);
            testCase.verifyEqual(out, structs);
            testCase.verifyEqual(numel(dir(fullfile(testCase.Dir, 'files'))) - 2, nFiles);
        end

        function testAnEvenlySpacedTimeGroupOfSeveralChannelsIsNotSplit(testCase)
            % the control: both time channels of the group evenly spaced, so
            % the group adds nothing the groups' time covariates do not say
            % ([evenly spaced time is a covariate]): its body is removed and
            % nothing is split
            [structs, v1] = testCase.splitTimeGroup(struct('even', true));
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.archives_converted, 1, rep.first_unconvertible_reason);
            testCase.verifyEqual(rep.time_not_evenly_spaced, 0);
            testCase.verifyEqual(rep.uneven_time_groups_split, 0);
            testCase.verifyEqual(rep.uneven_time_channels_split, 0);
            testCase.verifyEqual(rep.uneven_time_values, 0);
            testCase.verifyTrue(ismember('body_ti', removed));
            testCase.verifyEqual(numel(out), numel(structs), 'nothing added');
            ids = cellfun(@(x) x.base.id, out, 'UniformOutput', false);
            ax = out{strcmp(ids, 'body_ax')};
            testCase.verifyEmpty(edgeOf(ax, 'key_id'));
            t = covOf(ax, 'om:Time');
            testCase.verifyEqual(double(t.spacing), 1/10000, 'AbsTol', 1e-15);
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
        function [out, rep, removed] = convertArchive(testCase, varargin)
            % the archive fixture (ARCHIVE's arguments), converted
            [structs, v1] = testCase.archive(varargin{:});
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
        end

        function [s, v1] = twoTimeGroups(testCase, o)
            % an epoch with two time groups, as NDI's ingest writes them
            % (ndi.file.type.mfdaq_epoch_channel: a time channel's group is
            % 1 + floor(number / 100000)): 3 analog inputs at 10 kHz (160
            % samples) timed by t1 (group 1), 2 auxiliary inputs at 5 kHz (80
            % samples) timed by t100001 (group 2); both time channels not
            % evenly spaced. O.axEven: t100001 evenly spaced; O.axTimeN: the
            % samples of t100001 (80); O.axTimeChannel: the auxiliary rows'
            % v1 time_channel (100001)
            if ~isfield(o, 'axEven'); o.axEven = false; end
            if ~isfield(o, 'axTimeN'); o.axTimeN = 80; end
            if ~isfield(o, 'axTimeChannel'); o.axTimeChannel = 100001; end
            files = fullfile(testCase.Dir, 'files');
            ch = struct('name', {'ai1', 'ai2', 'ai3', 'ax1', 'ax2', 't1', 't100001'}, ...
                'type', {'analog_in', 'analog_in', 'analog_in', 'auxiliary_in', ...
                    'auxiliary_in', 'time', 'time'}, ...
                'time_channel', {1, 1, 1, o.axTimeChannel, o.axTimeChannel, 1, 100001}, ...
                'sample_rate', {10000, 10000, 10000, 5000, 5000, 10000, 5000}, ...
                'offset', {-2, -2, -2, 0, 0, 0, 0}, ...
                'scale', {0.195, 0.195, 0.195, 3.74e-05, 3.74e-05, 1, 1});
            ec = ndi.file.type.mfdaq_epoch_channel(ch);
            [ok, msg] = ec.writeToFile(fullfile(files, 'u_cl'));
            testCase.assertTrue(logical(ok), msg);
            ai = int16(round(1000 * sin((1:160)' * [0.05 0.11 0.23])));
            ax = int16(round(800 * cos((1:80)' * [0.07 0.13])));
            segs = {ai(1:100, :), ai(101:160, :), ax};
            names = {'u_ai_1', 'u_ai_2', 'u_ax_1'};
            for k = 1:3
                stem = tempname();
                ndi.compress.compress_ephys(double(segs{k}), 16, stem, ...
                    'data_format', ndi.compress.datatypestring('int16'), ...
                    'data_is_unsigned', false);
                movefile([stem '.nbf.tgz'], fullfile(files, names{k}));
            end
            t1 = (0:159)' / 10000;
            t1(50) = t1(50) + 0.3 / 10000;
            t2 = (0:o.axTimeN - 1)' / 5000;
            if ~o.axEven; t2(20) = t2(20) + 0.3 / 5000; end
            tsegs = {t1(1:100), t1(101:160), t2};
            tnames = {'u_ti1_1', 'u_ti1_2', 'u_ti2_1'};
            for k = 1:3
                stem = tempname();
                ndi.compress.compress_time(tsegs{k}, stem);
                movefile([stem '.nbf.tgz'], fullfile(files, tnames{k}));
            end
            s = {owner(), ...
                body('body_ai', 'ai_group1_seg.nbf_#', {'u_ai_1', 'u_ai_2'}), ...
                body('body_ax', 'ax_group1_seg.nbf_#', {'u_ax_1'}), ...
                body('body_cl', 'channel_list.bin', {'u_cl'}), ...
                body('body_ti1', 'ti_group1_seg.nbf_#', {'u_ti1_1', 'u_ti1_2'}), ...
                body('body_ti2', 'ti_group2_seg.nbf_#', {'u_ti2_1'})};
            uids = ['u_cl', names, tnames];
            locs = cellfun(@(u) struct('delete_original', 0, 'uid', u, ...
                'location', '/gone', 'parameters', '', 'location_type', 'file', ...
                'ingest', 1), uids);
            fi = struct('name', uids, 'locations', num2cell(locs));
            v1 = {struct('base', struct('id', 'arch_1'), ...
                'document_class', struct('class_name', 'daqreader_mfdaq_epochdata_ingested'), ...
                'daqreader_mfdaq_epochdata_ingested', struct('parameters', ...
                    struct('sample_analog_segment', 100, 'sample_digital_segment', 100)), ...
                'daqreader_epochdata_ingested', struct('epochtable', ...
                    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 159/10000])), ...
                'files', struct('file_list', {{'channel_list.bin'}}, 'file_info', fi))};
        end

        function [s, v1, t] = splitTimeGroup(testCase, o)
            % an epoch whose one time group file ti_group1 holds two time
            % channels, as NDI's ingest writes them (ndi.file.type.
            % mfdaq_epoch_channel: t1 and t2 are both group 1 + floor(n /
            % 100000) = 1, so ndi.daq.reader.mfdaq/ingest_epochfiles reads both
            % and writes one ndi.compress.compress_time file per segment of
            % 100, the two columns T): 3 analog inputs at 10 kHz (160 samples)
            % timed by t1, 2 auxiliary inputs at 10 kHz timed by t2. O.t0: the
            % epoch's start (0); O.axTimeChannel: the auxiliary rows' v1
            % time_channel ([2 2]); O.axN: the auxiliary samples (160);
            % O.even: both time channels evenly spaced (false)
            if ~isfield(o, 't0'); o.t0 = 0; end
            if ~isfield(o, 'axTimeChannel'); o.axTimeChannel = [2 2]; end
            if ~isfield(o, 'axN'); o.axN = 160; end
            if ~isfield(o, 'even'); o.even = false; end
            files = fullfile(testCase.Dir, 'files');
            sr = 10000;
            ch = struct('name', {'ai1', 'ai2', 'ai3', 'ax1', 'ax2', 't1', 't2'}, ...
                'type', {'analog_in', 'analog_in', 'analog_in', 'auxiliary_in', ...
                    'auxiliary_in', 'time', 'time'}, ...
                'time_channel', {1, 1, 1, o.axTimeChannel(1), o.axTimeChannel(2), 1, 2}, ...
                'sample_rate', sr, ...
                'offset', {-2, -2, -2, 0, 0, 0, 0}, ...
                'scale', {0.195, 0.195, 0.195, 3.74e-05, 3.74e-05, 1, 1});
            ec = ndi.file.type.mfdaq_epoch_channel(ch);
            [ok, msg] = ec.writeToFile(fullfile(files, 'u_cl'));
            testCase.assertTrue(logical(ok), msg);
            ai = int16(round(1000 * sin((1:160)' * [0.05 0.11 0.23])));
            ax = int16(round(800 * cos((1:o.axN)' * [0.07 0.13])));
            segs = {ai(1:100, :), ai(101:160, :), ax(1:100, :), ax(101:end, :)};
            names = {'u_ai_1', 'u_ai_2', 'u_ax_1', 'u_ax_2'};
            for k = 1:4
                stem = tempname();
                ndi.compress.compress_ephys(double(segs{k}), 16, stem, ...
                    'data_format', ndi.compress.datatypestring('int16'), ...
                    'data_is_unsigned', false);
                movefile([stem '.nbf.tgz'], fullfile(files, names{k}));
            end
            t = o.t0 + repmat((0:159)' / sr, 1, 2);
            if ~o.even
                t(50, 1) = t(50, 1) + 0.3 / sr;
                t(70, 2) = t(70, 2) + 0.2 / sr;
            end
            tsegs = {t(1:100, :), t(101:160, :)};
            tnames = {'u_ti_1', 'u_ti_2'};
            for k = 1:2
                stem = tempname();
                ndi.compress.compress_time(tsegs{k}, stem);
                movefile([stem '.nbf.tgz'], fullfile(files, tnames{k}));
            end
            s = {owner(), ...
                body('body_ai', 'ai_group1_seg.nbf_#', {'u_ai_1', 'u_ai_2'}), ...
                body('body_ax', 'ax_group1_seg.nbf_#', {'u_ax_1', 'u_ax_2'}), ...
                body('body_cl', 'channel_list.bin', {'u_cl'}), ...
                body('body_ti', 'ti_group1_seg.nbf_#', tnames)};
            uids = ['u_cl', names, tnames];
            locs = cellfun(@(u) struct('delete_original', 0, 'uid', u, ...
                'location', '/gone', 'parameters', '', 'location_type', 'file', ...
                'ingest', 1), uids);
            fi = struct('name', uids, 'locations', num2cell(locs));
            v1 = {struct('base', struct('id', 'arch_1'), ...
                'document_class', struct('class_name', 'daqreader_mfdaq_epochdata_ingested'), ...
                'daqreader_mfdaq_epochdata_ingested', struct('parameters', ...
                    struct('sample_analog_segment', 100, 'sample_digital_segment', 100)), ...
                'daqreader_epochdata_ingested', struct('epochtable', ...
                    struct('epochclock', {{'dev_local_time'}}, ...
                    't0_t1', [o.t0; o.t0 + 159/sr])), ...
                'files', struct('file_list', {{'channel_list.bin'}}, 'file_info', fi))};
        end

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
            % O.eventName, the event channel's v1 name ('e1'); O.text, a
            % text channel tx3 in the events file too (entries O.entries),
            % wired with the others unless O.wireText is false;
            % O.timeRowTimeChannel and O.timeRowOffset, the v1 time row
            % t1's time_channel (NaN) and offset (0)
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
            if ~isfield(o, 'text'); o.text = false; end
            if ~isfield(o, 'entries'); o.entries = {'start', 'stop now', ''}; end
            if ~isfield(o, 'wireText'); o.wireText = true; end
            if ~isfield(o, 'timeRowTimeChannel'); o.timeRowTimeChannel = NaN; end
            if ~isfield(o, 'timeRowOffset'); o.timeRowOffset = 0; end
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
                if o.text
                    ch(end+1) = struct('name', 'tx3', 'type', 'text', 'time_channel', NaN, ...
                        'sample_rate', NaN, 'offset', 0, 'scale', 1);
                end
            end
            if withTime
                ch(end+1) = struct('name', 't1', 'type', 'time', ...
                    'time_channel', o.timeRowTimeChannel, ...
                    'sample_rate', sr, 'offset', o.timeRowOffset, 'scale', 1);
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
                    'D', {{ones(3, 1), [7; 2]}}, 'types', {{'event', 'marker'}}, ...
                    'numbers', [1 2]);
                if o.text
                    ev.T{3} = t0 + [0.003; 0.004; 0.012];
                    ev.D{3} = o.entries;
                    ev.types{3} = 'text';
                    ev.numbers(3) = 3;
                end
                stem = tempname();
                ndi.compress.compress_eventmarktext(ev.types, ev.numbers, ev.T, ev.D, stem);
                movefile([stem '.nbf.tgz'], fullfile(files, 'u_ev'));
                if o.text
                    % what NDI's own expander reads back from the file
                    stem2 = tempname();
                    copyfile(fullfile(files, 'u_ev'), [stem2 '.nbf.tgz']);
                    try
                        [~, ~, ev.T, ev.D] = ndi.compress.expand_eventmarktext(stem2);
                    catch
                        % NDI-compress writes a non-ASCII character as
                        % UTF-8 but reads it back byte by byte
                        ev.unreadable = true;
                    end
                    delete([stem2 '.nbf.tgz']);
                end
                s{end+1} = body('body_ev', 'evmktx_group1_seg.nbf_#', {'u_ev'});
                uids{end+1} = 'u_ev';
                if o.wired
                    s{end+1} = wiring(o.text && o.wireText);
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

function rel = wiring(withText)
% the stimulator stim_1 `connected to` the system sys_1 on e1 and mk2 (and,
% WITHTEXT, tx3), as did2.convert.resolveEpochProbemap mkWiring writes it
if nargin < 1; withText = false; end
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
conds = {did2.build.condition(struct('node', 'EMPTY:0000376', 'name', 'event channel'), 'Matrix', 1), ...
    did2.build.condition(struct('node', 'EMPTY:0000377', 'name', 'marker channel'), 'Matrix', 2)};
if withText
    conds{end+1} = did2.build.condition(struct('node', 'EMPTY:0000410', 'name', 'text channel'), 'Matrix', 3);
end
rel = did2.build.directedRelation('stim_1', 'sys_1', ...
    struct('node', 'RO:0002170', 'name', 'connected to'), ...
    'TimeReferenceIds', {'tr_1'}, ...
    'Fields', struct('conditions', {did2.build.list(conds{:})}), ...
    'Id', 'rel_1', 'SessionId', 'sess_1', 'Validate', false);
end

function x = bytesOf(dir, b)
% an unpacked body's member body_data_0, as a row of bytes
fi = b.files.file_info;
fid = fopen(fullfile(dir, 'files', char(fi(1).locations(1).uid)), 'r');
x = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);
x = reshape(x, 1, []);
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

function tc = timeChannelOf(b)
% the time channel a split time body names (condition "time channel",
% EMPTY:0000374, count); NaN when it names none
tc = NaN;
if ~isfield(b.data_body, 'conditions'); return; end
cs = b.data_body.conditions;
if isstruct(cs); cs = num2cell(cs); end
for k = 1:numel(cs)
    if isfield(cs{k}, 'variable') && strcmp(char(cs{k}.variable.node), 'EMPTY:0000374')
        tc = double(cs{k}.count);
        return;
    end
end
end

function S = fakeBinarySession(dir)
% the two session calls ndi.vintage.ingestedSplitTime makes: a member of a
% body (wrapped as {document_properties}) opened from the store under DIR
S = struct('database_openbinarydoc', @(doc, member) openMember(dir, doc, member), ...
    'database_closebinarydoc', @(f) []);
end

function f = openMember(dir, doc, member)
p = memberPath(dir, doc.document_properties, member);
f = struct('fread', @(varargin) bytesAt(p));
end

function p = memberPath(dir, b, member)
fi = b.files.file_info;
if isstruct(fi); fi = num2cell(fi); end
for k = 1:numel(fi)
    if strcmp(char(fi{k}.name), member)
        p = fullfile(dir, 'files', char(fi{k}.locations(1).uid));
        return;
    end
end
error('test:noMember', 'no member %s', member);
end

function x = bytesAt(p)
fid = fopen(p, 'r');
x = fread(fid, Inf, 'uint8');
fclose(fid);
end

function x = timeBodyValues(dir, b)
% a time body's values (its members body_data_0.. in order, each expanded
% by NDI's own expander), as the round trip's ReadBody gives them
fi = b.files.file_info;
if isstruct(fi); fi = num2cell(fi); end
x = [];
for m = 1:numel(fi)
    x = [x; readTime(memberPath(dir, b, sprintf('body_data_%d', m - 1)))]; %#ok<AGROW>
end
end
