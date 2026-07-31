function [meanWf, wst, nUsed] = recalculatemeanwaveforms(binfile, num_channels, spike_samples_global, spike_clusters, cluster_ids, sample_rate, t0, t1, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORMS - mean waveforms for many clusters in one file pass
%
% [MEANWF, WST, NUSED] = NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORMS(...
%       BINFILE, NUM_CHANNELS, SPIKE_SAMPLES_GLOBAL, SPIKE_CLUSTERS, CLUSTER_IDS, ...
%       SAMPLE_RATE, T0, T1)
%
% Computes a wide mean spike waveform for EVERY cluster in CLUSTER_IDS directly from
% the raw binary BINFILE, reading the file in a SINGLE sequential pass. This is the
% many-cluster counterpart of NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORM,
% which reads one cluster at a time and therefore re-sweeps (and, when high-pass
% filtering, re-filters) the whole recording once per cluster. Here the file is
% streamed once in chunks: each chunk is read (and filtered) a single time, and every
% spike whose window falls in the chunk is added to its cluster's running mean. For N
% clusters this reads and filters ~N times less data.
%
% Inputs:
%   BINFILE              - path to the raw binary recording
%   NUM_CHANNELS         - number of interleaved channels in the binary (the read
%                           stride; must match the file, e.g. 385 for a raw
%                           Neuropixels AP band, 384 for an NDI export)
%   SPIKE_SAMPLES_GLOBAL - 0-based sample indices of ALL spikes into the concatenated
%                           stream (as stored in spike_times.npy)
%   SPIKE_CLUSTERS       - cluster id of each spike (same length as the samples)
%   CLUSTER_IDS          - the cluster ids to compute, in the desired output order
%   SAMPLE_RATE          - sampling rate (Hz)
%   T0, T1               - window start/end relative to each spike (seconds)
%
% MEANWF is a 1xnumel(CLUSTER_IDS) cell array; MEANWF{k} is the (NumSamples x
% NUM_CHANNELS) mean waveform for CLUSTER_IDS(k), in the same physical units as
% RECALCULATEMEANWAVEFORM (int16 divided by 'multiplier'). Clusters with no usable
% spikes get a zeros matrix. WST is the shared column vector of sample times
% (seconds, 0 at the spike). NUSED(k) is the number of spikes that contributed to
% cluster k (spikes whose window falls off the recording, or straddles an epoch seam
% when 'epochBounds' is given, are skipped - identical selection to the per-cluster
% function).
%
% Name/value pairs (defaults) - the same as RECALCULATEMEANWAVEFORM, plus:
% ---------------------------------------------------------------------------------
% | dtype ('int16'), byteOrder ('ieee-le'), headerOffsetBytes (0),                 |
% | multiplier (1), maxSpikes (1000), epochBounds ([]), highpass (false),          |
% | hp_cutoff (300), hp_order (4), hp_ripple (0.8)  - see RECALCULATEMEANWAVEFORM.  |
% |--------------------------|------------------------------------------------------|
% | chunkSamples (1e5)       | Target number of samples/channel to read and filter  |
% |                          |   per chunk. Larger is faster but uses more memory   |
% |                          |   (a chunk holds up to chunkSamples x num_channels   |
% |                          |   doubles). The read span of a chunk is bounded by   |
% |                          |   this plus the window/pad width.                    |
% | progressfcn ([])         | Optional handle f(fraction, message) called after    |
% |                          |   each chunk, with fraction the share of spikes done.|
% | verbose (false)          | If true, print a progress line every ~10%.           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORM,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE

    arguments
        binfile (1,:) char
        num_channels (1,1) double {mustBePositive}
        spike_samples_global double
        spike_clusters double
        cluster_ids double
        sample_rate (1,1) double {mustBePositive}
        t0 (1,1) double
        t1 (1,1) double
        options.dtype (1,:) char = 'int16'
        options.byteOrder (1,:) char = 'ieee-le'
        options.headerOffsetBytes (1,1) double = 0
        options.multiplier (1,1) double = 1
        options.maxSpikes (1,1) double = 1000
        options.epochBounds double = []
        options.highpass (1,1) logical = false
        options.hp_cutoff (1,1) double {mustBePositive} = 300
        options.hp_order (1,1) double {mustBePositive} = 4
        options.hp_ripple (1,1) double {mustBePositive} = 0.8
        options.chunkSamples (1,1) double {mustBePositive} = 1e5
        options.progressfcn = []
        options.verbose (1,1) logical = false
    end

    if t1 < t0,
        error('ndi:fun:probe:import:kilosort:recalculatemeanwaveforms:badWindow', ...
            'The window end T1 (%g) must be >= the window start T0 (%g).', t1, t0);
    end;

    % samples-per-channel data type -> bytes and fread precision
    switch lower(options.dtype),
        case {'int16','short'},            bytesPer = 2; prec = 'int16';
        case {'uint16','ushort'},          bytesPer = 2; prec = 'uint16';
        case {'int32','int'},              bytesPer = 4; prec = 'int32';
        case {'single','float','float32'}, bytesPer = 4; prec = 'single';
        case {'double','float64'},         bytesPer = 8; prec = 'double';
        otherwise,
            error('ndi:fun:probe:import:kilosort:recalculatemeanwaveforms:badDtype', ...
                'Unsupported dtype ''%s''.', options.dtype);
    end;

    K = numel(cluster_ids);

    % window sample offsets relative to each spike sample (0-based)
    off0 = round(t0*sample_rate);
    off1 = round(t1*sample_rate);
    nWin = off1 - off0 + 1;
    wst = ((off0:off1).') / sample_rate;

    % outputs default to zeros so clusters with no usable spikes are well-defined
    meanWf = cell(1, K);
    for k=1:K, meanWf{k} = zeros(nWin, num_channels); end;
    nUsed = zeros(K, 1);

    % design the high-pass filter once (identical to RECALCULATEMEANWAVEFORM): each
    % chunk is read with 'pad' extra samples beyond every spike's window, filtered
    % with zero-phase filtfilt, then windows are sliced out, so each window sees at
    % least 'pad' settled samples on either side (the trough alignment is preserved).
    doFilter = false;
    pad = 0;
    bcoef = [];
    acoef = [];
    if options.highpass,
        nyq = 0.5 * sample_rate;
        Wn = options.hp_cutoff / nyq;
        if ~(Wn > 0 && Wn < 1),
            warning('ndi:fun:probe:import:kilosort:recalculatemeanwaveforms:badCutoff', ...
                ['High-pass cutoff %g Hz is not valid for sample rate %g Hz ' ...
                '(must be 0 < cutoff < Nyquist = %g Hz); leaving the data unfiltered.'], ...
                options.hp_cutoff, sample_rate, nyq);
        elseif ~(exist('cheby1','file') || exist('cheby1','builtin')) || ...
                ~(exist('filtfilt','file') || exist('filtfilt','builtin')),
            warning('ndi:fun:probe:import:kilosort:recalculatemeanwaveforms:noSignalToolbox', ...
                ['highpass is true but the Signal Processing Toolbox (cheby1/filtfilt) ' ...
                'is not available; leaving the data unfiltered.']);
        else,
            [bcoef, acoef] = cheby1(options.hp_order, options.hp_ripple, Wn, 'high');
            doFilter = true;
            pad = max(ceil(3*sample_rate/options.hp_cutoff), 3*(options.hp_order+1));
        end;
    end;

    % offsets of the padded block that must be available around each spike
    readOff0 = off0 - pad;
    readOff1 = off1 + pad;

    % total number of complete multi-channel samples available in the file
    d = dir(binfile);
    if isempty(d),
        error('ndi:fun:probe:import:kilosort:recalculatemeanwaveforms:noFile', ...
            'Binary file not found: %s.', binfile);
    end;
    nTotalSamples = floor((d.bytes - options.headerOffsetBytes) / (bytesPer*num_channels));

    if isempty(spike_samples_global) || K==0,
        return;
    end;

    % --- build the flat list of (sample, output-index) to read, per cluster: apply
    % the same validity and maxSpikes selection as the per-cluster function so the
    % result is identical to calling it cluster by cluster. ---
    eb = options.epochBounds(:);
    sc = double(spike_samples_global(:));
    cl = double(spike_clusters(:));

    allSamp = [];
    allK = [];
    for k=1:K,
        ss = sc(cl == cluster_ids(k));
        if isempty(ss), continue; end;

        % window fully inside the recording (with padding when filtering)
        valid = (ss + readOff0) >= 0 & (ss + readOff1) <= (nTotalSamples-1);

        % and, if epoch bounds given, fully inside the spike's own epoch (no window
        % straddles the artificial seam between two concatenated epochs)
        if numel(eb) >= 2,
            e = sum(ss >= eb(1:end-1).', 2);
            e = max(min(e, numel(eb)-1), 1);
            lo = eb(e);
            hi = eb(e+1) - 1;
            valid = valid & (ss + readOff0) >= lo & (ss + readOff1) <= hi;
        end;
        ss = ss(valid);
        if isempty(ss), continue; end;

        % cap the number of spikes averaged (evenly spaced subset when over the cap)
        if isfinite(options.maxSpikes) && numel(ss) > options.maxSpikes,
            idx = unique(round(linspace(1, numel(ss), options.maxSpikes)));
            ss = ss(idx);
        end;

        allSamp = [allSamp; ss(:)];            %#ok<AGROW>
        allK    = [allK; repmat(k, numel(ss), 1)]; %#ok<AGROW>
    end;

    if isempty(allSamp),
        return;
    end;

    % order by sample so the file is read strictly front-to-back
    [allSamp, ord] = sort(allSamp);
    allK = allK(ord);
    N = numel(allSamp);

    % per-cluster accumulators
    acc = cell(1, K);
    for k=1:K, acc{k} = zeros(nWin, num_channels); end;

    fid = fopen(binfile, 'r', options.byteOrder);
    if fid < 0,
        error('ndi:fun:probe:import:kilosort:recalculatemeanwaveforms:cannotOpen', ...
            'Unable to open binary file %s for reading.', binfile);
    end;
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    lastPct = 0;
    i = 1;
    while i <= N,
        % greedily grow a chunk whose spikes span at most chunkSamples, so the read
        % block (spike span + padding) stays bounded regardless of spike density
        spanLimit = allSamp(i) + options.chunkSamples;
        j = i;
        while j < N && allSamp(j+1) <= spanLimit,
            j = j + 1;
        end;

        chunkSamp = allSamp(i:j);
        chunkK    = allK(i:j);

        rStart = chunkSamp(1) + readOff0;      % >= 0 by the validity check
        rEnd   = chunkSamp(end) + readOff1;    % <= nTotalSamples-1 by the validity check
        nBlock = rEnd - rStart + 1;

        byteOffset = options.headerOffsetBytes + rStart*num_channels*bytesPer;
        if fseek(fid, byteOffset, 'bof') ~= 0,
            i = j + 1;
            continue;
        end;
        raw = fread(fid, num_channels*nBlock, [prec '=>double']);
        if numel(raw) < num_channels*nBlock,
            i = j + 1;
            continue; % short read (should not happen given the validity check)
        end;
        block = reshape(raw, num_channels, nBlock).'; % (nBlock x num_channels)
        if doFilter,
            block = filtfilt(bcoef, acoef, block); % zero-phase high-pass per channel
        end;

        for m=1:numel(chunkSamp),
            p = chunkSamp(m);
            k = chunkK(m);
            r0 = (p + off0) - rStart + 1;       % 1-based row of the window start
            r1 = (p + off1) - rStart + 1;
            acc{k} = acc{k} + block(r0:r1, :);
            nUsed(k) = nUsed(k) + 1;
        end;

        i = j + 1;

        % progress = share of spikes processed
        frac = (i-1) / N;
        if ~isempty(options.progressfcn),
            options.progressfcn(frac, 'Recalculating mean waveforms');
        end;
        if options.verbose && (frac - lastPct) >= 0.10,
            lastPct = frac;
            disp(['  Recalculating mean waveforms: ' int2str(round(100*frac)) '% ' ...
                '(' int2str(i-1) ' of ' int2str(N) ' spikes).']);
        end;
    end;

    % finalize: mean = sum/count, then int16 -> physical units (free each
    % accumulator as we go so acc and meanWf are not both held at full size)
    for k=1:K,
        if nUsed(k) > 0,
            meanWf{k} = acc{k} / nUsed(k);
            if options.multiplier ~= 0 && options.multiplier ~= 1,
                meanWf{k} = meanWf{k} / options.multiplier;
            end;
        end;
        acc{k} = [];
    end;

    if ~isempty(options.progressfcn),
        options.progressfcn(1, 'Recalculating mean waveforms');
    end;

end
