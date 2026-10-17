classdef TestExternalToolCommands < matlab.unittest.TestCase
    % TestExternalToolCommands - avi2mp4 and prism2csv hand the right
    % arguments to ffmpeg and Rscript.
    %
    % Stand-in programs (POSIX shell scripts) record the arguments they
    % were given, one per line, so the test needs neither FFmpeg nor R.
    % Folder and file names contain spaces to check the quoting.

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.Root = fullfile(tempname, 'my data');
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(fileparts(testCase.Root), 's'));
        end
    end

    methods (Access = private)
        function f = fakeProgram(testCase, fileName, extraLines)
            % Records "$@" in args.txt next to itself, then runs extraLines.
            if nargin < 3
                extraLines = {};
            end
            f = fullfile(testCase.Root, fileName);
            lines = [{'#!/bin/sh', ...
                'printf ''%s\n'' "$@" > "$(dirname "$0")/args.txt"'}, extraLines];
            fid = fopen(f, 'w');
            testCase.assertGreaterThan(fid, 0);
            fprintf(fid, '%s', strjoin(lines, newline));
            fprintf(fid, '\n');
            fclose(fid);
            system(['chmod +x ''' f '''']);
        end

        function args = recordedArgs(testCase)
            args = splitlines(strtrim(string(fileread(fullfile(testCase.Root, 'args.txt')))));
            args = cellstr(args)';
        end
    end

    methods (Test)

        function testAvi2mp4PassesEachArgumentIntact(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in for ffmpeg.');
            % The stand-in creates its last argument, the output file.
            ffmpeg = testCase.fakeProgram('fake ffmpeg', ...
                {'for last; do :; done', ': > "$last"'});
            avi = fullfile(testCase.Root, 'trial 1.avi');
            fclose(fopen(avi, 'w'));

            ndi.fun.data.avi2mp4(avi, '', 'ffmpegPath', ffmpeg, ...
                'crf', 18, 'preset', 'slow');

            out = fullfile(testCase.Root, 'trial 1_compressed.mp4');
            testCase.verifyTrue(isfile(out), 'the output was not written');
            testCase.verifyEqual(testCase.recordedArgs(), ...
                {'-i', avi, '-vcodec', 'libx264', '-crf', '18', ...
                 '-preset', 'slow', '-y', out});
        end

        function testAvi2mp4WithoutOptionsKeepsFFmpegDefaults(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in for ffmpeg.');
            ffmpeg = testCase.fakeProgram('ffmpeg');
            avi = fullfile(testCase.Root, 'a.avi');
            fclose(fopen(avi, 'w'));
            ndi.fun.data.avi2mp4(avi, '', 'ffmpegPath', ffmpeg, 'Overwrite', false);
            testCase.verifyEqual(testCase.recordedArgs(), ...
                {'-i', avi, '-vcodec', 'libx264', '-n', ...
                 fullfile(testCase.Root, 'a_compressed.mp4')});
        end

        function testAvi2mp4RefusesAnUnknownPreset(testCase)
            % The preset reaches a shell; only ffmpeg's own names pass.
            avi = fullfile(testCase.Root, 'a.avi');
            fclose(fopen(avi, 'w'));
            testCase.verifyError(@() ndi.fun.data.avi2mp4(avi, '', ...
                'preset', 'slow; rm -rf ~'), 'MATLAB:validators:mustBeMember');
        end

        function testAvi2mp4RejectsAMissingFFmpeg(testCase)
            avi = fullfile(testCase.Root, 'a.avi');
            fclose(fopen(avi, 'w'));
            testCase.verifyError(@() ndi.fun.data.avi2mp4(avi, '', ...
                'ffmpegPath', fullfile(testCase.Root, 'no-ffmpeg')), ...
                'ndi:fun:findExecutable:badPath');
        end

        function testPrism2csvPassesEachArgumentIntact(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in for Rscript.');
            rscript = testCase.fakeProgram('fake Rscript');
            input = fullfile(testCase.Root, 'study one.prism');
            outDir = fullfile(testCase.Root, 'csv out');

            ndi.fun.data.prism2csv(input, outDir, 'RscriptPath', rscript, ...
                'Overwrite', false);

            args = testCase.recordedArgs();
            testCase.verifyNumElements(args, 4);
            [~, scriptName, ext] = fileparts(args{1});
            testCase.verifyEqual([scriptName ext], 'prism2csv.R');
            testCase.verifyEqual(args(2:4), {input, outDir, 'FALSE'});
        end

        function testPrism2csvWithoutOutputDirPassesNULL(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in for Rscript.');
            rscript = testCase.fakeProgram('Rscript');
            input = fullfile(testCase.Root, 'p.prism');
            ndi.fun.data.prism2csv(input, 'RscriptPath', rscript);
            args = testCase.recordedArgs();
            testCase.verifyEqual(args(2:4), {input, 'NULL', 'TRUE'});
        end
    end
end
