classdef TestArchiveSegmentLengths < matlab.unittest.TestCase
%TESTARCHIVESEGMENTLENGTHS ndi.migrate.internal.archiveSegmentLengths: each v1
%   ingested archive's sample_analog_segment and sample_digital_segment,
%   rebuilt from the v2 bodies' time chunks after NDI's second pass and
%   compared with the v1 values (Decided by Jess Haley, 2026-11-12 [archive
%   segment lengths measured after the second pass]; [segment length is the
%   time chunk], 2026-10-29).
%
%   The fixture is one archive written as ndi.daq.reader.mfdaq/
%   ingest_epochfiles writes it, by NDI's own writers (ndi.compress,
%   ndi.file.type.mfdaq_epoch_channel), as TestIngestedArchiveBodies builds
%   its fixtures: 160 samples at 10 kHz, three analog inputs cut at the
%   analog segment length (100) and two digital inputs cut at the digital
%   segment length (120, so the two fields cannot be confused), carried by
%   pass 1 as opaque bodies; the real second pass
%   (ndi.migrate.internal.ingestedArchiveBodies) converts them, and the
%   comparison reads what it wrote.

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

        function testTheConvertedBodiesCarryTheV1Lengths(testCase)
            [structs, v1] = testCase.archive(true);
            out = testCase.secondPass(structs, v1);
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual(r.archives_inspected, 1, 'the denominator');
            testCase.verifyEqual(r.bodies_inspected, numel(out) - 1, ...
                'every body is read (all but the owning observation)');
            testCase.verifyEqual(r.state, 'measured');
            testCase.verifyEqual(r.archives_measured, 1);
            testCase.verifyEqual(r.archives_not_measured, 0);
            testCase.verifyEqual([r.analog.v1_stated r.analog.compared r.analog.equal ...
                r.analog.differ r.analog.no_v2_home], [1 1 1 0 0], 'sample_analog_segment');
            testCase.verifyEqual([r.digital.v1_stated r.digital.compared r.digital.equal ...
                r.digital.differ r.digital.no_v2_home r.digital.no_digital_default], ...
                [1 1 1 0 0 0], 'sample_digital_segment');
            testCase.verifyEmpty(r.differences);
            % the v1 bodies as JSON text, as did2.convert.readers hand them over
            r2 = ndi.migrate.internal.archiveSegmentLengths(out, ...
                cellfun(@jsonencode, v1, 'UniformOutput', false), testCase.Dir);
            testCase.verifyEqual(r2, r);
        end

        function testAChunkThatIsNotTheV1LengthDiffers(testCase)
            [structs, v1] = testCase.archive(true);
            out = testCase.secondPass(structs, v1);
            k = find(cellfun(@(b) strcmp(b.base.id, 'body_ai'), out));
            out{k}.data.dimensions(1).chunk = 99;
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual([r.analog.compared r.analog.equal r.analog.differ], [1 0 1]);
            testCase.verifyEqual([r.digital.compared r.digital.equal r.digital.differ], [1 1 0], ...
                'the digital length is read from the digital body only');
            testCase.assertNumElements(r.differences, 1);
            d = r.differences(1);
            testCase.verifyEqual(d.archive_id, 'arch_1');
            testCase.verifyEqual(d.field, ...
                'daqreader_mfdaq_epochdata_ingested.parameters.sample_analog_segment');
            testCase.verifyEqual([d.v1 d.v2], [100 99]);
        end

        function testAMissingChunkDiffers(testCase)
            [structs, v1] = testCase.archive(true);
            out = testCase.secondPass(structs, v1);
            k = find(cellfun(@(b) strcmp(b.base.id, 'body_di'), out));
            out{k}.data.dimensions(1).chunk = [];
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual([r.digital.compared r.digital.differ], [1 1]);
            testCase.verifyTrue(contains(r.differences(1).why, 'no time chunk'), ...
                r.differences(1).why);
        end

        function testNoDigitalGroupIsAStatedValueWithNoV2Home(testCase)
            % the v1 ingest states both lengths for every archive; with no
            % digital channel, no body holds sample_digital_segment. The
            % fixture's 120 is not the writer's default (1e7), so it is not
            % notation: reported as no v2 home, not compared
            [structs, v1] = testCase.archive(false);
            out = testCase.secondPass(structs, v1);
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual([r.analog.compared r.analog.equal], [1 1]);
            testCase.verifyEqual([r.digital.v1_stated r.digital.compared ...
                r.digital.no_digital_default r.digital.no_v2_home], [1 0 0 1]);
        end

        function testNoDigitalGroupAtTheWriterDefaultIsNotation(testCase)
            % Decided by Jess Haley, 2026-11-19 [archive with no digital
            % channel]: the v1 writer (ndi.daq.reader.mfdaq/
            % ingest_epochfiles_plan, NDI origin/main mfdaq.m:848) writes
            % sample_digital_segment = 1e7 for every archive; on an archive
            % with no digital series that value is notation
            [structs, v1] = testCase.archive(false);
            out = testCase.secondPass(structs, v1);
            v1{1}.daqreader_mfdaq_epochdata_ingested.parameters.sample_digital_segment = 1e7;
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual(r.archives_measured, 1);
            testCase.verifyEqual([r.analog.compared r.analog.equal r.analog.no_digital_default], ...
                [1 1 0], 'the analog length is compared as before, and is never the digital default');
            testCase.verifyEqual([r.digital.v1_stated r.digital.compared r.digital.equal ...
                r.digital.differ r.digital.no_digital_default r.digital.no_v2_home], ...
                [1 0 0 0 1 0]);
            testCase.verifyEmpty(r.differences);
            % the same as JSON text
            r2 = ndi.migrate.internal.archiveSegmentLengths(out, ...
                cellfun(@jsonencode, v1, 'UniformOutput', false), testCase.Dir);
            testCase.verifyEqual(r2, r);
        end

        function testTheDefaultWithAnUnconvertedDigitalSeriesHasNoV2Home(testCase)
            % the archive HAS a digital series, still pass 1's opaque body:
            % 1e7 there is a value no converted body holds, not notation
            [structs, v1] = testCase.archive(true);
            out = testCase.secondPass(structs, v1);
            k = find(cellfun(@(b) strcmp(b.base.id, 'body_di'), out));
            j = find(cellfun(@(b) strcmp(b.base.id, 'body_di'), structs));
            testCase.assertNumElements(k, 1);
            testCase.assertNumElements(j, 1);
            out{k} = structs{j};
            v1{1}.daqreader_mfdaq_epochdata_ingested.parameters.sample_digital_segment = 1e7;
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual([r.analog.compared r.analog.equal], [1 1]);
            testCase.verifyEqual([r.digital.v1_stated r.digital.compared ...
                r.digital.no_digital_default r.digital.no_v2_home], [1 0 0 1]);
        end

        function testTheDefaultWithADigitalSegmentFileInV1HasNoV2Home(testCase)
            % the v1 archive names a digital segment file no body holds:
            % its 1e7 is not notation either
            [structs, v1] = testCase.archive(false);
            out = testCase.secondPass(structs, v1);
            v1{1}.daqreader_mfdaq_epochdata_ingested.parameters.sample_digital_segment = 1e7;
            loc = v1{1}.files.file_info(1).locations;
            loc.uid = 'u_di_gone';
            v1{1}.files.file_info(end+1) = struct('name', 'di_group1_seg.nbf_1', 'locations', loc);
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual([r.digital.v1_stated r.digital.compared ...
                r.digital.no_digital_default r.digital.no_v2_home], [1 0 0 1]);
        end

        function testBytesAbsentIsNotMeasured(testCase)
            % a document-only corpus (NDI-matlab #785): the second pass
            % converts nothing, so nothing is compared, and the report says
            % why rather than reading as equal
            [structs, v1] = testCase.archive(true);
            delete(fullfile(testCase.Dir, 'files', '*'));
            out = testCase.secondPass(structs, v1);
            r = ndi.migrate.internal.archiveSegmentLengths(out, v1, testCase.Dir);
            testCase.verifyEqual(r.archives_inspected, 1);
            testCase.verifyEqual(r.state, 'not measured');
            testCase.verifyEqual(r.archives_measured, 0);
            testCase.verifyEqual(r.not_measured_bytes_absent, 1);
            testCase.verifyEqual(r.not_measured_not_converted, 0);
            testCase.verifyEqual([r.analog.compared r.digital.compared], [0 0]);
            testCase.verifyEqual([r.analog.v1_stated r.digital.v1_stated], [0 0], ...
                'stated counts only the measured archives');
        end

        function testBytesHereButNotConvertedIsNotMeasured(testCase)
            [structs, v1] = testCase.archive(true);
            r = ndi.migrate.internal.archiveSegmentLengths(structs, v1, testCase.Dir);
            testCase.verifyEqual(r.state, 'not measured');
            testCase.verifyEqual(r.not_measured_not_converted, 1);
            testCase.verifyEqual(r.not_measured_bytes_absent, 0);
        end

        function testAnArchiveNoBodyNamesIsNotMeasured(testCase)
            [~, v1] = testCase.archive(true);
            r = ndi.migrate.internal.archiveSegmentLengths({}, v1, testCase.Dir);
            testCase.verifyEqual(r.archives_inspected, 1);
            testCase.verifyEqual(r.bodies_inspected, 0);
            testCase.verifyEqual(r.not_measured_no_v2_body, 1);
        end

        function testNoArchiveInspectsNothing(testCase)
            r = ndi.migrate.internal.archiveSegmentLengths({}, {}, testCase.Dir);
            testCase.verifyEqual(r.archives_inspected, 0);
            testCase.verifyEqual(r.state, 'not measured', 'zero archives is not a measurement');
        end
    end

    methods
        function out = secondPass(testCase, structs, v1)
            % ndi.migrate.internal.ingestedArchiveBodies, dropping what it
            % removes, as ndi.migrate.local does
            [out, ~, removed] = ndi.migrate.internal.ingestedArchiveBodies( ...
                structs, testCase.Dir, v1);
            out = out(~cellfun(@(s) any(strcmp(s.base.id, removed)), out));
        end

        function [s, v1] = archive(testCase, withDigital)
            sr = 10000;
            names = {'ai1', 'ai2', 'ai3'};
            types = repmat({'analog_in'}, 1, 3);
            if withDigital
                names = [names, {'di1', 'di2'}];
                types = [types, {'digital_in', 'digital_in'}];
            end
            ch = struct('name', names, 'type', types, 'time_channel', NaN, ...
                'sample_rate', sr, 'offset', 0, 'scale', 1);
            for k = 1:3; ch(k).offset = -2; ch(k).scale = 0.195; end
            files = fullfile(testCase.Dir, 'files');
            ec = ndi.file.type.mfdaq_epoch_channel(ch);
            [ok, msg] = ec.writeToFile(fullfile(files, 'u_cl'));
            testCase.assertTrue(logical(ok), msg);
            uids = {'u_cl'};
            % analog: cut at 100 (NDI's ephys compressor fits a predictor, so
            % a segment needs more samples than its order)
            data = int16(round(1000 * sin((1:160)' * [0.05 0.11 0.23])));
            aseg = {data(1:100, :), data(101:160, :)};
            for k = 1:2
                stem = tempname();
                ndi.compress.compress_ephys(double(aseg{k}), 16, stem, ...
                    'data_format', ndi.compress.datatypestring('int16'), ...
                    'data_is_unsigned', false);
                movefile([stem '.nbf.tgz'], fullfile(files, sprintf('u_ai_%d', k)));
            end
            uids = [uids, {'u_ai_1', 'u_ai_2'}];
            s = {owner(), body('body_ai', 'ai_group1_seg.nbf_#', {'u_ai_1', 'u_ai_2'}), ...
                body('body_cl', 'channel_list.bin', {'u_cl'})};
            if withDigital
                % digital: cut at 120
                dig = double(sin((1:160)' * [0.07 0.19]) > 0);
                dseg = {dig(1:120, :), dig(121:160, :)};
                for k = 1:2
                    stem = tempname();
                    ndi.compress.compress_digital(dseg{k}, stem);
                    movefile([stem '.nbf.tgz'], fullfile(files, sprintf('u_di_%d', k)));
                end
                uids = [uids, {'u_di_1', 'u_di_2'}];
                s{end+1} = body('body_di', 'di_group1_seg.nbf_#', {'u_di_1', 'u_di_2'});
            end
            locs = cellfun(@(u) struct('delete_original', 0, 'uid', u, ...
                'location', '/gone', 'parameters', '', 'location_type', 'file', ...
                'ingest', 1), uids);
            fi = struct('name', uids, 'locations', num2cell(locs));
            v1 = {struct('base', struct('id', 'arch_1'), ...
                'document_class', struct('class_name', 'daqreader_mfdaq_epochdata_ingested'), ...
                'daqreader_mfdaq_epochdata_ingested', struct('parameters', ...
                    struct('sample_analog_segment', 100, 'sample_digital_segment', 120)), ...
                'daqreader_epochdata_ingested', struct('epochtable', ...
                    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 159/sr])), ...
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
    'AcquisitionSystemId', 'sys_1', ...
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
