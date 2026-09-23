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

        function testBinaryInfoParamsPyParsedButNotLocated(testCase)
            % Phy-style layout: params.py next to the binary, no sidecar. binaryinfo
            % PARSES the acquisition parameters but must NOT open the binary via
            % dat_path (which frequently names a whitened/filtered temp file).
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
            testCase.verifyFalse(info.found, ...
                'binaryinfo must not locate a binary from params.py dat_path.');
            testCase.verifyEqual(info.file, '', 'No binary file should be resolved.');
            testCase.verifyEqual(info.num_channels, testCase.numChannels, ...
                'n_channels_dat should still be parsed.');
            testCase.verifyEqual(info.dtype, 'int16');
            testCase.verifyEqual(info.sample_rate, testCase.sampleRate, 'AbsTol', 1e-9);
            testCase.verifyEqual(info.dat_path, 'recording.dat', ...
                'dat_path string should be kept for reporting.');
        end

        function testNeuropixelsMultiplier(testCase)
            % NP1/NP2 encode multipliers and aliases.
            np1 = (512*500)/0.6;
            np2 = (8192*80)/0.5;
            testCase.verifyEqual(ndi.fun.probe.import.kilosort.neuropixelsmultiplier('NP1'), ...
                np1, 'AbsTol', 1e-6);
            testCase.verifyEqual(ndi.fun.probe.import.kilosort.neuropixelsmultiplier('NP2'), ...
                np2, 'AbsTol', 1e-6);
            testCase.verifyEqual(ndi.fun.probe.import.kilosort.neuropixelsmultiplier('Neuropixels 1.0'), ...
                np1, 'AbsTol', 1e-6);
            testCase.verifyEqual(ndi.fun.probe.import.kilosort.neuropixelsmultiplier('np2.0'), ...
                np2, 'AbsTol', 1e-6);
            [~, info] = ndi.fun.probe.import.kilosort.neuropixelsmultiplier('NP1');
            testCase.verifyEqual(info.name, 'NP1');
            testCase.verifyEqual(info.uV_per_bit, 1e6*0.6/(512*500), 'AbsTol', 1e-6);
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.neuropixelsmultiplier('NP3'), ...
                'ndi:fun:probe:import:kilosort:neuropixelsmultiplier:badType');
        end

        function testPromptRawBinaryHeadless(testCase)
            % headless resolution: RawFile + ProbeType + RawNumChannels supplied (no
            % dialogs). The channel count is the stride of the SELECTED raw file and
            % is NOT taken from params.py n_channels_dat (that describes the missing
            % sorted file); it must come from an override or a SpikeGLX .meta sidecar.
            kdir = fullfile(testCase.workDir,'phy2');
            mkdir(kdir);
            fid = fopen(fullfile(kdir,'params.py'),'w');
            fprintf(fid,'n_channels_dat = %d\n', testCase.numChannels);
            fprintf(fid,"dtype = 'int16'\n");
            fprintf(fid,'offset = 0\n');
            fprintf(fid,'sample_rate = %g\n', testCase.sampleRate);
            fclose(fid);
            baseinfo = ndi.fun.probe.import.kilosort.binaryinfo(kdir);
            testCase.verifyFalse(baseinfo.found);

            % n_channels_dat alone must NOT satisfy the stride: headless with no
            % override and no .meta sidecar must error rather than reuse it.
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.promptrawbinary(baseinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false), ...
                'ndi:fun:probe:import:kilosort:promptrawbinary:noChannelCount');

            % with an explicit RawNumChannels override it resolves.
            info = ndi.fun.probe.import.kilosort.promptrawbinary(baseinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false, ...
                'num_channels', testCase.numChannels);
            testCase.verifyTrue(info.found);
            testCase.verifyEqual(info.file, testCase.binFile);
            testCase.verifyEqual(info.num_channels, testCase.numChannels);
            testCase.verifyEqual(info.multiplier, (512*500)/0.6, 'AbsTol', 1e-6);
            testCase.verifyEqual(info.probe_type, 'NP1');

            info2 = ndi.fun.probe.import.kilosort.promptrawbinary(baseinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP2', 'PromptForRawFile', false, ...
                'num_channels', testCase.numChannels);
            testCase.verifyEqual(info2.multiplier, (8192*80)/0.5, 'AbsTol', 1e-6);

            % headless mode with no ProbeType must error rather than block on a dialog
            % (the probe generation is resolved before the channel count).
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.promptrawbinary(baseinfo, ...
                'RawFile', testCase.binFile, 'PromptForRawFile', false, ...
                'num_channels', testCase.numChannels), ...
                'ndi:fun:probe:import:kilosort:promptrawbinary:noProbeType');

            % a missing RawFile path errors
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.promptrawbinary(baseinfo, ...
                'RawFile', fullfile(testCase.workDir,'does_not_exist.bin'), ...
                'ProbeType', 'NP1', 'PromptForRawFile', false), ...
                'ndi:fun:probe:import:kilosort:promptrawbinary:noFile');
        end

        function testPromptRawBinaryChannelCount(testCase)
            % when no override and no .meta sidecar give a channel count, it must be
            % supplied explicitly; otherwise headless resolution errors.
            nochan = fullfile(testCase.workDir,'nochan');
            mkdir(nochan);
            emptyinfo = ndi.fun.probe.import.kilosort.binaryinfo(nochan);
            testCase.verifyTrue(isnan(emptyinfo.num_channels), ...
                'Fixture dir has no channel-count source.');

            testCase.verifyError(@() ndi.fun.probe.import.kilosort.promptrawbinary(emptyinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false), ...
                'ndi:fun:probe:import:kilosort:promptrawbinary:noChannelCount');

            info = ndi.fun.probe.import.kilosort.promptrawbinary(emptyinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false, ...
                'num_channels', testCase.numChannels);
            testCase.verifyTrue(info.found);
            testCase.verifyEqual(info.num_channels, testCase.numChannels);
        end

        function testReadSpikeGLXMeta(testCase)
            % the SpikeGLX '.meta' reader: parses key=value, numeric where possible,
            % strips the '~' prefix on multi-valued keys, and returns [] when absent.
            bf = fullfile(testCase.workDir,'run_g0_t0.imec0.ap.bin');
            ndi.unittest.fun.probe.import.kilosort.RecalculateMeanWaveformTest.writeBinary(...
                bf, zeros(385, 10)); % shape only; contents irrelevant here
            mf = fullfile(testCase.workDir,'run_g0_t0.imec0.ap.meta');
            fid = fopen(mf,'w');
            fprintf(fid,'nSavedChans=385\n');
            fprintf(fid,'imSampRate=30000.5\n');
            fprintf(fid,'fileName=D:\\data\\run_g0_t0.imec0.ap.bin\n');
            fprintf(fid,'~snsChanMap=(384,384,1)(AP0;0:0)\n');
            fclose(fid);

            [meta, metafile] = ndi.fun.probe.import.kilosort.readspikeglxmeta(bf);
            testCase.verifyEqual(metafile, mf, 'Should find the sibling .meta file.');
            testCase.verifyEqual(meta.nSavedChans, 385, ...
                'nSavedChans should be parsed as a number.');
            testCase.verifyEqual(meta.imSampRate, 30000.5, 'AbsTol', 1e-9);
            testCase.verifyEqual(meta.fileName, 'D:\data\run_g0_t0.imec0.ap.bin', ...
                'Non-numeric values should be kept as char.');
            testCase.verifyTrue(isfield(meta,'snsChanMap'), ...
                'The ~ prefix should be stripped to a valid field name.');

            % no sidecar -> empty
            [meta2, metafile2] = ndi.fun.probe.import.kilosort.readspikeglxmeta(...
                testCase.binFile);
            testCase.verifyEmpty(meta2);
            testCase.verifyEqual(metafile2, '');
        end

        function testPromptRawBinaryUsesMetaChannelCount(testCase)
            % with no override, the read stride comes from the SpikeGLX .meta sidecar.
            nc = 5; nS = 40;
            A = zeros(nc, nS);
            for ch=1:nc, A(ch,:) = ch*100 + (0:nS-1); end;
            bf = fullfile(testCase.workDir,'meta_case.imec0.ap.bin');
            ndi.unittest.fun.probe.import.kilosort.RecalculateMeanWaveformTest.writeBinary(bf, A);
            mf = fullfile(testCase.workDir,'meta_case.imec0.ap.meta');
            fid = fopen(mf,'w'); fprintf(fid,'nSavedChans=%d\n', nc); fclose(fid);

            emptyinfo = ndi.fun.probe.import.kilosort.binaryinfo(...
                fullfile(testCase.workDir,'nochan2'));
            info = ndi.fun.probe.import.kilosort.promptrawbinary(emptyinfo, ...
                'RawFile', bf, 'ProbeType', 'NP1', 'PromptForRawFile', false, ...
                'expectedSamples', nS);
            testCase.verifyTrue(info.found);
            testCase.verifyEqual(info.num_channels, nc, ...
                'Channel count should come from the .meta nSavedChans.');
        end

        function testPromptRawBinaryStrideGuards(testCase)
            % a wrong channel count must be a hard error, not silent noise. The
            % fixture binFile is 3 ch x 100 samples of int16 (600 bytes).
            emptyinfo = ndi.fun.probe.import.kilosort.binaryinfo(...
                fullfile(testCase.workDir,'nochan3'));

            % (a) non-divisible stride: 600 bytes is not a multiple of 7 ch x 2 bytes
            % (600 = 14*42 + 12), so reading as 7 channels cannot be a whole recording.
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.promptrawbinary(emptyinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false, ...
                'num_channels', 7), ...
                'ndi:fun:probe:import:kilosort:promptrawbinary:strideMismatch');

            % (b) divisible but wrong count vs expectedSamples: reading 3-ch data as
            % 2 ch divides evenly (600/4 = 150) but implies 150 samples, not 100.
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.promptrawbinary(emptyinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false, ...
                'num_channels', 2, 'expectedSamples', testCase.numSamples), ...
                'ndi:fun:probe:import:kilosort:promptrawbinary:durationMismatch');

            % (c) the correct count passes the guards.
            info = ndi.fun.probe.import.kilosort.promptrawbinary(emptyinfo, ...
                'RawFile', testCase.binFile, 'ProbeType', 'NP1', 'PromptForRawFile', false, ...
                'num_channels', testCase.numChannels, 'expectedSamples', testCase.numSamples);
            testCase.verifyTrue(info.found);
            testCase.verifyEqual(info.num_channels, testCase.numChannels);
        end

        function testHighPassFilterApplied(testCase)
            % Verify the high-pass path matches an independent filtfilt reference and
            % removes the DC/slow-drift baseline. Skipped without the Signal Toolbox.
            haveSPT = (logical(exist('cheby1','file')) || logical(exist('cheby1','builtin'))) && ...
                (logical(exist('filtfilt','file')) || logical(exist('filtfilt','builtin')));
            testCase.assumeTrue(haveSPT, ...
                'Signal Processing Toolbox (cheby1/filtfilt) not available; skipping.');

            nCh = 2; nS = 4000; fs = 30000;
            tt = 0:nS-1;
            A = zeros(nCh, nS);
            for ch=1:nCh,
                % DC offset + slow drift (removed by high-pass) + a 1 kHz tone (kept)
                A(ch,:) = ch*500 + 0.01*tt + 50*sin(2*pi*1000*tt/fs);
            end;
            Aint = double(int16(round(A))); % values as they are stored/read back
            bf = fullfile(testCase.workDir,'hp.bin');
            ndi.unittest.fun.probe.import.kilosort.RecalculateMeanWaveformTest.writeBinary(...
                bf, int16(round(A)));

            spikes = [1000 2000 3000];
            t0 = -0.005; t1 = 0.005; order = 4; ripple = 0.8; cutoff = 300;

            meanWf = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                bf, nCh, spikes, fs, t0, t1, 'multiplier', 1, 'maxSpikes', Inf, ...
                'highpass', true, 'hp_cutoff', cutoff, 'hp_order', order, 'hp_ripple', ripple);

            % independent reference: read padded windows, filtfilt, trim, average
            off0 = round(t0*fs); off1 = round(t1*fs); nWin = off1-off0+1;
            pad = max(ceil(3*fs/cutoff), 3*(order+1));
            [b,a] = cheby1(order, ripple, cutoff/(fs/2), 'high');
            acc = zeros(nWin, nCh);
            for s = spikes,
                r0 = s + off0 - pad; r1 = s + off1 + pad; % 0-based sample indices
                seg = Aint(:, (r0+1):(r1+1)).'; % (nRead x nCh)
                segf = filtfilt(b, a, seg);
                acc = acc + segf(pad+1:pad+nWin, :);
            end;
            refWf = acc / numel(spikes);

            testCase.verifyEqual(meanWf, refWf, 'AbsTol', 1e-6, ...
                'High-pass filtered mean waveform does not match the reference.');
            % DC offsets of 500 and 1000 must be gone; a small margin avoids flakiness
            % from the residual of the (kept) 1 kHz tone averaged over the window.
            testCase.verifyLessThan(max(abs(mean(meanWf,1))), 5, ...
                'High-pass should remove the DC/slow-drift baseline (near-zero channel means).');
        end

        function testHighPassBadCutoffWarnsAndPassesThrough(testCase)
            % a cutoff at/above Nyquist cannot be realized: warn and leave unfiltered,
            % so the result equals the plain (unfiltered) average.
            spikes = [20 50];
            warnID = 'ndi:fun:probe:import:kilosort:recalculatemeanwaveform:badCutoff';
            meanWf = testCase.verifyWarning(@() ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes, testCase.sampleRate, ...
                -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf, ...
                'highpass', true, 'hp_cutoff', testCase.sampleRate), warnID);
            expected = zeros(11, testCase.numChannels);
            for ch=1:testCase.numChannels,
                expected(:,ch) = ch*1000 + (0:10)' + 30;
            end;
            testCase.verifyEqual(meanWf, expected, 'AbsTol', 1e-9, ...
                'When the cutoff is invalid the data must be left unfiltered.');
        end

        function testBinaryInfoNotFound(testCase)
            kdir = fullfile(testCase.workDir,'empty');
            mkdir(kdir);
            info = ndi.fun.probe.import.kilosort.binaryinfo(kdir);
            testCase.verifyFalse(info.found, 'Nothing should be found in an empty directory.');
        end

        function testStreamingMatchesPerClusterNoFilter(testCase)
            % the single-pass, many-cluster function must return, for each cluster,
            % exactly what the per-cluster function returns (same selection, same mean).
            spikes   = [20 50 30 60 80];
            clusters = [ 1  1  2  2  2];
            cids     = [1 2];
            [mw, wst, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                testCase.binFile, testCase.numChannels, spikes, clusters, cids, ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf);

            testCase.verifyEqual(numel(mw), 2, 'One mean per cluster id.');
            testCase.verifyEqual(nUsed, [2;3], 'Per-cluster spike counts.');
            testCase.verifyEqual(numel(wst), 11);

            mw1 = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes(clusters==1), ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf);
            mw2 = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes(clusters==2), ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf);
            testCase.verifyEqual(mw{1}, mw1, 'AbsTol', 1e-9, 'Cluster 1 mismatch.');
            testCase.verifyEqual(mw{2}, mw2, 'AbsTol', 1e-9, 'Cluster 2 mismatch.');
        end

        function testStreamingChunkInvarianceNoFilter(testCase)
            % the result must not depend on chunkSamples: a tiny chunk (one spike per
            % chunk, many file seeks) and a huge chunk (all spikes in one block) agree.
            spikes   = [20 50 30 60 78];
            clusters = [ 1  2  1  2  1];
            cids     = [1 2];
            args = {testCase.binFile, testCase.numChannels, spikes, clusters, cids, ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf};
            small = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(args{:}, 'chunkSamples', 3);
            big   = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(args{:}, 'chunkSamples', 1e6);
            testCase.verifyEqual(small{1}, big{1}, 'AbsTol', 1e-9);
            testCase.verifyEqual(small{2}, big{2}, 'AbsTol', 1e-9);
        end

        function testStreamingMemoryBudgetSizing(testCase)
            % the memory-budget path (maxChunkBytes, chunkSamples auto) must produce
            % the same result as an explicit chunk size, and a tiny budget (forced to
            % the internal floor, hence several chunks) must still be correct.
            spikes   = [20 50 30 60 78];
            clusters = [ 1  2  1  2  1];
            cids     = [1 2];
            args = {testCase.binFile, testCase.numChannels, spikes, clusters, cids, ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf};
            ref  = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(args{:}, 'chunkSamples', 1e6);
            auto = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(args{:}); % default budget
            tight = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(args{:}, 'maxChunkBytes', 1);
            testCase.verifyEqual(auto{1}, ref{1}, 'AbsTol', 1e-9);
            testCase.verifyEqual(auto{2}, ref{2}, 'AbsTol', 1e-9);
            testCase.verifyEqual(tight{1}, ref{1}, 'AbsTol', 1e-9, ...
                'A tiny memory budget must still give the correct mean.');
            testCase.verifyEqual(tight{2}, ref{2}, 'AbsTol', 1e-9);
        end

        function testStreamingRespectsMaxSpikesAndEpochBounds(testCase)
            % maxSpikes cap and epoch-seam exclusion must match the per-cluster function.
            spikes   = [20 38 60 25 55];
            clusters = [ 1  1  1  2  2];
            cids     = [1 2];
            epochBounds = [0; 40; 100]; % spike 38 straddles the seam -> dropped
            [mw, ~, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                testCase.binFile, testCase.numChannels, spikes, clusters, cids, ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf, ...
                'epochBounds', epochBounds);
            testCase.verifyEqual(nUsed, [2;2], 'Seam-straddling spike 38 should be dropped.');

            mw1 = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                testCase.binFile, testCase.numChannels, spikes(clusters==1), ...
                testCase.sampleRate, -0.005, 0.005, 'multiplier', 1, 'maxSpikes', Inf, ...
                'epochBounds', epochBounds);
            testCase.verifyEqual(mw{1}, mw1, 'AbsTol', 1e-9);
        end

        function testStreamingHighPassMatchesPerCluster(testCase)
            % with high-pass on and a tiny chunk (one spike per chunk), each chunk is
            % filtered over the same padded window the per-cluster function uses, so
            % the streaming result must match it. Skipped without the Signal Toolbox.
            haveSPT = (logical(exist('cheby1','file')) || logical(exist('cheby1','builtin'))) && ...
                (logical(exist('filtfilt','file')) || logical(exist('filtfilt','builtin')));
            testCase.assumeTrue(haveSPT, 'Signal Processing Toolbox not available; skipping.');

            nCh = 2; nS = 8000; fs = 30000;
            tt = 0:nS-1;
            A = zeros(nCh, nS);
            for ch=1:nCh,
                A(ch,:) = ch*500 + 0.01*tt + 50*sin(2*pi*1000*tt/fs);
            end;
            bf = fullfile(testCase.workDir,'hp_stream.bin');
            ndi.unittest.fun.probe.import.kilosort.RecalculateMeanWaveformTest.writeBinary(...
                bf, int16(round(A)));

            spikes   = [1000 3000 5000 7000];
            clusters = [   1    2    1    2];
            cids     = [1 2];
            hp = {'highpass', true, 'hp_cutoff', 300, 'hp_order', 4, 'hp_ripple', 0.8};

            % tiny chunk -> one spike per chunk (spikes are 2000 samples apart)
            mw = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                bf, nCh, spikes, clusters, cids, fs, -0.005, 0.005, ...
                'multiplier', 1, 'maxSpikes', Inf, 'chunkSamples', 5, hp{:});

            mw1 = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                bf, nCh, spikes(clusters==1), fs, -0.005, 0.005, ...
                'multiplier', 1, 'maxSpikes', Inf, hp{:});
            mw2 = ndi.fun.probe.import.kilosort.recalculatemeanwaveform(...
                bf, nCh, spikes(clusters==2), fs, -0.005, 0.005, ...
                'multiplier', 1, 'maxSpikes', Inf, hp{:});
            testCase.verifyEqual(mw{1}, mw1, 'AbsTol', 1e-6, 'HP cluster 1 mismatch.');
            testCase.verifyEqual(mw{2}, mw2, 'AbsTol', 1e-6, 'HP cluster 2 mismatch.');

            % a big chunk filters both spikes' region together; the DC baseline must
            % still be removed (near-zero channel means).
            mwbig = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                bf, nCh, spikes, clusters, cids, fs, -0.005, 0.005, ...
                'multiplier', 1, 'maxSpikes', Inf, 'chunkSamples', 1e6, hp{:});
            testCase.verifyLessThan(max(abs(mean(mwbig{1},1))), 5, ...
                'High-pass should remove the DC baseline in the streaming result.');
        end

        function testStreamingProgressCallback(testCase)
            % the progressfcn is called with non-decreasing fractions in [0,1], ending
            % at exactly 1; a tiny chunk forces several callbacks. The nested function
            % 'record' accumulates the fractions in this method's workspace.
            fracs = [];
            spikes   = [20 30 50 60 78];
            clusters = [ 1  1  2  2  2];
            ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                testCase.binFile, testCase.numChannels, spikes, clusters, [1 2], ...
                testCase.sampleRate, -0.005, 0.005, 'maxSpikes', Inf, ...
                'chunkSamples', 3, 'progressfcn', @record);

            testCase.verifyNotEmpty(fracs, 'progressfcn should be called.');
            testCase.verifyGreaterThanOrEqual(min(fracs), 0);
            testCase.verifyLessThanOrEqual(max(fracs), 1);
            testCase.verifyTrue(all(diff(fracs) >= -1e-12), 'Fractions must be non-decreasing.');
            testCase.verifyEqual(fracs(end), 1, 'AbsTol', 1e-12, 'Should end at 100%.');

            function record(f, ~)
                fracs(end+1) = f; %#ok<AGROW>
            end
        end

        function testStreamingEmptyAndMissingCluster(testCase)
            % no spikes -> zeros for every requested cluster; a requested cluster id
            % that has no spikes -> zeros with nUsed 0.
            [mw, wst, nUsed] = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                testCase.binFile, testCase.numChannels, [], [], [1 2], ...
                testCase.sampleRate, -0.005, 0.005);
            testCase.verifyEqual(nUsed, [0;0]);
            testCase.verifyEqual(mw{1}, zeros(11, testCase.numChannels));
            testCase.verifyEqual(numel(wst), 11);

            % cluster 3 requested but has no spikes -> zeros, nUsed 0
            spikes = [20 50]; clusters = [1 1];
            [mw2, ~, nUsed2] = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                testCase.binFile, testCase.numChannels, spikes, clusters, [1 3], ...
                testCase.sampleRate, -0.005, 0.005, 'maxSpikes', Inf);
            testCase.verifyEqual(nUsed2, [2;0]);
            testCase.verifyEqual(mw2{2}, zeros(11, testCase.numChannels));
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
