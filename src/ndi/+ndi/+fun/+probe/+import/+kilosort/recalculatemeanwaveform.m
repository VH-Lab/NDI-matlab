function [meanWf, wst, nUsed] = recalculatemeanwaveform(binfile, num_channels, spike_samples_global, sample_rate, t0, t1, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORM - mean waveform read from the raw binary
%
% [MEANWF, WST, NUSED] = NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORM(...
%       BINFILE, NUM_CHANNELS, SPIKE_SAMPLES_GLOBAL, SAMPLE_RATE, T0, T1)
%
% Computes a mean spike waveform for a single cluster directly from the raw binary
% recording BINFILE (the concatenated int16 stream that Kilosort was run on, as
% written by NDI.FUN.PROBE.EXPORT.BINARY). Unlike the Kilosort template waveforms,
% which are only ~2 ms wide, this reads an arbitrary window [T0, T1] (in seconds,
% relative to each spike sample) around every spike and averages them, so a much
% wider window (e.g. -5 ms to +5 ms) can be recovered.
%
% Inputs:
%   BINFILE              - path to the raw binary recording
%   NUM_CHANNELS         - number of interleaved channels in the binary
%   SPIKE_SAMPLES_GLOBAL - 0-based sample indices of this cluster's spikes into the
%                           concatenated stream (as stored in spike_times.npy)
%   SAMPLE_RATE          - sampling rate (Hz)
%   T0                   - window start relative to each spike (seconds, e.g. -0.005)
%   T1                   - window end relative to each spike (seconds, e.g. +0.005)
%
% MEANWF is a (NumSamples x NUM_CHANNELS) matrix in the same physical units as the
% template-based waveforms (int16 values are divided by 'multiplier' - the encode
% multiplier recorded in the export .metadata sidecar - so the result is in the
% probe's physical units). WST is the column vector of sample times (seconds),
% running from ~T0 to ~T1 with 0 at the spike sample. NUSED is the number of spikes
% that actually contributed (spikes whose window would fall off either end of the
% recording are skipped).
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | dtype ('int16')          | Sample data type in the binary                      |
% | byteOrder ('ieee-le')    | Byte order used to read the binary                  |
% | headerOffsetBytes (0)    | Bytes to skip at the start of the file (phy 'offset')|
% | multiplier (1)           | Encode multiplier: int16 = multiplier*physical.     |
% |                          |   The mean is divided by this so it is in physical  |
% |                          |   units. Pass 1 to leave the values as stored.      |
% | maxSpikes (1000)         | Maximum number of spikes to average per cluster. If |
% |                          |   a cluster has more, an evenly spaced subset is    |
% |                          |   used (the mean of a large random-ish subset is    |
% |                          |   indistinguishable from the full mean but far      |
% |                          |   cheaper to read). Inf uses every spike.           |
% | epochBounds ([])         | 0-based half-open epoch boundaries into the         |
% |                          |   concatenated stream ([0; cumsum(epoch_counts)]).  |
% |                          |   When given, a spike is used only if its whole     |
% |                          |   window stays within the single epoch it belongs   |
% |                          |   to, so no window straddles the artificial seam    |
% |                          |   between two concatenated epochs. When empty, only |
% |                          |   the file's own start/end are honored.             |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.IMPORT.KILOSORT.BINARYINFO,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.MEANWAVEFORM, NDI.FUN.PROBE.EXPORT.BINARY

    arguments
        binfile (1,:) char
        num_channels (1,1) double {mustBePositive}
        spike_samples_global double
        sample_rate (1,1) double {mustBePositive}
        t0 (1,1) double
        t1 (1,1) double
        options.dtype (1,:) char = 'int16'
        options.byteOrder (1,:) char = 'ieee-le'
        options.headerOffsetBytes (1,1) double = 0
        options.multiplier (1,1) double = 1
        options.maxSpikes (1,1) double = 1000
        options.epochBounds double = []
    end

    if t1 < t0,
        error('ndi:fun:probe:import:kilosort:recalculatemeanwaveform:badWindow', ...
            'The window end T1 (%g) must be >= the window start T0 (%g).', t1, t0);
    end;

    % samples-per-channel data type -> bytes and fread precision
    switch lower(options.dtype),
        case {'int16','short'},          bytesPer = 2; prec = 'int16';
        case {'uint16','ushort'},        bytesPer = 2; prec = 'uint16';
        case {'int32','int'},            bytesPer = 4; prec = 'int32';
        case {'single','float','float32'}, bytesPer = 4; prec = 'single';
        case {'double','float64'},       bytesPer = 8; prec = 'double';
        otherwise,
            error('ndi:fun:probe:import:kilosort:recalculatemeanwaveform:badDtype', ...
                'Unsupported dtype ''%s''.', options.dtype);
    end;

    % window sample offsets relative to each spike sample (0-based, symmetric-ish)
    off0 = round(t0*sample_rate);
    off1 = round(t1*sample_rate);
    nWin = off1 - off0 + 1;
    wst = ((off0:off1).') / sample_rate;

    % total number of complete multi-channel samples available in the file
    d = dir(binfile);
    if isempty(d),
        error('ndi:fun:probe:import:kilosort:recalculatemeanwaveform:noFile', ...
            'Binary file not found: %s.', binfile);
    end;
    nTotalSamples = floor((d.bytes - options.headerOffsetBytes) / (bytesPer*num_channels));

    meanWf = zeros(nWin, num_channels);
    nUsed = 0;

    if isempty(spike_samples_global),
        return;
    end;

    ss = double(spike_samples_global(:));

    % keep only spikes whose full window lies inside the recording (file ends)
    valid = (ss + off0) >= 0 & (ss + off1) <= (nTotalSamples-1);

    % if epoch boundaries were provided, additionally require each spike's whole
    % window to stay within the single epoch it belongs to, so a window never
    % straddles the artificial seam where two concatenated epochs meet (the far
    % side of such a seam is unrelated data from a different recording).
    eb = options.epochBounds(:);
    if numel(eb) >= 2,
        % epoch index of each spike = number of left edges it is at or past
        e = sum(ss >= eb(1:end-1).', 2);
        e = max(min(e, numel(eb)-1), 1); % clamp (spikes are expected in range)
        lo = eb(e);        % first sample of the spike's epoch (0-based)
        hi = eb(e+1) - 1;  % last sample of the spike's epoch (0-based)
        valid = valid & (ss + off0) >= lo & (ss + off1) <= hi;
    end;

    ss = ss(valid);
    if isempty(ss),
        return;
    end;

    % cap the number of spikes averaged (evenly spaced subset when over the cap)
    if isfinite(options.maxSpikes) && numel(ss) > options.maxSpikes,
        idx = unique(round(linspace(1, numel(ss), options.maxSpikes)));
        ss = ss(idx);
    end;

    fid = fopen(binfile, 'r', options.byteOrder);
    if fid < 0,
        error('ndi:fun:probe:import:kilosort:recalculatemeanwaveform:cannotOpen', ...
            'Unable to open binary file %s for reading.', binfile);
    end;
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    acc = zeros(nWin, num_channels);
    for i=1:numel(ss),
        startSample = ss(i) + off0; % 0-based sample index of the first sample in the window
        byteOffset = options.headerOffsetBytes + startSample*num_channels*bytesPer;
        if fseek(fid, byteOffset, 'bof') ~= 0,
            continue;
        end;
        raw = fread(fid, num_channels*nWin, [prec '=>double']);
        if numel(raw) < num_channels*nWin,
            continue; % short read (should not happen given the validity check)
        end;
        % binary is channel-interleaved per sample: [ch1 ch2 ... chN] for each sample
        w = reshape(raw, num_channels, nWin).'; % -> (nWin x num_channels)
        acc = acc + w;
        nUsed = nUsed + 1;
    end;

    if nUsed > 0,
        meanWf = acc / nUsed;
    end;

    % convert stored int16 back to physical units: physical = int16 / multiplier
    if options.multiplier ~= 0 && options.multiplier ~= 1,
        meanWf = meanWf / options.multiplier;
    end;

end
