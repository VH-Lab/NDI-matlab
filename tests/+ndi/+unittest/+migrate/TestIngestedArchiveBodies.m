classdef TestIngestedArchiveBodies < matlab.unittest.TestCase
%TESTINGESTEDARCHIVEBODIES ndi.migrate.internal.ingestedArchiveBodies: the NDI
%   second pass turns each v1 ingested mfdaq channel group (carried by pass 1
%   as an opaque_body of its segment files) into one sampled_body whose
%   channel list is covariates (Decided by Jess Haley, 2026-11-01 [ingested
%   archives are sampled bodies], [evenly spaced time is a covariate], [clock
%   only on the time reference], [uneven time is a keyed time value]; and
%   Jess Haley, 2026-11-12, [uneven time rewritten from the epoch start]). The segments and channel_list.bin are
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
            off = covs(strcmp(vars, 'signal offset configuration'));
            testCase.verifyEqual(double(off.quantity.value(:))', [-2 -2 -2]);
            testCase.verifyEqual(char(b.data_body.conditions(1).term.node), 'EMPTY:0000370');
            testCase.verifyEqual(numel(b.files.file_info), 2, 'the members are unchanged');
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
        function [s, v1, t] = archive(testCase, withTime, evenTime, t0)
            % an epoch of 160 samples at 10 kHz, 3 analog inputs in
            % segments of 100 (NDI's ephys compressor fits a predictor, so
            % a segment needs more samples than its order), and
            % (WITHTIME) the time channel t1, its v1 times T; the epoch
            % starts at T0 (0)
            if nargin < 4; t0 = 0; end
            sr = 10000;
            ch = struct('name', {'ai1', 'ai2', 'ai3'}, 'type', 'analog_in', ...
                'time_channel', NaN, 'sample_rate', sr, 'offset', -2, 'scale', 0.195);
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
                ndi.compress.compress_ephys(double(segs{k}), 16, stem, ...
                    'data_format', ndi.compress.datatypestring('int16'), ...
                    'data_is_unsigned', false);
                movefile([stem '.nbf.tgz'], fullfile(files, sprintf('u_ai_%d', k)));
            end
            uids = {'u_cl', 'u_ai_1', 'u_ai_2'};
            t = [];
            obs = owner();
            s = {obs, ...
                body('body_ai', 'ai_group1_seg.nbf_#', {'u_ai_1', 'u_ai_2'}), ...
                body('body_cl', 'channel_list.bin', {'u_cl'})};
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
                    struct('sample_analog_segment', 100, 'sample_digital_segment', 1000)), ...
                'daqreader_epochdata_ingested', struct('epochtable', ...
                    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [t0; t0 + 159/sr])), ...
                'files', struct('file_list', {{'channel_list.bin'}}, 'file_info', fi))};
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
    'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'time');
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
