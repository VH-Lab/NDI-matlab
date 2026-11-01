classdef TestIngestedArchiveBodies < matlab.unittest.TestCase
%TESTINGESTEDARCHIVEBODIES ndi.migrate.internal.ingestedArchiveBodies: the NDI
%   second pass turns each v1 ingested mfdaq channel group (carried by pass 1
%   as an opaque_body of its segment files) into one sampled_body whose
%   channel list is covariates (Decided by Jess Haley, 2026-11-01 [ingested
%   archives are sampled bodies], [evenly spaced time is a covariate], [clock
%   only on the time reference]). The segments and channel_list.bin are
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
            testCase.verifyEqual(double(dims(1).n), 8);
            testCase.verifyEqual(double(dims(1).chunk), 5, 'chunk = the v1 segment length');
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
            res = did2.convert.v1_to_v2(out(keep), 'Validate', true, 'TargetVersion', 'V_eta');
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

        function testUnevenTimeLeavesTheArchive(testCase)
            [structs, v1] = testCase.archive(true, false);
            [out, rep, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            testCase.verifyEqual(rep.time_not_evenly_spaced, 1);
            testCase.verifyEqual(rep.archives_converted, 0);
            testCase.verifyEmpty(removed);
            testCase.verifyEqual(out, structs, 'nothing changed');
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
        function [s, v1] = archive(testCase, withTime, evenTime)
            % an epoch of 8 samples at 10 kHz, 3 analog inputs in segments
            % of 5, and (WITHTIME) the time channel t1
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
            data = reshape(int16(1:24), 8, 3);
            segs = {data(1:5, :), data(6:8, :)};
            for k = 1:2
                stem = tempname();
                ndi.compress.compress_ephys(double(segs{k}), 16, stem, ...
                    'data_format', ndi.compress.datatypestring('int16'), ...
                    'data_is_unsigned', false);
                movefile([stem '.nbf.tgz'], fullfile(files, sprintf('u_ai_%d', k)));
            end
            uids = {'u_cl', 'u_ai_1', 'u_ai_2'};
            obs = owner();
            s = {obs, ...
                body('body_ai', 'ai_group1_seg.nbf_#', {'u_ai_1', 'u_ai_2'}), ...
                body('body_cl', 'channel_list.bin', {'u_cl'})};
            if withTime
                t = (0:7)' / sr;
                if ~evenTime; t(5) = t(5) + 0.3 / sr; end
                tsegs = {t(1:5), t(6:8)};
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
                    struct('sample_analog_segment', 5, 'sample_digital_segment', 50)), ...
                'daqreader_epochdata_ingested', struct('epochtable', ...
                    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 7/sr])), ...
                'files', struct('file_list', {{'channel_list.bin'}}, 'file_info', fi))};
        end
    end
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
