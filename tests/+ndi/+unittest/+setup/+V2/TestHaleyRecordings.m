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
            ce = fullfile(testCase.Root, 'haley', 'celegans');

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
            ec = fullfile(testCase.Root, 'haley', 'ecoli');
            mkdir(fullfile(ec, 'images'));
            placeholder(fullfile(ec, 'images', '0002.tiff'), 50);
            placeholder(fullfile(ec, 'images', '0003.tiff'), 60);
            info = table([1; 1], [1; 2], {'rectangle'; 'none'}, [1; 1], [0.5; 200], ...
                'VariableNames', {'expNum', 'plateNum', 'template', 'OD600', 'lawnVolume'}); %#ok<NASGU>
            metaData = table([1; 1; 1; 1], [1; 2; 3; 4], [1; 1; 2; 2], ...
                datetime(2023, 12, 30, 9, [38; 39; 40; 41], 0), ...
                {'a.tif'; 'b.tif'; 'c.tif'; 'd.tif'}, [0; 1; 1; 1], ...
                'VariableNames', {'expNum', 'imageNum', 'plateNum', 'acquisitionTime', ...
                'fileName', 'fluorescence'}); %#ok<NASGU>
            save(fullfile(ec, 'bacteria.mat'), 'info', 'metaData');
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
            testCase.verifyEqual(r.plate{1}, 'concentration_plate0012');
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
info = table(uint16(expNum(:)), uint16(plateNum(:)), uint16(videoNum(:)), double(camera(:)), ...
    video(:), lawn(:), t(:), double(nFrames(:)), double(rate(:)), ...
    'VariableNames', {'expNum', 'plateNum', 'videoNum', 'camera', 'videoFileName', ...
    'lawnFileName', 'timeRecord', 'numFrames', 'frameRate'}); %#ok<NASGU>
save(fullfile(folder, 'experimentInfo.mat'), 'info');
end

function placeholder(file, n)
fid = fopen(file, 'w');
fwrite(fid, zeros(1, n, 'uint8'));
fclose(fid);
end
