classdef TestHaleyRecordings < matlab.unittest.TestCase
%TESTHALEYRECORDINGS Stage 5 of the Haley V2 import (acquisition listing), over a synthetic fixture.
%
%   Writes a stand-in for the raw data: a tableOfContents.xlsx and
%   experimentInfo.mat per C. elegans folder, placeholder .mp4 files in one
%   day's videos folder, and ecoli/bacteria.mat with placeholder .tiff
%   images. Checks the recordings listed, how they are matched to files,
%   plates and cameras, and the source checks. Videos are not opened
%   ('ReadVideos' stays false), so the placeholders need no content.

    properties
        Root
        Spec
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            specFile = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            testCase.Spec = jsondecode(fileread(specFile));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
        end
    end

    methods (Static)
        function writeFixture(root)
            % The raw-data stand-in, also used by TestHaleyWrite.
            ce = fullfile(root, 'haley', 'celegans');

            % foragingConcentration, one day (22-02-04):
            %   plate 11  camera 1  video + lawn clip; filmed twice (an
            %             hourly continuation), the lawn clip shared
            %   plate 12  camera 2  video + lawn clip
            %   plate 13  camera 1  video named but not on disk
            %   plate 14  camera 1  table says camera 1, file name says _2;
            %             numFrames 0
            % plus a video on disk that no row names.
            f = fullfile(ce, 'foragingConcentration');
            writeToc(f, {'0001', '22-02-04', 'nb', '0001-0016', 'grid [OD600 = 1]', 'yes', ''});
            t = @(h, m, s) datetime(2022, 2, 4, h, m, s);
            writeInfo(f, [1 1 1 1 1], [11 11 12 13 14], [1 2 1 1 1], [1 1 2 1 1], ...
                {'2022-02-04_12-10-51_1.avi', '2022-02-04_13-12-02_1.avi', '2022-02-04_12-10-51_2.avi', ...
                 '2022-02-04_14-16-36_1.avi', '2022-02-04_15-17-10_2.avi'}, ...
                {'2022-02-04_11-49-08_1.avi', '2022-02-04_11-49-08_1.avi', '2022-02-04_11-49-08_2.avi', ...
                 '', ''}, ...
                [t(12, 10, 51), t(13, 12, 2), t(12, 10, 51), t(14, 16, 36), t(15, 17, 10)], ...
                [10797 10797 10796 10797 0], [2.9991 2.9991 2.9991 2.9991 0]);
            writeTracks(f);
            writeEncounters(ce);
            v = fullfile(f, 'videos', '22-02-04');
            mkdir(v);
            for name = {'2022-02-04_12-10-51_1', '2022-02-04_13-12-02_1', '2022-02-04_12-10-51_2', ...
                        '2022-02-04_15-17-10_2', '2022-02-04_11-49-08_1', '2022-02-04_11-49-08_2', ...
                        '2022-02-04_11-58-24_1'}
                placeholder(fullfile(v, [name{1} '.mp4']), 100);
            end

            % The other folders: a day with no rows for it.
            for name = {'foragingMatching', 'foragingMini', 'foragingMutants', 'foragingSensory'}
                f = fullfile(ce, name{1});
                writeToc(f, {'0001', '23-02-24', 'nb', '0001-0004', 'grid [OD600 = 1]', 'yes', ''});
                writeInfo(f, 99, 1, 1, 1, {'x.avi'}, {''}, datetime(2023, 2, 24), 1, 1);
            end

            % E. coli: images 2 and 3 on disk, 1 and 4 not (4 is fluorescence).
            ec = fullfile(root, 'haley', 'ecoli');
            mkdir(fullfile(ec, 'images'));
            % real (tiny) 16-bit TIFFs: the write path reads their headers
            imwrite(uint16(magic(4)), fullfile(ec, 'images', '0002.tiff'));
            imwrite(uint16(magic(5)), fullfile(ec, 'images', '0003.tiff'));
            % stage 8: poured 25 Dec, cold room that evening, seeded 28 Dec,
            % cold room that afternoon, room temperature the morning of 30 Dec;
            % plate 2 without peptone
            d = @(day, h) datetime(2023, 12, day, h, 0, 0);
            info = table([1; 1], [1; 2], {'rectangle'; 'none'}, [1; 1], [0.5; 200], ...
                [d(25, 10); d(25, 10)], [d(25, 18); d(25, 18)], [d(28, 11); d(28, 11)], ...
                [d(28, 15); d(28, 15)], [d(30, 8); d(30, 8)], {'with'; 'without'}, ...
                [10; 10], [600; 600], ...
                'VariableNames', {'expNum', 'plateNum', 'template', 'OD600', 'lawnVolume', ...
                'timePoured', 'timePouredColdRoom', 'timeSeed', 'timeSeedColdRoom', ...
                'timeRoomTemp', 'peptone', 'OD600Real', 'CFU'}); %#ok<NASGU>
            metaData = table([1; 1; 1; 1], [1; 2; 3; 4], [1; 1; 2; 2], ...
                datetime(2023, 12, 30, 9, [38; 39; 40; 41], 0), ...
                {'a.tif'; 'b.tif'; 'c.tif'; 'd.tif'}, [0; 1; 1; 1], [30; 300; 300; 3000], ...
                [NaN; 9; 9; 9], [NaN; 1; NaN; NaN], ...
                'VariableNames', {'expNum', 'imageNum', 'plateNum', 'acquisitionTime', ...
                'fileName', 'fluorescence', 'exposureTime', 'backgroundImageNum', ...
                'brightfieldImageNum'}); %#ok<NASGU>
            % stage 10 part C (decision #62): image 2 (plate 1, 12 patches)
            % and image 3 (plate 2, one patch) were analysed. Image 2's mask is
            % the staggered 3 x 4 grid, its bottom-left patch shifted a column
            % left so bwlabel numbers it FIRST (as on the real image 2) while
            % the grid order makes the top-left patch 1; lawnAnalysis row j has
            % borderAmplitude 100 + j.
            mkdir(fullfile(ec, 'mask'));
            mkdir(fullfile(ec, 'closest'));
            m = false(40, 80);
            for x = [6 26 46 66]
                m(7:9, x-1:x+1) = true;                  % top row
                m(31:33, x-1:x+1) = true;                % bottom row
                m(19:21, x+9:x+11) = true;               % middle row, offset
            end
            m(31:33, 5:7) = false; m(31:33, 4:6) = true;  % bottom-left, a column left
            imwrite(m, fullfile(ec, 'mask', '0002.png'));
            imwrite(uint8(ones(40, 80)), fullfile(ec, 'closest', '0002.png'));
            m = false(10, 10); m(4:6, 4:6) = true;
            imwrite(m, fullfile(ec, 'mask', '0003.png'));
            j = (1:12)';
            lawnAnalysis = table([2 * ones(12, 1); 3], [0.1 * ones(12, 1); 0.2], ...
                [1000 + j; 2000], [900 * ones(12, 1); 1900], [0.9 * ones(12, 1); 0.8], ...
                [100 + j; 500], [50 + j; 250], ...
                'VariableNames', {'imageNum', 'xPeak', 'yPeak', 'yOuterEdge', 'circularity', ...
                'borderAmplitude', 'centerAmplitude'}); %#ok<NASGU>
            save(fullfile(ec, 'bacteria.mat'), 'info', 'metaData', 'lawnAnalysis');
        end
    end

    methods (Test)
        function testOneRowPerRecordingOnDisk(testCase)
            [R, ~] = testCase.list();
            testCase.verifyEqual(sum(strcmp(R.kind, 'behaviour')), 4, ...
                'plate 11 twice, 12, and 14; plate 13 has no file');
            testCase.verifyEqual(sum(strcmp(R.kind, 'lawn')), 2, 'plate 11''s clip is listed once');
            testCase.verifyEqual(sum(strcmp(R.kind, 'image')), 2);
            testCase.verifyEqual(numel(unique(R.epoch)), height(R));
        end

        function testEpochsSystemsAndPlates(testCase)
            [R, ~] = testCase.list();
            r = R(strcmp(R.epoch, 'concentration_2022-02-04_12-10-51_2'), :);
            testCase.verifyEqual(r.system{1}, 'camera2');
            testCase.verifyEqual(r.plate{1}, 'concentration_assayPlate0012');
            testCase.verifyEqual(r.source_name{1}, '2022-02-04_12-10-51_2.avi');
            testCase.verifyEqual(r.duration, 10796 / 2.9991, 'AbsTol', 1e-9);
            l = R(strcmp(R.epoch, 'concentration_2022-02-04_11-49-08_1'), :);
            testCase.verifyEqual(l.kind{1}, 'lawn');
            testCase.verifyEqual(l.local_start, datetime(2022, 2, 4, 11, 49, 8), ...
                'a lawn clip starts at the time in its name');
            testCase.verifyTrue(isnan(l.duration), 'not read without ReadVideos');
            e = R(strcmp(R.epoch, 'ecoli_image0002'), :);
            testCase.verifyEqual(e.system{1}, 'microscope');
            testCase.verifyEqual(e.plate{1}, 'ecoli_plate0001');
            testCase.verifyEqual(e.local_start, datetime(2023, 12, 30, 9, 39, 0));
            testCase.verifySubstring(e.note{1}, 'background image 9');
            testCase.verifySubstring(e.note{1}, 'brightfield image 1');
        end

        function testSourceChecks(testCase)
            [~, checks] = testCase.list();
            testCase.verifyTrue(any(contains(checks.rowWithoutFile, '2022-02-04_14-16-36_1')));
            testCase.verifyTrue(any(contains(checks.fileWithoutRow, '2022-02-04_11-58-24_1.mp4')));
            testCase.verifyTrue(any(contains(checks.cameraDisagrees, '2022-02-04_15-17-10_2')));
            testCase.verifyTrue(any(contains(checks.noFrames, '2022-02-04_15-17-10_2')));
            testCase.verifyTrue(any(contains(checks.imagesWithoutFile, '2 of 4')));
            testCase.verifyTrue(any(contains(checks.imagesWithoutFile, '1 of them fluorescence')));
        end
    end

    methods
        function [R, checks] = list(testCase)
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            [R, checks] = ndi.setup.conv.haley.recordingList(testCase.Root, T);
        end
    end
end

function writeToc(folder, rows)
if ~isfolder(folder), mkdir(folder); end
[~, name] = fileparts(folder);
T = cell2table([repmat({name}, size(rows, 1), 1), rows], 'VariableNames', ...
    {'experimentName', 'experimentNumber', 'directoryName', 'notebookName', ...
     'wormNumber', 'conditions', 'include', 'notes'});
writetable(T, fullfile(folder, 'tableOfContents.xlsx'));
end

function writeInfo(folder, expNum, plateNum, videoNum, camera, video, lawn, t, nFrames, rate)
% The recording columns, plus the subject columns (subjectList needs them)
% filled with plain values: two worms per plate (plate*10 + 1, + 2), N2,
% picked the day before, one patch. Plate 14 is food-deprived: moved to an
% unseeded plate (`starvedTime`) 3 h before it was filmed. Plate 13 is
% excluded (the source's `exclude`). Stage 8's columns (hand-written, to the
% minute): seeded two days before filming at OD600 1, 0.5 uL, from a solution
% read at OD600 10.2 with CFU 500; to the cold room an hour later; to room
% temperature 67 min before filming -- plate 12 exactly 60 min before, the
% rule that marks an estimated time; its acclimation plate seeded 30 min after
% it, the same day, at growthOD600 1, cold room an hour later, room
% temperature an hour before the pick. Stage 9's probe readings, the same on
% every video of a plate: temp 21.5 + plate/100 C, humidity 40 + plate %RH.
% Stage 10 part A's columns, on 8x8 images rather than 1024x1024: 33 pixels per
% mm; an arena mask of the inner 6x6; a reference mark at (2,2) except on
% plate 14 (empty, as foragingMini's are); a lawn mask of the centre 2x2; every
% pixel's nearest patch is the plate's one patch; patches found by template;
% the lawn clip registered at 0.98 where the plate has one.
n = numel(expNum);
arena = false(8); arena(2:7, 2:7) = true;
ref = false(8); ref(2, 2) = true;
lawnMask = false(8); lawnMask(4:5, 4:5) = true;
refs = repmat({ref}, n, 1);
refs(plateNum(:) == 14) = {false(8)};
fit = NaN(n, 1);
fit(~cellfun(@isempty, lawn(:))) = 0.98;
minute = @(x) dateshift(x, 'start', 'minute');
seed = minute(t(:) - days(2));
roomTemp = minute(t(:) - minutes(67));
roomTemp(plateNum(:) == 12) = t(plateNum(:) == 12) - hours(1);
growthSeed = seed + minutes(30);
starved = NaT(n, 1);
starved(plateNum(:) == 14) = t(plateNum(:) == 14) - hours(3);
worms = arrayfun(@(p) double(p) * 10 + [1 2], plateNum(:), 'UniformOutput', false);
info = table(uint16(expNum(:)), uint16(plateNum(:)), uint16(videoNum(:)), double(camera(:)), ...
    video(:), lawn(:), t(:), double(nFrames(:)), double(rate(:)), ...
    worms, repmat({'N2'}, n, 1), t(:) - days(1), repmat({zeros(1, 2)}, n, 1), ...
    repmat({zeros(1, 1)}, n, 1), plateNum(:) == 13, starved, ...
    seed, seed + hours(1), roomTemp, ones(n, 1), 0.5 * ones(n, 1), 10.2 * ones(n, 1), ...
    500 * ones(n, 1), growthSeed, growthSeed + hours(1), minute(t(:) - days(1) - hours(1)), ...
    ones(n, 1), 21.5 + double(plateNum(:)) / 100, 40 + double(plateNum(:)), ...
    33 * ones(n, 1), 30 * ones(n, 1), 1.5 * ones(n, 1), 5 * ones(n, 1), ...
    repmat({arena}, n, 1), refs, repmat({lawnMask}, n, 1), repmat({ones(8)}, n, 1), ...
    repmat({{'template'}}, n, 1), fit, ...
    'VariableNames', {'expNum', 'plateNum', 'videoNum', 'camera', 'videoFileName', ...
    'lawnFileName', 'timeRecord', 'numFrames', 'frameRate', 'wormNum', 'strainID', ...
    'growthTimePicked', 'lawnCenters', 'lawnRadii', 'exclude', 'starvedTime', ...
    'timeSeed', 'timeColdRoom', 'timeRoomTemp', 'OD600', 'lawnVolume', 'OD600Real', ...
    'CFU', 'growthTimeSeed', 'growthTimeColdRoom', 'growthTimeRoomTemp', 'growthOD600', ...
    'temp', 'humidity', 'scale', 'arenaDiameter', 'lawnDiameter', 'lawnSpacing', ...
    'arenaMask', 'refMask', 'lawnMask', 'lawnClosest', 'lawnMethod', 'lawnRegistration'}); %#ok<NASGU>
save(fullfile(folder, 'experimentInfo.mat'), 'info');
end

function writeTracks(folder)
% Stage 10 part B's midpoint.mat: 5 frames for each worm of each filmed video
% (plate 11 videos 1 and 2, 12, 14; worms plate*10 + 1, + 2). Worm w is at
% x = frame + w/10, y = 4; speed w um/s; 2 pixels inside the patch edge; its
% nearest patch is patch 1, except frame 3 of worm 121, which the source
% marks noTrack (and reads its nearest patch at pixel (1,1)).
rows = {};
for pv = [11 1; 11 2; 12 1; 14 1]'
    for w = pv(1) * 10 + [1 2]
        f = (1:5)';
        noTrack = false(5, 1);
        if w == 121, noTrack(3) = true; end
        rows{end+1} = table(uint16(ones(5, 1)), uint16(pv(1) * ones(5, 1)), ...
            uint16(pv(2) * ones(5, 1)), w * ones(5, 1), f, f + w / 10, 4 * ones(5, 1), ...
            noTrack, w * ones(5, 1), 2 * ones(5, 1), ones(5, 1), ...
            'VariableNames', {'expNum', 'plateNum', 'videoNum', 'wormNum', 'frameNum', ...
            'xPosition', 'yPosition', 'noTrack', 'velocitySmooth', 'distanceLawnEdge', ...
            'closestLawnID'}); %#ok<AGROW>
    end
end
data = vertcat(rows{:}); %#ok<NASGU>
save(fullfile(folder, 'midpoint.mat'), 'data');
end

function writeEncounters(folder)
% Stage 11's encounter.mat: worm 121 (plate 12, one video) -- the gap before its
% first encounter (id 0), then encounters at rows 2-3 and 4-5 on patch 1;
% worm 111 (plate 11, two videos of 5 frames each, joined) -- one encounter at
% rows 7-9, frames 2-4 of the second video. Values: speeds w*1 um/s on, ...
n = 4;
name = repmat({'foragingConcentration'}, n, 1);
encounter = table(uint16(ones(n, 1)), uint16([12; 12; 12; 11]), [1; 1; 1; 2], ...
    [121; 121; 121; 111], [0; 1; 2; 1], [NaN; 2; 4; 7], [NaN; 3; 5; 9], ...
    [NaN; 1; 1; 1], [NaN; 10; 20; 30], [NaN; 5; 6; 7], [NaN; 0.1; 0.2; 0.3], ...
    [NaN; 100; 110; 120], [NaN; 8; 9; 10], [NaN; 1.5; 2.5; 3.5], [NaN; -40; -50; -60], ...
    [50; 60; NaN; NaN], [1.0; 1.1; NaN; NaN], name, [NaN; 0.9; 0.2; 0.7], [NaN; 0.8; 0.6; 0.01], ...
    {''; 'exploit'; 'sample'; 'exploit'}, ...
    'VariableNames', {'expNum', 'plateNum', 'videoNum', 'wormNum', 'id', 'enter', 'exit', ...
    'lawnID', 'velocityOn', 'velocityOnMin', 'distanceOnMax', 'velocityBeforeEnter', ...
    'velocityAfterEnter', 'timeSlowDown', 'decelerate', 'velocityOff', 'distanceOffMax', ...
    'expName', 'exploitPosterior', 'sensePosterior', 'label'}); %#ok<NASGU>
save(fullfile(folder, 'encounter.mat'), 'encounter');
end

function placeholder(file, n)
fid = fopen(file, 'w');
fwrite(fid, zeros(1, n, 'uint8'));
fclose(fid);
end
