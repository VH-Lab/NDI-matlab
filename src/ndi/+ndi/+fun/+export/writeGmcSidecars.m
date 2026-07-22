function writeGmcSidecars(outputFolder, baseName, channelPositions, options)
% NDI.FUN.EXPORT.WRITEGMCSIDECARS - write the channel map, metadata, and driver files for a GMC_Sorter export
%
% NDI.FUN.EXPORT.WRITEGMCSIDECARS(OUTPUTFOLDER, BASENAME, CHANNELPOSITIONS, ...)
%
% Writes the non-voltage companion files that accompany the raw '.dat' pair
% produced for GMC_Sorter (https://github.com/stevevanhooser/GMC_Sorter) by
% NDI.FUN.EXPORT.GMCSORTER / NDI.FUN.EXPORT.GMCSORTERWRITE. GMC_Sorter's raw
% reader (raw_data.py, file_struct 'dat_t_s') finds the '*_samples.dat' and
% '*_timestamps.dat' files by suffix and derives the channel count and sample
% rate from their sizes, but its feature extractor (sp_feature_ext.py,
% extract_spike_features) additionally needs a channel map: an (n_channels x 2)
% array of [x y] electrode positions (microns) in the SAME channel order as the
% samples file. This function writes that map (and a couple of conveniences) so
% the exported folder is a self-contained, runnable GMC_Sorter input.
%
% Files written into OUTPUTFOLDER:
% --------------------------------------------------------------------------
% | File                     | Contents                                     |
% |--------------------------|----------------------------------------------|
% | channel_positions.csv    | n_channels rows of "x,y" (microns), channel  |
% |                          |   order. Load in Python with np.loadtxt(...,  |
% |                          |   delimiter=',') and pass as ch_map.         |
% | channel_map.mat          | xcoords, ycoords (1 x n_channels) and ch_map |
% |                          |   (n_channels x 2 = [xcoords' ycoords']).    |
% | [baseName].metadata      | epoch_sample_counts, epoch_sample_rates,     |
% |                          |   num_channels, multiplier, sample_rate,     |
% |                          |   probe_name, file_struct ('dat_t_s'),       |
% |                          |   samples_file, timestamps_file. Written with|
% |                          |   vlt.file.saveStructArray (same as          |
% |                          |   ndi.fun.probe.export.binary).              |
% | run_gmc_extract.py       | A ready-to-run driver that calls             |
% |                          |   extract_spike_features on this folder,      |
% |                          |   producing spike_prop/batch_*_spike_         |
% |                          |   properties.npz for the GMC_Sorter GUI.     |
% --------------------------------------------------------------------------
%
% Name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default)       | Description                                 |
% |---------------------------|---------------------------------------------|
% | epochSampleCounts ([])    | Per-epoch sample counts (for metadata).     |
% | epochSampleRates ([])     | Per-epoch sample rates, Hz (for metadata).  |
% | sampleRate ([])           | Representative sample rate, Hz (for driver  |
% |                           |   comment); defaults to epochSampleRates(1).|
% | multiplier (1)            | Encode multiplier used for the samples file.|
% | probeName ('')            | Probe elementstring, recorded in metadata.  |
% | writeDriver (true)        | Whether to write run_gmc_extract.py.        |
% | gmcSorterPath ('')        | Filesystem path to the GMC_Sorter checkout  |
% |                           |   (the folder holding sp_feature_ext.py),   |
% |                           |   added to sys.path in the driver. If empty,|
% |                           |   the driver assumes GMC_Sorter is already  |
% |                           |   importable.                               |
% | verbose (1)               | 0/1 Should we be verbose?                   |
% --------------------------------------------------------------------------
%
% See also: NDI.FUN.EXPORT.GMCSORTER, NDI.FUN.EXPORT.GMCSORTERWRITE,
%   NDI.FUN.PROBE.EXPORT.BINARY

    arguments
        outputFolder (1,:) char
        baseName (1,:) char
        channelPositions (:,2) double
        options.epochSampleCounts double = []
        options.epochSampleRates double = []
        options.sampleRate double = []
        options.multiplier (1,1) double = 1
        options.probeName (1,:) char = ''
        options.writeDriver (1,1) logical = true
        options.gmcSorterPath (1,:) char = ''
        options.verbose (1,1) double = 1
    end

    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    numChannels = size(channelPositions,1);
    xcoords = channelPositions(:,1).';   % 1 x n_channels
    ycoords = channelPositions(:,2).';   % 1 x n_channels

    sampleRate = options.sampleRate;
    if isempty(sampleRate) && ~isempty(options.epochSampleRates)
        sampleRate = options.epochSampleRates(1);
    end

    % --- channel_positions.csv : "x,y" per channel, channel order ---------
    csvFile = fullfile(outputFolder, 'channel_positions.csv');
    fid = fopen(csvFile, 'w');
    if fid<0
        error('ndi:fun:export:writeGmcSidecars:csv', ...
            'Unable to open %s for writing.', csvFile);
    end
    for i = 1:numChannels
        fprintf(fid, '%.6g,%.6g\n', channelPositions(i,1), channelPositions(i,2));
    end
    fclose(fid);

    % --- channel_map.mat --------------------------------------------------
    ch_map = channelPositions; %#ok<NASGU> (n_channels x 2 = [x y])
    save(fullfile(outputFolder, 'channel_map.mat'), 'xcoords', 'ycoords', 'ch_map', '-v7');

    % --- [baseName].metadata (same writer as ndi.fun.probe.export.binary) -
    epoch_sample_counts = options.epochSampleCounts; %#ok<NASGU>
    epoch_sample_rates  = options.epochSampleRates;  %#ok<NASGU>
    num_channels = numChannels;                      %#ok<NASGU>
    multiplier   = options.multiplier;               %#ok<NASGU>
    probe_name   = options.probeName;                %#ok<NASGU>
    file_struct  = 'dat_t_s';                        %#ok<NASGU>
    samples_file    = [baseName '_samples.dat'];     %#ok<NASGU>
    timestamps_file = [baseName '_timestamps.dat'];  %#ok<NASGU>
    metastructure = vlt.data.var2struct('epoch_sample_counts','epoch_sample_rates', ...
        'num_channels','multiplier','probe_name','file_struct', ...
        'samples_file','timestamps_file');
    vlt.file.saveStructArray(fullfile(outputFolder, [baseName '.metadata']), metastructure);

    % --- run_gmc_extract.py : a ready-to-run GMC_Sorter driver ------------
    if options.writeDriver
        local_write_driver(outputFolder, sampleRate, options.gmcSorterPath);
    end

    if options.verbose
        disp(['Wrote GMC_Sorter channel map + metadata to ' outputFolder '.']);
    end
