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
% channels that pass loads. This function writes that map (and a couple of
% conveniences) so the exported folder is a self-contained, runnable
% GMC_Sorter input.
%
% This targets GMC_Sorter Version 4, whose extract_spike_features takes a
% CH_ORDER argument -- a list of 0-based recording channel indices that selects
% and reorders the channels a pass loads (raw_data.py indexes the samples file
% with it). Version 4's own driver (main.py) uses that to run ONE PASS PER
% PROBE SHANK, with each pass's ch_map holding just that shank's sites in
% ch_order order. The generated driver here does the same, deriving the shanks
% from the exported channel table.
%
% Files written into OUTPUTFOLDER:
% --------------------------------------------------------------------------
% | File                     | Contents                                     |
% |--------------------------|----------------------------------------------|
% | channel_info.csv         | Header row 'channel,x,y,shank,connected'     |
% |                          |   then one row per exported channel: 0-based |
% |                          |   channel index, [x y] in microns, shank id, |
% |                          |   and 1/0 for whether a site is wired to it. |
% |                          |   This is what the driver groups into the    |
% |                          |   per-shank ch_order / ch_map pairs.         |
% | channel_positions.csv    | n_channels rows of "x,y" (microns), channel  |
% |                          |   order. The whole-probe ch_map, kept for    |
% |                          |   single-shank use and for reading the map   |
% |                          |   without parsing the header row.            |
% | channel_map.mat          | xcoords, ycoords, kcoords (shank), connected |
% |                          |   (1 x n_channels) and ch_map (n_channels x  |
% |                          |   2 = [xcoords' ycoords']).                  |
% | [baseName].metadata      | epoch_sample_counts, epoch_sample_rates,     |
% |                          |   num_channels, num_shanks, multiplier,      |
% |                          |   sample_rate, probe_name, file_struct        |
% |                          |   ('dat_t_s'), samples_file, timestamps_file.|
% |                          |   Written with vlt.file.saveStructArray (same|
% |                          |   as ndi.fun.probe.export.binary).           |
% | run_gmc_extract.py       | A ready-to-run Version 4 driver: one         |
% |                          |   extract_spike_features(..., ch_order=...)  |
% |                          |   pass per shank, then properties.mat for    |
% |                          |   each pass (the same concatenation          |
% |                          |   GMC_Sorter's main.py does), producing      |
% |                          |   spike_prop/batch_*_spike_properties.npz    |
% |                          |   for the GMC_Sorter GUI.                    |
% --------------------------------------------------------------------------
%
% Name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default)       | Description                                 |
% |---------------------------|---------------------------------------------|
% | shankIndex ([])           | n_channels x 1 shank id per channel (the    |
% |                           |   Kilosort 'kcoords'). Empty => all channels|
% |                           |   on one shank. Channels sharing an id are  |
% |                           |   sorted together in one GMC pass.          |
% | connected ([])            | n_channels x 1 logical: does this channel   |
% |                           |   have an electrode site? Empty => all true. |
% |                           |   Unconnected channels are left out of      |
% |                           |   ch_order so GMC never sorts them.         |
% | sortByDepth (true)        | Order each shank's ch_order tip-to-base     |
% |                           |   (ascending y), matching the convention in  |
% |                           |   GMC_Sorter's probe_mappings.py.           |
% | gmcProbeName ('')         | Name of a GMC_Sorter built-in probe (see    |
% |                           |   probe_mappings.get_probe_map, e.g.        |
% |                           |   'KN_UCLA_64M'). If given, the driver uses |
% |                           |   GMC's own wiring instead of the exported  |
% |                           |   channel table. Only correct if the export |
% |                           |   channel order IS that probe's wiring.     |
% | featureOptions ({})       | Name/value cell passed through to           |
% |                           |   extract_spike_features as keyword         |
% |                           |   arguments, e.g. {'refr_space',150,        |
% |                           |   'wvf_space',150,'noise_space',NaN}.       |
% | makePlots (false)         | make_plots for extract_spike_features.      |
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
        options.shankIndex double = []
        options.connected = []
        options.sortByDepth (1,1) logical = true
        options.gmcProbeName (1,:) char = ''
        options.featureOptions cell = {}
        options.makePlots (1,1) logical = false
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

    [kcoords, connected] = local_shank_and_connected(numChannels, ...
        options.shankIndex, options.connected);

    if mod(numel(options.featureOptions),2)~=0
        error('ndi:fun:export:writeGmcSidecars:featureOptions', ...
            'featureOptions must be a cell array of name/value pairs (got %d elements).', ...
            numel(options.featureOptions));
    end

    sampleRate = options.sampleRate;
    if isempty(sampleRate) && ~isempty(options.epochSampleRates)
        sampleRate = options.epochSampleRates(1);
    end

    % --- channel_info.csv : the per-shank ch_order/ch_map source -----------
    infoFile = fullfile(outputFolder, 'channel_info.csv');
    fid = fopen(infoFile, 'w');
    if fid<0
        error('ndi:fun:export:writeGmcSidecars:csv', ...
            'Unable to open %s for writing.', infoFile);
    end
    fprintf(fid, 'channel,x,y,shank,connected\n');
    for i = 1:numChannels
        fprintf(fid, '%d,%.6g,%.6g,%d,%d\n', i-1, ...   % 0-based: Python indexes it
            channelPositions(i,1), channelPositions(i,2), kcoords(i), connected(i));
    end
    fclose(fid);

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
    ch_map = channelPositions; % n_channels x 2 = [x y]
    % kcoords/connected are saved 1 x n_channels, matching xcoords/ycoords
    mapStruct = struct('xcoords', xcoords, 'ycoords', ycoords, ...
        'kcoords', kcoords(:).', 'connected', connected(:).', 'ch_map', ch_map);
    save(fullfile(outputFolder, 'channel_map.mat'), '-struct', 'mapStruct', '-v7');

    % --- [baseName].metadata (same writer as ndi.fun.probe.export.binary) -
    epoch_sample_counts = options.epochSampleCounts; %#ok<NASGU>
    epoch_sample_rates  = options.epochSampleRates;  %#ok<NASGU>
    num_channels = numChannels;                      %#ok<NASGU>
    num_shanks   = numel(unique(kcoords));           %#ok<NASGU>
    multiplier   = options.multiplier;               %#ok<NASGU>
    probe_name   = options.probeName;                %#ok<NASGU>
    file_struct  = 'dat_t_s';                        %#ok<NASGU>
    samples_file    = [baseName '_samples.dat'];     %#ok<NASGU>
    timestamps_file = [baseName '_timestamps.dat'];  %#ok<NASGU>
    metastructure = vlt.data.var2struct('epoch_sample_counts','epoch_sample_rates', ...
        'num_channels','num_shanks','multiplier','probe_name','file_struct', ...
        'samples_file','timestamps_file');
    vlt.file.saveStructArray(fullfile(outputFolder, [baseName '.metadata']), metastructure);

    % --- run_gmc_extract.py : a ready-to-run GMC_Sorter Version 4 driver ---
    if options.writeDriver
        local_write_driver(outputFolder, sampleRate, options);
    end

    if options.verbose
        disp(['Wrote GMC_Sorter channel map + metadata to ' outputFolder '.']);
    end
