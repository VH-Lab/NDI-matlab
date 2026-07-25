classdef RecalculateMeanWaveformTest < matlab.unittest.TestCase
    % RECALCULATEMEANWAVEFORMTEST - Unit tests for recalculating mean spike
    % waveforms directly from the raw Kilosort binary.
    %
    % Covers:
    %   ndi.fun.probe.import.kilosort.recalculatemeanwaveform - reads a window
    %       around each spike from a synthetic int16 binary and averages them.
    %   ndi.fun.probe.import.kilosort.binaryinfo - locates the binary and its
    %       parameters from a '.metadata' sidecar or a Phy params.py file.

    properties
        workDir
        binFile
        numChannels = 3
        numSamples  = 100
        sampleRate  = 1000
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.workDir = tempname;
            mkdir(testCase.workDir);
            testCase.binFile = fullfile(testCase.workDir,'kilosort.bin');
            % value at (channel ch (1-based), sample s (0-based)) = ch*1000 + s.
            % This makes the expected window mean easy to reason about.
            A = zeros(testCase.numChannels, testCase.numSamples);
            for ch=1:testCase.numChannels,
                A(ch,:) = ch*1000 + (0:testCase.numSamples-1);
            end;
            ndi.unittest.fun.probe.import.kilosort.RecalculateMeanWaveformTest.writeBinary(...
                testCase.binFile, A);
        end
    end

    methods (TestMethodTeardown)
        function removeFixture(testCase)
            if exist(testCase.workDir,'dir'),
                rmdir(testCase.workDir,'s');
            end
        end
    end

    methods (Test)

        function testMeanAndTimebase(testCase)
            % spikes at samples 20 and 50 (0-based); window -5..+5 ms at 1 kHz
            spikes = [20 50];
            [meanWf, wst, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes, testCase.sampleRate, ...
                -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf);

            testCase.verifyEqual(nUsed, 2, 'Both spikes should contribute.');
            testCase.verifyEqual(size(meanWf), [11 testCase.numChannels], ...
                'Window should be 11 samples x num_channels.');

            % expected(k,ch) = ch*1000 + (k-1) + mean([20 50]) + off0
            % with off0 = -5, mean = 35  ->  ch*1000 + (k-1) + 30
            expected = zeros(11, testCase.numChannels);
            for ch=1:testCase.numChannels,
                expected(:,ch) = ch*1000 + (0:10)' + 30;
            end;
            testCase.verifyEqual(meanWf, expected, 'AbsTol', 1e-9, ...
                'Recalculated mean waveform is incorrect.');

            % time base: -5 ms .. +5 ms with 0 at the spike sample
            testCase.verifyEqual(numel(wst), 11, 'Time base length wrong.');
            testCase.verifyEqual(wst(1), -0.005, 'AbsTol', 1e-12);
            testCase.verifyEqual(wst(6),  0.000, 'AbsTol', 1e-12);
            testCase.verifyEqual(wst(11), 0.005, 'AbsTol', 1e-12);
        end

        function testMultiplierScaling(testCase)
            % physical = int16 / multiplier
            spikes = [20 50];
            m = 2;
            meanWf = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes, testCase.sampleRate, ...
                -0.005, 0.005, 'multiplier', m, 'maxSpikes', Inf);
            expected = zeros(11, testCase.numChannels);
            for ch=1:testCase.numChannels,
                expected(:,ch) = (ch*1000 + (0:10)' + 30)/m;
            end;
            testCase.verifyEqual(meanWf, expected, 'AbsTol', 1e-9, ...
                'Multiplier scaling to physical units is incorrect.');
        end

        function testEdgeSpikesSkipped(testCase)
            % spikes whose window runs off either end are skipped; the surviving
            % mean must equal the two in-range spikes only.
            spikes = [2 20 50 98]; % 2 -> window starts at -3 (invalid); 98 -> ends at 103 (invalid)
            [meanWf, ~, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes, testCase.sampleRate, ...
                -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf);
            testCase.verifyEqual(nUsed, 2, 'Only the two in-range spikes should be used.');
            expected = zeros(11, testCase.numChannels);
            for ch=1:testCase.numChannels,
                expected(:,ch) = ch*1000 + (0:10)' + 30;
            end;
            testCase.verifyEqual(meanWf, expected, 'AbsTol', 1e-9);
        end

        function testEpochSeamSpikesExcluded(testCase)
            % two epochs concatenated at sample 40: epoch 1 = 0..39, epoch 2 = 40..99.
            % A spike at 38 has window 33..43, which straddles the seam and must be
            % dropped when epoch bounds are supplied; 20 and 60 stay within an epoch.
            epochBounds = [0; 40; 100];
            spikes = [20 38 60];
            [meanWf, ~, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes, testCase.sampleRate, ...
                -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf, ...
                'epochBounds', epochBounds);
            testCase.verifyEqual(nUsed, 2, 'The seam-straddling spike should be dropped.');
            % expected mean of windows at 20 and 60: ch*1000 + (k-1) + mean([20 60]) + off0
            % = ch*1000 + (k-1) + 40 - 5 = ch*1000 + (k-1) + 35
            expected = zeros(11, testCase.numChannels);
            for ch=1:testCase.numChannels,
                expected(:,ch) = ch*1000 + (0:10)' + 35;
            end;
            testCase.verifyEqual(meanWf, expected, 'AbsTol', 1e-9);
        end

        function testWithoutEpochBoundsSeamSpikeKept(testCase)
            % same spikes, but with no epoch bounds only the file ends constrain,
            % so the sample-38 spike (window well inside the file) is kept.
            spikes = [20 38 60];
            [~, ~, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes, testCase.sampleRate, ...
                -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf);
            testCase.verifyEqual(nUsed, 3, 'Without epoch bounds all three spikes are in range.');
        end

        function testEmptySpikesReturnsZeros(testCase)
            [meanWf, wst, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, [], testCase.sampleRate, ...
                -0.005, 0.005);
            testCase.verifyEqual(nUsed, 0);
            testCase.verifyEqual(meanWf, zeros(11, testCase.numChannels));
            testCase.verifyEqual(numel(wst), 11);
        end

        function testBadWindowErrors(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, [20 50], testCase.sampleRate, ...
                0.005, -0.005), ...
                'ndi:fun:probe:import:kilosort:recalculatemeanwaveform:badWindow');
        end

        function testBinaryInfoFromMetadata(testCase)
            % NDI-style layout: binary + '.metadata' sidecar in the parent, curated
            % files in a 'kilosort_output' subdir.
            kdir = fullfile(testCase.workDir,'kilosort_output');
            mkdir(kdir);
            meta = struct('epoch_sample_counts', testCase.numSamples, ...
                'epoch_sample_rates', testCase.sampleRate, ...
                'multiplier', 1/0.195, 'num_channels', testCase.numChannels, ...
                'probe_name', 'mock_probe');
            vlt.file.saveStructArray([testCase.binFile '.metadata'], meta);

            info = ndi.fun.probe.import.kilosort.binaryinfo(kdir);
            testCase.verifyTrue(info.found, 'Binary should be located from the sidecar.');
            testCase.verifyEqual(info.file, testCase.binFile, 'Wrong binary file.');
            testCase.verifyEqual(info.num_channels, testCase.numChannels);
            testCase.verifyEqual(info.multiplier, 1/0.195, 'AbsTol', 1e-12);
            testCase.verifyEqual(info.sample_rate, testCase.sampleRate, 'AbsTol', 1e-9);
        end

        function testBinaryInfoFromParamsPy(testCase)
            % Phy-style layout: params.py next to the binary, no sidecar.
            kdir = fullfile(testCase.workDir,'phy');
            mkdir(kdir);
            binp = fullfile(kdir,'recording.dat');
            copyfile(testCase.binFile, binp);
            fid = fopen(fullfile(kdir,'params.py'),'w');
            fprintf(fid,'dat_path = r"recording.dat"\n');
            fprintf(fid,'n_channels_dat = %d\n', testCase.numChannels);
            fprintf(fid,"dtype = 'int16'\n");
            fprintf(fid,'offset = 0\n');
            fprintf(fid,'sample_rate = %g\n', testCase.sampleRate);
            fprintf(fid,'hp_filtered = False\n');
            fclose(fid);

            info = ndi.fun.probe.import.kilosort.binaryinfo(kdir);
            testCase.verifyTrue(info.found, 'Binary should be located from params.py.');
            testCase.verifyEqual(info.file, binp, 'Wrong binary file from dat_path.');
            testCase.verifyEqual(info.num_channels, testCase.numChannels);
            testCase.verifyEqual(info.dtype, 'int16');
            testCase.verifyEqual(info.sample_rate, testCase.sampleRate, 'AbsTol', 1e-9);
        end

        function testBinaryInfoNotFound(testCase)
            kdir = fullfile(testCase.workDir,'empty');
            mkdir(kdir);
            info = ndi.fun.probe.import.kilosort.binaryinfo(kdir);
            testCase.verifyFalse(info.found, 'Nothing should be found in an empty directory.');
        end

    end

    methods (Static)
        function writeBinary(fname, A)
            % write A (num_channels x num_samples) as little-endian int16,
            % channel-interleaved per sample (Kilosort/Phy convention).
            fid = fopen(fname,'w','ieee-le');
            fwrite(fid, A, 'int16'); % column-major -> [ch1..chN] per sample
            fclose(fid);
        end
    end
end
