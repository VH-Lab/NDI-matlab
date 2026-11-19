classdef TestIngestedMarkerCodes < matlab.unittest.TestCase
    % TESTINGESTEDMARKERCODES - an ingested marker with K codes per event reads back N x K
    %
    % VH-Lab/NDI-matlab#1276: NDR's ced_smr returns a Spike2 marker channel
    % as N x 4 uint8 (one row per event, its 4 code bytes), and NDI ingests it
    % with ndi.compress.compress_eventmarktext unchanged. NDI-compress V2
    % (Waltham-Data-Science/NDI-compress#16, 61f6bb3) stores and reads all
    % N x K codes (did-schema [multi-code markers keep every code],
    % did_v2_standing_wiring_plan.md). ndi.daq.reader.mfdaq/
    % readevents_epochsamples_ingested then did `data{i} = data{i}(:)` and
    % `data{i}(included,:)`, which keeps only the first column. It now keeps
    % one row per event (ndi.daq.reader.mfdaq.eventdatarows); a channel with
    % one code per event reads exactly as before.
    %
    % None of these tests needs NDI-compress's V2 file layout:
    %   - testEventDataRows and testIngestedEventDataRows call the shaping
    %     rules directly;
    %   - testV2Unpacked* read a v2 archive's unpacked event bodies
    %     (ndi.vintage.ingestedEventsRead), which are plain little-endian
    %     doubles, through the real readevents_epochsamples_ingested
    %     (ndi.unittest.daq.reader.MockIngestedEventsReader supplies the
    %     archive, ndi.unittest.daq.reader.MockBinarySession the bytes);
    %   - testV1ArchiveOneCodeMarker reads a v1 `evmktx` file with one code
    %     per event, which every NDI-compress version writes and reads, and
    %     is filtered (never passed) when ndi.compress is not on the path.
    % The same v1 read of a K = 4 marker needs NDI-compress V2 and is not
    % here: NDI CI installs NDI-compress-matlabp, whose V2 p-code has not
    % been rebuilt.
    %
    % UNVERIFIED: written without MATLAB; the first CI run is the first run.

    methods (Test)

        function testEventDataRows(testCase)
            f = @ndi.daq.reader.mfdaq.eventdatarows;
            % one code per event: made a column, as before
            testCase.verifyEqual(f([7; 2; 9], 3), [7; 2; 9]);
            testCase.verifyEqual(f([7 2 9], 3), [7; 2; 9]);
            testCase.verifyEqual(f(5, 1), 5);
            testCase.verifyEqual(size(f([], 0)), [0 1]);
            testCase.verifyEqual(f({'a', 'b'}, 2), {'a'; 'b'});
            % K codes per event: every column kept
            M = uint8([12 0 0 0; 7 1 0 0; 200 3 9 1]);
            testCase.verifyEqual(f(M, 3), M);
            testCase.verifyEqual(f(M(3,:), 1), M(3,:), 'one event with 4 codes keeps its row');
            % rows that are not the events: made a column, as before
            testCase.verifyEqual(f(M, 4), M(:));
        end

        function testIngestedEventDataRows(testCase)
            % ndi.vintage.ingestedEventData, the v2 reader's shaping rule
            [T, D] = ndi.vintage.ingestedEventData('marker', [0.1; 0.5], [7 2]);
            testCase.verifyEqual(T, [0.1; 0.5]);
            testCase.verifyEqual(D, [7; 2], 'one code per event: a column, as before');
            M = [12 0 0 0; 7 1 0 0; 200 3 9 1];
            [~, D] = ndi.vintage.ingestedEventData('marker', [0.5; 1.25; 2.75], M);
            testCase.verifyEqual(D, M);
            [~, D] = ndi.vintage.ingestedEventData('marker', 2.75, M(3,:));
            testCase.verifyEqual(D, M(3,:), 'one event with 4 codes keeps its row');
        end

        function testV2UnpackedFourCodeMarkerThenEvent(testCase)
            M = [12 0 0 0; 7 1 0 0; 200 3 9 1];
            [r, S] = ndi.unittest.daq.reader.TestIngestedMarkerCodes.v2Reader(M);
            ef = {'epochid://e1'};

            [T, D] = r.readevents_epochsamples_ingested({'marker', 'event'}, [1 2], ef, -Inf, Inf, S);
            testCase.verifyEqual(T{1}, 10 + [0.5; 1.25; 2.75]);
            testCase.verifyEqual(D{1}, M, 'every code of every event');
            testCase.verifyEqual(T{2}, 10 + [0.1; 3.3], 'the channel after the marker');
            testCase.verifyEqual(D{2}, [1; 1]);

            [T, D] = r.readevents_epochsamples_ingested({'marker'}, 1, ef, -Inf, Inf, S);
            testCase.verifyEqual(T, 10 + [0.5; 1.25; 2.75]);
            testCase.verifyEqual(D, M);

            % a window keeps whole rows
            [T, D] = r.readevents_epochsamples_ingested({'marker'}, 1, ef, 11, 13, S);
            testCase.verifyEqual(T, 10 + [1.25; 2.75]);
            testCase.verifyEqual(D, M(2:3,:));
            [T, D] = r.readevents_epochsamples_ingested({'marker'}, 1, ef, 12, 13, S);
            testCase.verifyEqual(T, 12.75);
            testCase.verifyEqual(D, M(3,:), 'one event in the window keeps its 4 codes');

            [T, D] = r.readevents_epochsamples_ingested({'event'}, 2, ef, -Inf, Inf, S);
            testCase.verifyEqual(T, 10 + [0.1; 3.3]);
            testCase.verifyEqual(D, [1; 1]);
        end

        function testV2UnpackedOneCodeMarker(testCase)
            % the control: one code per event reads as before, a column
            codes = [12; 7; 200];
            [r, S] = ndi.unittest.daq.reader.TestIngestedMarkerCodes.v2Reader(codes);
            ef = {'epochid://e1'};
            [T, D] = r.readevents_epochsamples_ingested({'marker', 'event'}, [1 2], ef, -Inf, Inf, S);
            testCase.verifyEqual(T{1}, 10 + [0.5; 1.25; 2.75]);
            testCase.verifyEqual(D{1}, codes);
            testCase.verifyEqual(T{2}, 10 + [0.1; 3.3]);
            testCase.verifyEqual(D{2}, [1; 1]);
            [T, D] = r.readevents_epochsamples_ingested({'marker'}, 1, ef, 12, 13, S);
            testCase.verifyEqual(T, 12.75);
            testCase.verifyEqual(D, 200);
        end

        function testV1ArchiveOneCodeMarker(testCase)
            % a v1 `evmktx` file, written as ingest_epochfiles writes it; one
            % code per event, so it needs no NDI-compress V2 layout
            testCase.assumeFalse(isempty(which('ndi.compress.compress_eventmarktext')), ...
                'ndi.compress (NDI-compress) is not on the path');
            stem = tempname;
            testCase.addTeardown(@() deleteIfThere([stem '.nbf.tgz']));
            ndi.compress.compress_eventmarktext({'marker', 'event'}, [1 2], ...
                {[0.5; 1.25; 2.75], [0.1; 3.3]}, {[12; 7; 200], ones(2,1)}, stem);
            fid = fopen([stem '.nbf.tgz'], 'r');
            bytes = fread(fid, Inf, 'uint8=>uint8');
            fclose(fid);
            files = containers.Map({'evmktx_group1_seg.nbf_1'}, {bytes});
            S = ndi.unittest.daq.reader.MockBinarySession(files);
            A = struct('vintage', 'v1', 'doc', struct('id', 'ingested'), 'epoch_id', 'e1');
            r = ndi.unittest.daq.reader.MockIngestedEventsReader(A, {[0 10]});
            ef = {'epochid://e1'};

            [T, D] = r.readevents_epochsamples_ingested({'marker', 'event'}, [1 2], ef, -Inf, Inf, S);
            testCase.verifyEqual(double(T{1}), [0.5; 1.25; 2.75]);
            testCase.verifyEqual(double(D{1}), [12; 7; 200]);
            testCase.verifyEqual(double(T{2}), [0.1; 3.3], 'the channel after the marker');
            [T, D] = r.readevents_epochsamples_ingested({'marker'}, 1, ef, 1, 3, S);
            testCase.verifyEqual(double(T), [1.25; 2.75]);
            testCase.verifyEqual(double(D), [7; 200]);
        end
    end

    methods (Static)

        function [r, S] = v2Reader(codes)
            % a v2 archive whose events file was unpacked into a marker
            % channel 1 with CODES (N x K; a 2-dimension body when K > 1,
            % [several marker numbers are a second dimension]) at times
            % 0.5, 1.25, 2.75 and an event channel 2 at 0.1, 3.3, seconds
            % from the epoch start 10
            tm = ndi.unittest.daq.reader.TestIngestedMarkerCodes.body([0.5; 1.25; 2.75], struct('n', 3));
            if size(codes, 2) > 1
                dims = struct('n', {size(codes, 1), size(codes, 2)});
            else
                dims = struct('n', numel(codes));
            end
            vm = ndi.unittest.daq.reader.TestIngestedMarkerCodes.body(codes, dims);
            te = ndi.unittest.daq.reader.TestIngestedMarkerCodes.body([0.1; 3.3], struct('n', 2));
            E = struct('type', {'marker', 'event'}, 'number', {1, 2}, ...
                'statement_id', {'obs_marker', 'obs_event'}, ...
                'values', {vm, te}, 'times', {tm, te});
            A = struct('vintage', 'v2', 'epoch_id', 'e1', ...
                'bodies', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'events', E);
            r = ndi.unittest.daq.reader.MockIngestedEventsReader(A, {[10 20]});
            S = ndi.unittest.daq.reader.MockBinarySession();
        end

        function b = body(x, dims)
            % an unpacked event body as ingestedArchiveBodies writes it:
            % little-endian doubles, the first dimension fastest
            bytes = typecast(double(x(:)'), 'uint8');
            [~, ~, endian] = computer();
            if endian == 'B'
                bytes = typecast(swapbytes(double(x(:)')), 'uint8');
            end
            b = struct('document_properties', struct('data', struct('dimensions', dims)), ...
                'bytes', bytes);
        end
    end
end

function deleteIfThere(f)
if isfile(f)
    delete(f);
end
end