end % writeGmcSidecars

% =========================================================================
% Shank ids and connectedness, defaulted and validated against the channels
% =========================================================================
function [kcoords, connected] = local_shank_and_connected(numChannels, shankIndex, connectedIn)
    if isempty(shankIndex)
        kcoords = ones(numChannels,1);
    else
        kcoords = double(shankIndex(:));
        if numel(kcoords) ~= numChannels
            error('ndi:fun:export:writeGmcSidecars:shankIndex', ...
                ['shankIndex has %d elements but the export has %d channels; ' ...
                 'they must match.'], numel(kcoords), numChannels);
        end
    end

    if isempty(connectedIn)
        connected = true(numChannels,1);
    else
        connected = logical(connectedIn(:));
        if numel(connected) ~= numChannels
            error('ndi:fun:export:writeGmcSidecars:connected', ...
                ['connected has %d elements but the export has %d channels; ' ...
                 'they must match.'], numel(connected), numChannels);
        end
    end
end % local_shank_and_connected

% =========================================================================
% The GMC_Sorter Version 4 driver script
% =========================================================================
function local_write_driver(outputFolder, sampleRate, options)
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
    L{end+1} = '"""Auto-generated by ndi.fun.export.gmcSorter (NDI -> GMC_Sorter Version 4).';
    L{end+1} = '';
    L{end+1} = 'Runs GMC_Sorter''s own spike detector + feature extractor on the raw';
    L{end+1} = 'voltage that NDI exported here (file_struct ''dat_t_s''), producing';
    L{end+1} = 'spike_prop/batch_*_spike_properties.npz for the GMC_Sorter GUI plus a';
    L{end+1} = 'properties.mat for MATLAB/NDI.';
    L{end+1} = '';
    L{end+1} = 'One extract_spike_features pass runs per probe shank, as in GMC_Sorter''s';
    L{end+1} = 'own main.py: ch_order gives the 0-based recording channels that pass';
    L{end+1} = 'loads (in load order) and ch_map holds those channels'' [x y] positions in';
    L{end+1} = 'the SAME order. Multi-shank exports write each pass into Sh<n>/.';
    L{end+1} = sprintf('Sample rate: %s.', srComment);
    L{end+1} = '"""';
    L{end+1} = 'import os';
    L{end+1} = 'import glob';
    L{end+1} = 'import numpy as np';
    L{end+1} = 'import scipy.io';
    if ~isempty(options.gmcSorterPath)
        L{end+1} = 'import sys';
        L{end+1} = sprintf('sys.path.insert(0, r"%s")  # folder holding sp_feature_ext.py', options.gmcSorterPath);
    else
        L{end+1} = '# If sp_feature_ext is not importable, add the GMC_Sorter checkout to sys.path:';
        L{end+1} = '#   import sys; sys.path.insert(0, r"/path/to/GMC_Sorter")';
    end
    L{end+1} = 'from sp_feature_ext import extract_spike_features';
    if ~isempty(options.gmcProbeName)
        L{end+1} = 'from probe_mappings import get_probe_map';
    end
    L{end+1} = '';
    L{end+1} = 'HERE = os.path.dirname(os.path.abspath(__file__))';
    L{end+1} = 'EXP_FOLDER = HERE          # holds *_samples.dat and *_timestamps.dat';
    L{end+1} = 'FILE_STRUCT = "dat_t_s"';
    L{end+1} = sprintf('MAKE_PLOTS = %s', local_py_bool(options.makePlots));
    L{end+1} = sprintf('SORT_BY_DEPTH = %s   # order each shank tip-to-base (ascending y)', ...
        local_py_bool(options.sortByDepth));
    L{end+1} = sprintf('PROBE_NAME = %s   # "" -> use channel_info.csv; else a probe_mappings name', ...
        local_py_str(options.gmcProbeName));
    L{end+1} = ['EXTRACT_KWARGS = dict(' local_py_kwargs(options.featureOptions) ')'];
    L{end+1} = '';
    L{end+1} = '';
    L{end+1} = 'def exported_time_interval():';
    L{end+1} = '    """The epoch clock span actually exported, in seconds.';
    L{end+1} = '';
    L{end+1} = '    extract_spike_features'' own default of (0, inf) resolves inf to';
    L{end+1} = '    n_samples/sample_rate, i.e. it assumes the recording starts at t=0.';
    L{end+1} = '    NDI writes the probe''s epoch clock, whose t0 need not be 0, so read the';
    L{end+1} = '    real first/last timestamp instead. GMC''s binary search is exclusive at';
    L{end+1} = '    both ends, hence the +1 us so the final sample is included.';
    L{end+1} = '    """';
    L{end+1} = '    name = next(f for f in os.listdir(EXP_FOLDER) if f.endswith("_timestamps.dat"))';
    L{end+1} = '    path = os.path.join(EXP_FOLDER, name)';
    L{end+1} = '    if os.path.getsize(path) == 0:   # an epoch that exported no samples';
    L{end+1} = '        raise SystemExit("Timestamps file is empty; nothing to sort.")';
    L{end+1} = '    ts = np.memmap(path, dtype=np.int64, mode="r")';
    L{end+1} = '    return (float(ts[0]) / 1e6, float(ts[-1] + 1) / 1e6)';
    L{end+1} = '';
    L{end+1} = '';
    L{end+1} = 'def shanks_from_export():';
    L{end+1} = '    """Group the channels NDI exported into one (ch_order, ch_map) pair per shank."""';
    L{end+1} = '    info = np.atleast_2d(np.loadtxt(os.path.join(HERE, "channel_info.csv"),';
    L{end+1} = '                                    delimiter=",", skiprows=1))';
    L{end+1} = '    if info.size == 0:';
    L{end+1} = '        return []';
    L{end+1} = '    channel = info[:, 0].astype(int)     # 0-based index into the samples file';
    L{end+1} = '    xy      = info[:, 1:3]';
    L{end+1} = '    shank   = info[:, 3].astype(int)';
    L{end+1} = '    good    = info[:, 4].astype(bool)    # channel has an electrode site';
    L{end+1} = '    out = []';
    L{end+1} = '    for k in np.unique(shank):';
    L{end+1} = '        sel = np.flatnonzero((shank == k) & good)';
    L{end+1} = '        if sel.size == 0:';
    L{end+1} = '            continue';
    L{end+1} = '        if SORT_BY_DEPTH:';
    L{end+1} = '            sel = sel[np.argsort(xy[sel, 1], kind="stable")]';
    L{end+1} = '        out.append(dict(ch_order=channel[sel].tolist(), ch_map=xy[sel, :]))';
    L{end+1} = '    return out';
    L{end+1} = '';
    L{end+1} = '';
    L{end+1} = 'def shanks_from_probe_mappings(name):';
    L{end+1} = '    """Use GMC_Sorter''s own wiring for a named probe instead of the export."""';
    L{end+1} = '    out = []';
    L{end+1} = '    for sh in get_probe_map(name):';
    L{end+1} = '        order = sh["ch_order"]';
    L{end+1} = '        if order is None:';
    L{end+1} = '            order = list(range(len(sh["x_position"])))';
    L{end+1} = '        out.append(dict(';
    L{end+1} = '            ch_order=list(order),';
    L{end+1} = '            ch_map=np.column_stack([sh["x_position"], sh["y_position"]]),';
    L{end+1} = '        ))';
    L{end+1} = '    return out';
    L{end+1} = '';
    L{end+1} = '';
    L{end+1} = 'def save_properties_mat(folder):';
    L{end+1} = '    """Concatenate spike_prop/*properties.npz into properties.mat (as main.py does)."""';
    L{end+1} = '    prop_dir = os.path.join(folder, "spike_prop")';
    L{end+1} = '    files = sorted(';
    L{end+1} = '        glob.glob(os.path.join(prop_dir, "*properties.npz")),';
    L{end+1} = '        key=lambda p: int(next(';
    L{end+1} = '            (s for s in os.path.splitext(os.path.basename(p))[0].split("_") if s.isdigit()),';
    L{end+1} = '            "0")),';
    L{end+1} = '    )';
    L{end+1} = '    if not files:';
    L{end+1} = '        print("No spike property files in", prop_dir, "- skipping properties.mat")';
    L{end+1} = '        return';
    L{end+1} = '    out = {"properties": np.concatenate([np.load(f)["Properties"] for f in files])}';
    L{end+1} = '    titles = glob.glob(os.path.join(prop_dir, "property_titles.npz"))';
    L{end+1} = '    if titles:';
    L{end+1} = '        out["prop_titles"] = np.load(titles[0])["PropTitles"]';
    L{end+1} = '    scipy.io.savemat(os.path.join(folder, "properties.mat"), out)';
    L{end+1} = '    print("Wrote", os.path.join(folder, "properties.mat"))';
    L{end+1} = '';
    L{end+1} = '';
    L{end+1} = 'shanks = shanks_from_probe_mappings(PROBE_NAME) if PROBE_NAME else shanks_from_export()';
    L{end+1} = 'if not shanks:';
    L{end+1} = '    raise SystemExit("No channels to sort; check channel_info.csv.")';
    L{end+1} = '';
    L{end+1} = 'TIME_INTERVAL = exported_time_interval()   # seconds; narrow to sort a sub-interval';
    L{end+1} = 'print("Sorting %.3f - %.3f s" % TIME_INTERVAL)';
    L{end+1} = '';
    L{end+1} = 'for n, sh in enumerate(shanks):';
    L{end+1} = '    out_folder = HERE if len(shanks) == 1 else os.path.join(HERE, "Sh%d" % n)';
    L{end+1} = '    os.makedirs(out_folder, exist_ok=True)';
    L{end+1} = '    print("Shank %d/%d: %d channels -> %s"';
    L{end+1} = '          % (n + 1, len(shanks), len(sh["ch_order"]), out_folder))';
    L{end+1} = '    extract_spike_features(';
    L{end+1} = '        EXP_FOLDER, FILE_STRUCT, sh["ch_map"], out_folder,';
    L{end+1} = '        time_interval=TIME_INTERVAL, make_plots=MAKE_PLOTS,';
    L{end+1} = '        ch_order=sh["ch_order"], **EXTRACT_KWARGS,';
    L{end+1} = '    )';
    L{end+1} = '    save_properties_mat(out_folder)';
    L{end+1} = '';
    L{end+1} = 'print("Done. Point the GMC_Sorter GUI at:", HERE)';
    fprintf(fid, '%s\n', L{:});
    fclose(fid);
