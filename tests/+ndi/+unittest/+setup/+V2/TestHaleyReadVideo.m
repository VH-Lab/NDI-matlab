classdef TestHaleyReadVideo < matlab.unittest.TestCase
%TESTHALEYREADVIDEO A real video frame, read through NDI's V2 read path.
%
%   Builds TestHaleyRecordings' synthetic fixture, replaces ONE placeholder
%   (camera 2's 2022-02-04_12-10-51_2.mp4, plate 12) with a real short video
%   of known content, runs import_V2's write path for concentration_0001,
%   then opens the session, rebuilds camera 2 with daqsystem_load and reads
%   the epoch through ndi.daq.system.image -> ndi.daq.reader.image.ndr ->
%   ndr.reader('video'). Nothing else in CI reads a frame: TestHaleyWrite's
%   placeholders are not videos.
%
%   Needs an NDR that has ndr.reader.video (VH-Lab/NDR-matlab#140). There is
%   deliberately no assumption here: without it the test FAILS.
%
%   The video: MPEG-4 where VideoWriter can write it, otherwise Motion JPEG
%   AVI written to a .avi and renamed .mp4 (the import's file pattern wants
%   .mp4; Linux runners cannot write MPEG-4). The profile used is logged.
%   Both are lossy, so content is compared by per-channel means.

    properties (Constant)
        Y = 32
        X = 48
        T = 5
        FrameRate = 3
        MeanTol = 6
        Epoch = 'concentration_2022-02-04_12-10-51_2'
    end

    properties
        Root
        Truth
        Profile
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                ndi.setup.V2.schemaHasClass('study', schemaPath), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `study`');
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);

            % frame k is flat per channel, a different level per channel and
            % per frame, so channel order and frame index are both checked
            rgb = zeros(testCase.Y, testCase.X, 3, testCase.T, 'uint8');
            for k = 1:testCase.T
                rgb(:, :, 1, k) = 40 + 30 * k;
                rgb(:, :, 2, k) = 200 - 30 * k;
                rgb(:, :, 3, k) = 100;
            end
            testCase.Truth = rgb;
            file = fullfile(testCase.Root, 'haley', 'celegans', 'foragingConcentration', ...
                'videos', '22-02-04', '2022-02-04_12-10-51_2.mp4');
            testCase.Profile = writeVideoAsMp4(file, rgb, testCase.FrameRate);
            fprintf('VIDEO PROFILE: %s, written to %s\n', testCase.Profile, file);
        end
    end

    methods (Test)
        function testFrameTimesAreMeasuredAndCached(testCase)
            % stage 5 with ReadVideos (decision #87), over the one real
            % video: the table says 10796 frames and the file has T, which is
            % the case that stopped the first real run (an undeclared
            % framesDisagree check). The placeholders are not videos, so
            % they are reported unreadable and the run carries on.
            spec = jsondecode(fileread(fullfile(fileparts( ...
                which('ndi.setup.conv.haley.import_V2')), 'import_V2_spec.json')));
            sessions = ndi.setup.conv.haley.sessionList(testCase.Root, spec);
            cacheFile = fullfile(testCase.Root, 'haley_V2', 'video_frame_times.mat');
            [R, checks] = ndi.setup.conv.haley.recordingList(testCase.Root, sessions, ...
                'ReadVideos', true, 'FrameTimesCache', cacheFile);
            r = R(strcmp(R.epoch, testCase.Epoch), :);
            testCase.assertEqual(height(r), 1);
            ft = r.frame_times{1};
            testCase.verifyNumElements(ft, testCase.T, sprintf('frame times (%s)', testCase.Profile));
            testCase.verifyEqual(ft(1), 0, 'AbsTol', 1e-9, 'the first frame is at 0 s');
            testCase.verifyTrue(all(diff(ft) > 0), 'frame times increase');
            testCase.verifyEqual(r.n_frames, testCase.T, 'the decoded count replaces the table''s');
            testCase.verifyTrue(any(contains(checks.framesDisagree, ...
                sprintf('decodes to %d frame(s); the table says 10796', testCase.T))), ...
                strjoin(checks.framesDisagree, newline));
            testCase.verifyNotEmpty(checks.unreadable, 'the placeholders are not videos');

            % the cache holds the measured times, under the file's path, size and date
            testCase.assertTrue(isfile(cacheFile), 'the cache is written');
            testCase.verifyFalse(isfile([cacheFile '.partial.mat']), 'no partial file is left behind');
            testCase.verifyFalse(isfile([cacheFile '.decoding.txt']), ...
                'no note of a video being decoded is left behind');
            S = load(cacheFile, 'frameTimes');
            k = S.frameTimes.keys;
            hit = k(contains(k, '2022-02-04_12-10-51_2.mp4'));
            testCase.assertNumElements(hit, 1);
            testCase.verifyEqual(S.frameTimes(hit{1}), ft);
            % a second run takes the real video's times from the cache (the
            % placeholders are not cached: they never decode)
            out = evalc(['ndi.setup.conv.haley.recordingList(testCase.Root, sessions, ' ...
                '''ReadVideos'', true, ''FrameTimesCache'', cacheFile);']);
            testCase.verifyTrue(contains(out, '1 video(s) already in the cache'), out);
            testCase.verifyTrue(contains(out, ', 1 taken from the cache'), out);
            testCase.verifyFalse(contains(out, 'stopped while decoding'), out);
            % a run that was killed mid-video left the note behind: the next
            % run names that video
            fid = fopen([cacheFile '.decoding.txt'], 'w');
            fprintf(fid, '%s', '/data/haley/some_video.mp4 (started 19-Oct-2026 13:00:00)');
            fclose(fid);
            out = evalc(['ndi.setup.conv.haley.recordingList(testCase.Root, sessions, ' ...
                '''ReadVideos'', true, ''FrameTimesCache'', cacheFile);']);
            testCase.verifyTrue(contains(out, ['the last run stopped while decoding ' ...
                '/data/haley/some_video.mp4']), out);
            testCase.verifyFalse(isfile([cacheFile '.decoding.txt']), ...
                'a run that finishes removes the note');
        end

        function testReadFrameThroughDaqSystem(testCase)
            fprintf('ndr.reader.video: %s\n', which('ndr.reader.video'));
            result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations"], ...
                'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(testCase.Root, 'haley_V2'), ...
                'Write', true, 'Overwrite', true, 'ReadVideos', false);
            session = ndi.session.dir(result.sessions.path{1});
            sys = session.daqsystem_load();
            if ~iscell(sys), sys = {sys}; end
            names = cellfun(@(x) x.name, sys, 'UniformOutput', false);
            cam2 = sys{strcmp(names, 'camera2')};
            testCase.verifyClass(cam2.daqreader, 'ndi.daq.reader.image.ndr');
            testCase.verifyEqual(cam2.daqreader.ndr_reader_string, 'video');

            testCase.verifyEqual(cam2.numframes(testCase.Epoch), testCase.T, ...
                sprintf('numframes (%s)', testCase.Profile));
            f1 = cam2.readframes(testCase.Epoch, 1);
            testCase.verifyClass(f1, 'uint8');
            testCase.verifySize(f1, [testCase.Y testCase.X 3], ...
                'frame 1, YXCZT with singleton Z and T');
            testCase.verifyEqual(channelMeans(f1), channelMeans(testCase.Truth(:, :, :, 1)), ...
                'AbsTol', testCase.MeanTol, sprintf('frame 1 content (%s)', testCase.Profile));
            fT = cam2.readframes(testCase.Epoch, testCase.T);
            testCase.verifyEqual(channelMeans(fT), channelMeans(testCase.Truth(:, :, :, testCase.T)), ...
                'AbsTol', testCase.MeanTol, sprintf('last frame content (%s)', testCase.Profile));
        end
    end
end

function profile = writeVideoAsMp4(file, rgb, frameRate)
% MPEG-4 if this platform can write it; otherwise Motion JPEG AVI, renamed.
arguments
    file {mustBeText}
    rgb {mustBeNumeric}
    frameRate (1,1) {mustBeNumeric}
end
candidates = {'MPEG-4', file; 'Motion JPEG AVI', [tempname '.avi']};
if isfile(file), delete(file); end
for c = 1:size(candidates, 1)
    fn = candidates{c, 2};
    try
        w = VideoWriter(fn, candidates{c, 1});
        w.FrameRate = frameRate;
        w.Quality = 100;
        open(w);
        for k = 1:size(rgb, 4)
            writeVideo(w, rgb(:, :, :, k));
        end
        close(w);
    catch
        if isfile(fn), delete(fn); end
        continue
    end
    if ~strcmp(fn, file), movefile(fn, file); end
    profile = candidates{c, 1};
    return
end
error('TestHaleyReadVideo:noWriter', 'neither MPEG-4 nor Motion JPEG AVI could be written');
end

function m = channelMeans(frame)
arguments
    frame {mustBeNumeric}
end
m = reshape(mean(mean(double(frame), 1), 2), 1, []);
end
