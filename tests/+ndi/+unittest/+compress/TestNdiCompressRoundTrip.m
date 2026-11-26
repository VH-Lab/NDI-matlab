classdef TestNdiCompressRoundTrip < matlab.unittest.TestCase
%TESTNDICOMPRESSROUNDTRIP What NDI-compress writes, NDI reads back unchanged.
%
%   NDI ingests event, marker and text channels with
%   ndi.compress.compress_eventmarktext and ephys with
%   ndi.compress.compress_ephys (ndi.daq.reader.mfdaq/ingest_epochfiles), and
%   reads them back with expand_eventmarktext, expand_ephys and
%   read_ndibinary. NDI-compress is installed from
%   Waltham-Data-Science/NDI-compress-matlabp (requirements.txt).
%
%   - VH-Lab/NDI-matlab#1282: a non-ASCII text entry is written as UTF-8
%     bytes; it must read back as the same characters. An ASCII control
%     shows the path works at all.
%   - VH-Lab/NDI-matlab#1275: the ephys header must record the original
%     format as a number (1 integer, 2 float), with the original
%     signedness and bit size, and signed data with negative values must
%     round-trip.
%   - VH-Lab/NDI-matlab#1276: a marker channel with several codes per
%     event (one column each, as NDR's ced_smr reader returns them) must
%     read back with every column, and the channel after it unshifted.
%   - Uneven time (Waltham-Data-Science/NDI-compress#18; Jess Haley,
%     2026-11-26 [no migration before the time-reading fix], did-schema
%     docs/plans/did_v2_standing_wiring_plan.md): a time file MATLAB's
%     compress_time wrote from unevenly spaced samples must read back, with
%     the expand_time NDI calls, to those samples. The fixture and its
%     original values are NDI-compress V2 f235447 (#19)
%     example-data/data_time_uneven.{nbf.tgz,bin,json}, copied beside this
%     file. It FAILS until NDI-compress-matlabp's p-code is rebuilt from
%     NDI-compress V2 f235447 or later: the old expand_time adds the
%     residual where it should subtract it.
%
%   Filtered (never passed) when ndi.compress is not on the path.

    properties
        Stems = {}
    end

    methods (TestMethodSetup)
        function needCompress(testCase)
            testCase.assumeTrue(~isempty(which('ndi.compress.compress_eventmarktext')), ...
                'ndi.compress (NDI-compress-matlabp) is not on the path');
        end
    end

    methods (TestMethodTeardown)
        function removeFiles(testCase)
            for i = 1:numel(testCase.Stems)
                f = [testCase.Stems{i} '.nbf.tgz'];
                if isfile(f); delete(f); end
            end
            testCase.Stems = {};
        end
    end

    methods (Test)
        function testAsciiTextEntriesRoundTrip(testCase)
            entries = {'start', 'stop now', 'x'};
            [T, D] = testCase.textRoundTrip(entries);
            testCase.verifyEqual(T{1}, [0.5; 1.5; 2.5]);
            testCase.verifyEqual(D{1}(:)', entries);
        end

        function testNonAsciiTextEntriesRoundTrip(testCase)
            % VH-Lab/NDI-matlab#1282: 2-byte (u-umlaut, e-acute, micro) and
            % 3-byte (euro sign) UTF-8 characters
            entries = {'start', ['stop ' char(252)], ...
                ['caf' char(233) ' 5 ' char(181) 'm ' char(8364)]};
            [T, D] = testCase.textRoundTrip(entries);
            testCase.verifyEqual(T{1}, [0.5; 1.5; 2.5]);
            testCase.verifyEqual(D{1}(:)', entries, ...
                'a non-ASCII text entry reads back as the characters written');
        end

        function testChannelAfterANonAsciiTextChannelIsIntact(testCase)
            % a text channel before an event channel: the event times must
            % not be shifted by the text channel's byte count
            stem = testCase.stem();
            ndi.compress.compress_eventmarktext({'text', 'event'}, [1 2], ...
                {[0.5; 1.5], [0.25; 0.75; 1.25]}, ...
                {{['a' char(252)], 'b'}, ones(3, 1)}, stem);
            [~, ~, T, D] = ndi.compress.expand_eventmarktext(stem);
            testCase.verifyEqual(D{1}(:)', {['a' char(252)], 'b'});
            testCase.verifyEqual(T{2}, [0.25; 0.75; 1.25]);
        end

        function testEphysHeaderRecordsTheFormatAsANumber(testCase)
            % VH-Lab/NDI-matlab#1275, integer data (signed, int16)
            D = int16([-1200 40; -3 -32000; 15 7; 900 -5; -8 2; 31000 -31000; 4 4; -2 1]);
            D = repmat(D, 25, 1);
            stem = testCase.stem();
            ndi.compress.compress_ephys(D, 16, stem, ...
                'data_format', 'integer', 'data_is_unsigned', false);
            [b, errmsg, p] = ndi.compress.read_ndibinary(stem);
            testCase.assertEqual(b, 1, errmsg);
            testCase.verifyEqual(p.original_format, 1, ...
                'original_format is 1 (integer), not the characters of ''integer''');
            testCase.verifyEqual(p.original_isunsigned, 0, 'original_isunsigned');
            testCase.verifyEqual(p.original_bits_per_sample, 16, 'original_bits_per_sample');
        end

        function testEphysHeaderRecordsFloatAsANumber(testCase)
            % VH-Lab/NDI-matlab#1275, float data
            D = [0.25 -1.5; 3.75 2; -0.125 8; 1 1];
            D = repmat(D, 10, 1);
            stem = testCase.stem();
            ndi.compress.compress_ephys(D, 64, stem, ...
                'data_format', 'float', 'data_is_unsigned', false);
            [b, errmsg, p] = ndi.compress.read_ndibinary(stem);
            testCase.assertEqual(b, 1, errmsg);
            testCase.verifyEqual(p.original_format, 2, ...
                'original_format is 2 (float), not the characters of ''float''');
            testCase.verifyEqual(p.original_isunsigned, 0, 'original_isunsigned');
            testCase.verifyEqual(p.original_bits_per_sample, 64, 'original_bits_per_sample');
        end

        function testSignedEphysRoundTrips(testCase)
            % the reader takes its clamp from the header's original fields
            D = int16(round(4000 * sin((1:400)' / 7 * [1 2.3]) - 2500));
            stem = testCase.stem();
            ndi.compress.compress_ephys(D, 16, stem, ...
                'data_format', 'integer', 'data_is_unsigned', false);
            D_out = ndi.compress.expand_ephys(stem);
            testCase.verifyEqual(double(D_out), double(D), ...
                'signed ephys data with negative values round-trips');
        end

        function testSingleCodeMarkerRoundTrips(testCase)
            % control for #1276: one code per event
            stem = testCase.stem();
            ndi.compress.compress_eventmarktext({'marker', 'event'}, [1 2], ...
                {[0.1; 0.2; 0.3], [0.05; 0.5]}, {[7; -2; 300], ones(2, 1)}, stem);
            [~, ~, T, D] = ndi.compress.expand_eventmarktext(stem);
            testCase.verifyEqual(T{1}, [0.1; 0.2; 0.3]);
            testCase.verifyEqual(D{1}, [7; -2; 300]);
            testCase.verifyEqual(T{2}, [0.05; 0.5]);
        end

        function testMultiCodeMarkerRoundTrips(testCase)
            % VH-Lab/NDI-matlab#1276: several codes per marker event, one
            % column each, followed by another channel
            codes = [7 1 0 0; 2 3 0 0; 9 4 1 0];
            stem = testCase.stem();
            ndi.compress.compress_eventmarktext({'marker', 'event'}, [1 2], ...
                {[0.1; 0.2; 0.3], [0.05; 0.5]}, {codes, ones(2, 1)}, stem);
            [~, ~, T, D] = ndi.compress.expand_eventmarktext(stem);
            testCase.verifyEqual(T{1}, [0.1; 0.2; 0.3]);
            testCase.verifyEqual(D{1}, codes, 'every code column of the marker reads back');
            testCase.verifyEqual(T{2}, [0.05; 0.5], 'the channel after the marker is not shifted');
        end

        function testMatlabWrittenUnevenTimeReadsBackAsTheOriginal(testCase)
            % Waltham-Data-Science/NDI-compress#18 / #19 (V2 f235447): a
            % file ndi.compress.compress_time wrote from 1000x2 unevenly
            % spaced samples (up to 30 us jitter at 10 kHz; a 0.25 s gap at
            % 20 kHz), read with ndi.compress.expand_time, the reader
            % ndi.daq.reader.mfdaq, ndi.migrate.internal.ingestedArchiveBodies
            % and ndi.vintage.ingestedSegmentLength call. Compared with the
            % ORIGINAL samples (data_time_uneven.bin), not with the writer.
            % Expected to FAIL until the p-code is rebuilt (see the header).
            here = fileparts(mfilename('fullpath'));
            fid = fopen(fullfile(here, 'data_time_uneven.json'), 'r');
            testCase.assertGreaterThan(fid, 0, 'data_time_uneven.json is missing');
            header = jsondecode(fread(fid, inf, 'char=>char')');
            fclose(fid);
            fid = fopen(fullfile(here, header.filename), 'r');
            testCase.assertGreaterThan(fid, 0, [header.filename ' is missing']);
            t = fread(fid, inf, header.dtype);
            fclose(fid);
            t = reshape(t, header.size(:)');
            testCase.assertSize(t, [1000 2], 'the original samples');
            % read a copy, so nothing is written beside the fixture
            stem = testCase.stem();
            copyfile(fullfile(here, 'data_time_uneven.nbf.tgz'), [stem '.nbf.tgz']);
            t_read = ndi.compress.expand_time(stem);
            testCase.verifySize(t_read, size(t));
            if isequal(size(t_read), size(t))
                d = abs(double(t_read(:)) - t(:));
                testCase.verifyLessThan(max(d), 1e-12, sprintf(['MATLAB-written ' ...
                    'uneven time did not read back to the original samples: %d of %d ' ...
                    'differ by more than 1e-12 (max %g s)'], nnz(d > 1e-12), numel(d), max(d)));
            end
        end
    end

    methods (Access = private)
        function s = stem(testCase)
            s = tempname();
            testCase.Stems{end + 1} = s;
        end

        function [T, D] = textRoundTrip(testCase, entries)
            stem = testCase.stem();
            ndi.compress.compress_eventmarktext({'text'}, 1, {[0.5; 1.5; 2.5]}, {entries}, stem);
            [~, ~, T, D] = ndi.compress.expand_eventmarktext(stem);
        end
    end
end
