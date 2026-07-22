function gmcSorterWrite(outputFolder, samples, timestamps, channelPositions, options)
% NDI.FUN.EXPORT.GMCSORTERWRITE - write in-memory voltage to GMC_Sorter's 'dat_t_s' raw format
%
% NDI.FUN.EXPORT.GMCSORTERWRITE(OUTPUTFOLDER, SAMPLES, TIMESTAMPS, CHANNELPOSITIONS, ...)
%
% Writes a recording held in memory to the raw file format that GMC_Sorter
% (https://github.com/stevevanhooser/GMC_Sorter) reads as file_struct
% 'dat_t_s'. This is the pure, session-free core used by
% NDI.FUN.EXPORT.GMCSORTER; it takes plain arrays so it can be unit-tested
% without an NDI session or DAQ (see gmcSorterWriteTest).
%
% INPUTS
% --------------------------------------------------------------------------
% | SAMPLES           | n_channels x n_samples voltage. Written as int16.   |
% |                   |   Column j (all channels of sample j) is written    |
% |                   |   contiguously, so on disk the layout is            |
% |                   |   [ch0_s0, ch1_s0, ..., chN_s0, ch0_s1, ...] -- the |
% |                   |   exact interleaving raw_data.py reshapes as        |
% |                   |   (n_time_samples, n_saved_chans).                  |
% | TIMESTAMPS        | 1 x n_samples sample times in SECONDS. Written as    |
% |                   |   int64 MICROSECONDS (round(t*1e6)). Must be         |
% |                   |   monotonically increasing (raw_data.py binary-     |
% |                   |   searches them).                                   |
% | CHANNELPOSITIONS  | n_channels x 2 array of [x y] electrode positions   |
% |                   |   (microns), in the same channel order as SAMPLES.  |
% --------------------------------------------------------------------------
%
% The two '.dat' files are written little-endian (matching raw_data.py's
% native-endian numpy reads on x86). GMC_Sorter derives from their sizes:
%   n_time_samples = sizeof(timestamps)/8 (int64)
%   n_saved_chans  = sizeof(samples)/(n_time_samples*2) (int16)
%   sample_rate    = 1e6 / median(diff(first 1000 timestamps))
% so the two files must agree on n_samples and n_channels.
%
% Files written into OUTPUTFOLDER:
%   [baseName]_samples.dat       int16, channel-interleaved (see above)
%   [baseName]_timestamps.dat    int64, microseconds
%   channel_positions.csv, channel_map.mat, [baseName].metadata,
%   run_gmc_extract.py           (via ndi.fun.export.writeGmcSidecars)
%
% Name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default)   | Description                                     |
% |-----------------------|-------------------------------------------------|
% | baseName ('RawData')  | Base name for the '.dat' pair and metadata.     |
% | multiplier (1)        | Encode multiplier: int16 = round(multiplier *   |
% |                       |   SAMPLES). Use to scale physical units into a  |
% |                       |   sensible int16 range without clipping (cf.    |
% |                       |   ndi.fun.probe.export.autoMultiplier). Values  |
% |                       |   are saturated to [-32768, 32767].             |
% | sampleRate ([])       | Representative sample rate (Hz) for metadata /  |
% |                       |   driver. If empty, inferred from TIMESTAMPS.   |
% | probeName ('')        | Probe elementstring recorded in the metadata.   |
% | writeSidecars (true)  | Write channel map / metadata / driver too.      |
% | gmcSorterPath ('')    | Path to the GMC_Sorter checkout for the driver. |
% | verbose (1)           | 0/1 Should we be verbose?                       |
% --------------------------------------------------------------------------
%
% Example:
%   fs = 30000; t = (0:2999)/fs;                 % 3000 samples, 100 ms
%   x = int16(1000*randn(4,3000));               % 4 channels
%   pos = [0 0; 0 25; 0 50; 0 75];               % linear, 25 um spacing
%   ndi.fun.export.gmcSorterWrite('/tmp/rec', x, t, pos, 'baseName','RawData');
%
% See also: NDI.FUN.EXPORT.GMCSORTER, NDI.FUN.EXPORT.WRITEGMCSIDECARS,
%   NDI.FUN.PROBE.EXPORT.BINARY

    arguments
        outputFolder (1,:) char
        samples double
        timestamps (1,:) double
        channelPositions (:,2) double
        options.baseName (1,:) char = 'RawData'
        options.multiplier (1,1) double = 1
        options.sampleRate double = []
        options.probeName (1,:) char = ''
        options.writeSidecars (1,1) logical = true
        options.gmcSorterPath (1,:) char = ''
        options.verbose (1,1) double = 1
    end

    nChannels = size(samples,1);
    nSamples  = size(samples,2);

    if numel(timestamps) ~= nSamples
        error('ndi:fun:export:gmcSorterWrite:size', ...
            ['TIMESTAMPS has %d elements but SAMPLES has %d columns; they must ' ...
             'have one timestamp per sample.'], numel(timestamps), nSamples);
    end
    if size(channelPositions,1) ~= nChannels
        error('ndi:fun:export:gmcSorterWrite:channels', ...
            ['CHANNELPOSITIONS has %d rows but SAMPLES has %d channels (rows); ' ...
             'they must match.'], size(channelPositions,1), nChannels);
    end
    if nSamples>1 && any(diff(timestamps)<=0)
        error('ndi:fun:export:gmcSorterWrite:monotonic', ...
            ['TIMESTAMPS must be strictly increasing (GMC_Sorter binary-searches ' ...
             'them); found a non-increasing step.']);
    end

    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    % --- samples file : int16, channel-interleaved ------------------------
    samplesFile = fullfile(outputFolder, [options.baseName '_samples.dat']);
    fid = fopen(samplesFile,'w','ieee-le');
    if fid<0
        error('ndi:fun:export:gmcSorterWrite:open', ...
            'Unable to open %s for writing.', samplesFile);
    end
    % fwrite is column-major: writing SAMPLES (n_channels x n_samples) emits
    % column 1 (all channels of sample 0) first, giving the interleaving above.
    local_write_samples(fid, samples, options.multiplier);
    fclose(fid);

    % --- timestamps file : int64 microseconds -----------------------------
    tsFile = fullfile(outputFolder, [options.baseName '_timestamps.dat']);
    fid = fopen(tsFile,'w','ieee-le');
    if fid<0
        error('ndi:fun:export:gmcSorterWrite:open', ...
            'Unable to open %s for writing.', tsFile);
    end
    local_write_timestamps(fid, timestamps);
    fclose(fid);

    if options.verbose
        fprintf('Wrote %d channels x %d samples to %s (dat_t_s).\n', ...
            nChannels, nSamples, outputFolder);
    end

    % --- companion files --------------------------------------------------
    if options.writeSidecars
        sr = options.sampleRate;
        if isempty(sr) && nSamples>1
            sr = 1e6 / median(diff(timestamps)*1e6); % = 1/median(diff(t))
        end
        ndi.fun.export.writeGmcSidecars(outputFolder, options.baseName, channelPositions, ...
            'epochSampleCounts', nSamples, 'epochSampleRates', sr, 'sampleRate', sr, ...
            'multiplier', options.multiplier, 'probeName', options.probeName, ...
            'gmcSorterPath', options.gmcSorterPath, 'verbose', options.verbose);
    end
end % gmcSorterWrite

% =========================================================================
% Low-level byte writers. GMCSORTER streams large recordings chunk-by-chunk
% with these SAME two calls, so the on-disk layout is defined in one place.
% =========================================================================
function local_write_samples(fid, data, multiplier)
    % data: n_channels x n_samples (one chunk or the whole recording).
    scaled = multiplier * double(data);
    scaled = max(min(round(scaled), 32767), -32768); % saturate to int16 range
    fwrite(fid, int16(scaled), 'int16');
end

function local_write_timestamps(fid, t_seconds)
    fwrite(fid, int64(round(t_seconds(:).' * 1e6)), 'int64');
end