end % writeGmcSidecars

function local_write_driver(outputFolder, sampleRate, gmcSorterPath)
    driverFile = fullfile(outputFolder, 'run_gmc_extract.py');
    fid = fopen(driverFile, 'w');
    if fid<0
        warning('ndi:fun:export:writeGmcSidecars:driver', ...
            'Unable to write driver script %s; skipping.', driverFile);
        return;
    end
    if isempty(sampleRate)
        srComment = '(read from the .dat files at run time)';
    else
        srComment = sprintf('~%.6g Hz', sampleRate);
    end
    L = {};
    L{end+1} = '#!/usr/bin/env python3';
    L{end+1} = '"""Auto-generated by ndi.fun.export.gmcSorter (NDI -> GMC_Sorter, Level A).';
    L{end+1} = '';
    L{end+1} = 'Runs GMC_Sorter''s own spike detector + feature extractor on the raw';
    L{end+1} = 'voltage that NDI exported here (file_struct ''dat_t_s''), producing';
    L{end+1} = 'spike_prop/batch_*_spike_properties.npz for the GMC_Sorter GUI.';
    L{end+1} = sprintf('Sample rate: %s.', srComment);
    L{end+1} = '"""';
    L{end+1} = 'import os';
    L{end+1} = 'import numpy as np';
    if ~isempty(gmcSorterPath)
        L{end+1} = 'import sys';
        L{end+1} = sprintf('sys.path.insert(0, r"%s")  # folder holding sp_feature_ext.py', gmcSorterPath);
    else
        L{end+1} = '# If sp_feature_ext is not importable, add the GMC_Sorter checkout to sys.path:';
        L{end+1} = '#   import sys; sys.path.insert(0, r"/path/to/GMC_Sorter")';
    end
    L{end+1} = 'from sp_feature_ext import extract_spike_features';
    L{end+1} = '';
    L{end+1} = 'here = os.path.dirname(os.path.abspath(__file__))';
    L{end+1} = 'exp_folder = here          # holds *_samples.dat and *_timestamps.dat';
    L{end+1} = 'out_folder = here          # spike_prop/ is written here';
    L{end+1} = 'ch_map = np.atleast_2d(np.loadtxt(os.path.join(here, "channel_positions.csv"), delimiter=","))';
    L{end+1} = '';
    L{end+1} = 'extract_spike_features(';
    L{end+1} = '    exp_folder, "dat_t_s", ch_map, out_folder,';
    L{end+1} = '    time_interval=(0, float("inf")), make_plots=False,';
    L{end+1} = ')';
    L{end+1} = 'print("Done. Point the GMC_Sorter GUI at:", out_folder)';
    fprintf(fid, '%s\n', L{:});
    fclose(fid);
end % local_write_driver
