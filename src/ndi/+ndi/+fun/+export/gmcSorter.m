function outputFolders = gmcSorter(probe, outputFolder, options)
% NDI.FUN.EXPORT.GMCSORTER - export a probe's raw voltage for spike sorting with GMC_Sorter
%
% OUTPUTFOLDERS = NDI.FUN.EXPORT.GMCSORTER(PROBE, OUTPUTFOLDER, ...)
%
% Exports the raw extracellular voltage recorded by PROBE (an ndi.probe /
% ndi.element of type 'n-trode') into the raw file format that GMC_Sorter
% (https://github.com/stevevanhooser/GMC_Sorter) reads as file_struct
% 'dat_t_s'. Unlike an exporter that hands over already-sorted units, this
% gives GMC_Sorter the raw traces so that its OWN spike detector and feature
% extractor run -- which is what the GMC_Sorter workflow expects. After this
% export you run GMC_Sorter's extract_spike_features (a driver script is
% written for you), then open the resulting spike_prop/ folder in the
% GMC_Sorter GUI.
%
% For each exported epoch this writes a self-contained GMC_Sorter input
% folder containing:
%   [baseName]_samples.dat       int16 voltage, channel-interleaved
%   [baseName]_timestamps.dat    int64 sample times (microseconds)
%   channel_positions.csv        [x y] electrode positions (microns), the
%                                  ch_map GMC_Sorter's extractor needs
%   channel_map.mat              same positions as xcoords/ycoords/ch_map
%   [baseName].metadata          epoch/sample bookkeeping
%   run_gmc_extract.py           ready-to-run GMC_Sorter driver
%
% The int16 samples are written as int16 = round(multiplier * physical),
% column-interleaved so that GMC_Sorter's raw_data.py reshapes them as
% (n_time_samples, n_saved_chans); the timestamps are the probe's epoch clock
% converted to integer microseconds. See NDI.FUN.EXPORT.GMCSORTERWRITE for the
% byte-level layout contract.
%
% EPOCHS: with 'epochID' set, only that epoch is exported into OUTPUTFOLDER.
% With 'epochID' empty (default), every epoch of PROBE is exported; a single
% epoch goes directly into OUTPUTFOLDER, multiple epochs each go into an
% 'epoch_<id>' subfolder (GMC_Sorter's dat_t_s reader expects one recording
% per folder). OUTPUTFOLDERS is a cellstr of the folder(s) written.
%
% CHANNEL MAP: the [x y] positions are read from PROBE's stored geometry with
% NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP, aligned to the exported channel order.
% If PROBE has no geometry document, a default single-column linear map
% (x = 0, y spaced by 'spacing' microns) is written with a warning; pass
% 'channelPositions' to supply the true geometry explicitly.
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default)     | Description                                   |
% |-------------------------|-----------------------------------------------|
% | epochID ('')            | Export only this epoch. '' => all epochs.     |
% | baseName ('RawData')    | Base name for the '.dat' pair and metadata.   |
% | multiplier (1)          | Encode multiplier: int16 = multiplier *       |
% |                         |   physical. Choose so the physical range fills|
% |                         |   int16 without clipping (see                 |
% |                         |   ndi.fun.probe.export.autoMultiplier). GMC   |
% |                         |   thresholds are median-relative, so the      |
% |                         |   absolute scale only matters for int16       |
% |                         |   precision/clipping.                         |
% | channelPositions ([])   | n_channels x 2 [x y] positions (microns) in   |
% |                         |   channel order, overriding the probe geometry|
% | horizontalAxis          | Which probe axis becomes x: 'leftright' or    |
% |   ('leftright')         |   'frontback' (y is always depth).            |
% | spacing (25)            | Default linear y-spacing (microns) used only  |
% |                         |   when the probe has no geometry document.    |
% | gmcSorterPath ('')      | Path to the GMC_Sorter checkout, embedded in  |
% |                         |   run_gmc_extract.py's sys.path.              |
% | chunkDuration (100)     | Seconds of data read per chunk while          |
% |                         |   streaming (memory control).                 |
% | progressfcn ([])        | Optional handle f(pct,msg), pct in [0,1].     |
% | verbose (1)             | 0/1 Should we be verbose?                     |
% --------------------------------------------------------------------------
%
% Example:
%   S = ndi.session.dir('/path/to/session');
%   p = S.getprobes('type','n-trode'); p = p{1};
%   ndi.fun.export.gmcSorter(p, '/tmp/gmc_export');
%   % then, on a machine with GMC_Sorter installed:
%   %   python /tmp/gmc_export/run_gmc_extract.py
%   % and open /tmp/gmc_export in the GMC_Sorter GUI.
%
% See also: NDI.FUN.EXPORT.GMCSORTERWRITE, NDI.FUN.EXPORT.WRITEGMCSIDECARS,
%   NDI.FUN.PROBE.EXPORT.BINARY, NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP,
%   NDI.FUN.PROBE.EXPORT.AUTOMULTIPLIER

    arguments
        probe
        outputFolder (1,:) char
        options.epochID (1,:) char = ''
        options.baseName (1,:) char = 'RawData'
        options.multiplier (1,1) double = 1
        options.channelPositions double = []
        options.horizontalAxis (1,:) char {mustBeMember(options.horizontalAxis,{'leftright','frontback'})} = 'leftright'
        options.spacing (1,1) double = 25
        options.gmcSorterPath (1,:) char = ''
        options.chunkDuration (1,1) double = 100
        options.progressfcn = []
        options.verbose (1,1) double = 1
    end

    verbose = options.verbose;

    et = probe.epochtable();
    if isempty(et)
        error('ndi:fun:export:gmcSorter:noepochs', ...
            'Probe %s has no epochs to export.', probe.elementstring());
    end

    % select which epochs to export
    if ~isempty(options.epochID)
        idx = find(strcmp({et.epoch_id}, options.epochID), 1);
        if isempty(idx)
            error('ndi:fun:export:gmcSorter:noepoch', ...
                'Epoch %s was not found on probe %s.', options.epochID, probe.elementstring());
        end
        et = et(idx);
    end

    multiEpoch = numel(et) > 1;
    outputFolders = cell(1, numel(et));

    % total chunk count across all exported epochs, for the progress fraction
    total_chunks = 0;
    if ~isempty(options.progressfcn)
        for e=1:numel(et)
            ct = et(e).t0_t1{1}(1):options.chunkDuration:et(e).t0_t1{1}(2);
            total_chunks = total_chunks + numel(ct);
        end
        total_chunks = max(total_chunks,1);
    end
    done_chunks = 0;

    for e=1:numel(et)
        epoch_id = et(e).epoch_id;
        if multiEpoch
            thisFolder = fullfile(outputFolder, ['epoch_' epoch_id]);
        else
            thisFolder = outputFolder;
        end
        if ~isfolder(thisFolder)
            mkdir(thisFolder);
        end
        outputFolders{e} = thisFolder;

        if verbose
            disp(['Exporting epoch ' epoch_id ' (' int2str(e) ' of ' int2str(numel(et)) ') to ' thisFolder '.']);
        end

        samplesFile = fullfile(thisFolder, [options.baseName '_samples.dat']);
        tsFile      = fullfile(thisFolder, [options.baseName '_timestamps.dat']);
        fidS = fopen(samplesFile,'w','ieee-le');
        if fidS<0, error('ndi:fun:export:gmcSorter:open','Unable to open %s for writing.', samplesFile); end
        fidT = fopen(tsFile,'w','ieee-le');
        if fidT<0, fclose(fidS); error('ndi:fun:export:gmcSorter:open','Unable to open %s for writing.', tsFile); end

        sr = probe.samplerate(epoch_id);
        single_sample_time = 1/sr;
        numChannels = [];

        chunk_times = et(e).t0_t1{1}(1):options.chunkDuration:et(e).t0_t1{1}(2);
        for c=1:numel(chunk_times)
            start_time = chunk_times(c);
            end_time = min(chunk_times(c) + options.chunkDuration - single_sample_time, et(e).t0_t1{1}(2));
            [data,t] = probe.readtimeseries(epoch_id, start_time, end_time);
            if isempty(data), continue; end
            numChannels = size(data,2);
            % data is (n_samples x n_channels); write the transpose so each
            % time sample's channels are contiguous on disk (see gmcSorterWrite).
            local_write_samples(fidS, data.', options.multiplier);
            local_write_timestamps(fidT, t);
            done_chunks = done_chunks + 1;
            if ~isempty(options.progressfcn)
                options.progressfcn(done_chunks/total_chunks, ...
                    sprintf('epoch %d/%d, chunk %d/%d', e, numel(et), c, numel(chunk_times)));
            end
        end
        fclose(fidS);
        fclose(fidT);

        if isempty(numChannels)
            warning('ndi:fun:export:gmcSorter:empty', ...
                'Epoch %s produced no samples; wrote empty .dat files.', epoch_id);
            numChannels = 0;
        end

        % resolve channel positions [x y] aligned to the exported channel order
        channelPositions = local_channel_positions(probe, numChannels, options);

        epoch_sample_counts = local_epoch_sample_count(probe, epoch_id);

        ndi.fun.export.writeGmcSidecars(thisFolder, options.baseName, channelPositions, ...
            'epochSampleCounts', epoch_sample_counts, 'epochSampleRates', sr, ...
            'sampleRate', sr, 'multiplier', options.multiplier, ...
            'probeName', probe.elementstring(), 'gmcSorterPath', options.gmcSorterPath, ...
            'verbose', verbose);
    end
end % gmcSorter

% =========================================================================
% Low-level byte writers -- byte-identical to ndi.fun.export.gmcSorterWrite,
% so streamed and whole-array exports produce the same on-disk layout.
% =========================================================================
function local_write_samples(fid, data, multiplier)
    % data: n_channels x n_samples
    scaled = multiplier * double(data);
    scaled = max(min(round(scaled), 32767), -32768);
    fwrite(fid, int16(scaled), 'int16');
end

function local_write_timestamps(fid, t_seconds)
    fwrite(fid, int64(round(t_seconds(:).' * 1e6)), 'int64');
end

% =========================================================================
% Channel positions [x y], aligned to the exported channel order
% =========================================================================
function pos = local_channel_positions(probe, numChannels, options)
    if ~isempty(options.channelPositions)
        pos = options.channelPositions;
        if size(pos,1) ~= numChannels && numChannels>0
            error('ndi:fun:export:gmcSorter:posmismatch', ...
                ['channelPositions has %d rows but the export has %d channels; ' ...
                 'they must match.'], size(pos,1), numChannels);
        end
        return;
    end

    S = probe.session;
    mapFile = [tempname '.mat'];
    cleanup = onCleanup(@() local_delete(mapFile));
    tf = ndi.fun.probe.geometry.toKilosortMap(S, probe, mapFile, ...
        'num_channels', numChannels, 'horizontal_axis', options.horizontalAxis, ...
        'verbose', options.verbose);
    if tf && isfile(mapFile)
        m = load(mapFile, 'xcoords', 'ycoords');
        pos = [m.xcoords(:) m.ycoords(:)];
    else
        if options.verbose
            warning('ndi:fun:export:gmcSorter:nogeometry', ...
                ['Probe %s has no geometry document; writing a default single-column ' ...
                 'linear channel map (x=0, y spaced by %g um). Pass channelPositions ' ...
                 'for the real geometry.'], probe.elementstring(), options.spacing);
        end
        y = (0:max(numChannels-1,0)).' * options.spacing;
        pos = [zeros(numel(y),1) y];
    end
end

function local_delete(f)
    if isfile(f), delete(f); end
end

% =========================================================================
% Total sample count for an epoch (for metadata), via the probe's clock
% =========================================================================
function n = local_epoch_sample_count(probe, epoch_id)
    try
        et = probe.epochtable();
        idx = find(strcmp({et.epoch_id}, epoch_id), 1);
        s = probe.times2samples(epoch_id, et(idx).t0_t1{1});
        n = s(2) - s(1) + 1;
    catch
        n = [];
    end
end