end % local_write_driver

% =========================================================================
% MATLAB -> Python literal helpers for the generated driver
% =========================================================================
function s = local_py_bool(tf)
    if tf, s = 'True'; else, s = 'False'; end
end % local_py_bool

function s = local_py_str(c)
    s = ['"' strrep(c, '"', '\"') '"'];
end % local_py_str

function s = local_py_kwargs(nv)
    % NV is a name/value cell; render it as Python keyword arguments.
    parts = cell(1, numel(nv)/2);
    for i = 1:2:numel(nv)
        name = nv{i};
        if isstring(name), name = char(name); end
        if ~ischar(name)
            error('ndi:fun:export:writeGmcSidecars:featureOptionName', ...
                'featureOptions name %d is not a character vector.', (i+1)/2);
        end
        parts{(i+1)/2} = [name '=' local_py_value(nv{i+1})];
    end
    s = strjoin(parts, ', ');
end % local_py_kwargs

function s = local_py_value(v)
    if islogical(v) && isscalar(v)
        s = local_py_bool(v);
    elseif ischar(v)
        s = local_py_str(v);
    elseif isstring(v) && isscalar(v)
        s = local_py_str(char(v));
    elseif isnumeric(v)
        elems = arrayfun(@local_py_number, v(:).', 'UniformOutput', false);
        if isscalar(v)
            s = elems{1};
        else
            s = ['[' strjoin(elems, ', ') ']'];
        end
    else
        error('ndi:fun:export:writeGmcSidecars:featureOptionValue', ...
            'featureOptions values must be numeric, logical, or character; got %s.', class(v));
    end
end % local_py_value

function s = local_py_number(x)
    if isnan(x)
        s = 'float("nan")';
    elseif isinf(x)
        if x>0, s = 'float("inf")'; else, s = 'float("-inf")'; end
    else
        s = num2str(x, '%.12g');
    end
end % local_py_number
