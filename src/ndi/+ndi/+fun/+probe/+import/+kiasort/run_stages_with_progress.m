function run_stages_with_progress(binaryfile, outputFolder, channelMapFile, cfg_overrides, label, verbose)
% NDI.FUN.PROBE.IMPORT.KIASORT.RUN_STAGES_WITH_PROGRESS - run KIASORT's stages with a progress bar
%
% NDI.FUN.PROBE.IMPORT.KIASORT.RUN_STAGES_WITH_PROGRESS(BINARYFILE, OUTPUTFOLDER, ...
%    CHANNELMAPFILE, CFG_OVERRIDES, LABEL, VERBOSE)
%
% Mirrors KIASORT's run_kiasort_nogui, but calls the three KIASORT stages directly
% (kiaSort_main_extract_sample_data, kiaSort_main_sort_samples, kiaSort_main_sortData)
% and passes each a 'progressfcn' callback that drives an NDI progress bar, so the
% user sees progress while the sort runs. Used by ndi.fun.probe.import.kiasort.run
% when 'progressbar' is true; otherwise run() calls run_kiasort_nogui.
%
% This deliberately duplicates run_kiasort_nogui's setup (config build, channel-map
% load, num_channel_extract derivation) so it stays a drop-in that adds progress
% without modifying KIASORT.
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.RUN

    if nargin<6, verbose = 1; end

    % Build the config exactly as run_kiasort_nogui does, then overlay overrides.
    cfg = kiaSort_main_configs();
    cfg = kiaSort_extended_configs(cfg);
    cfg = kiaSort_hidden_configs(cfg);
    fn = fieldnames(cfg_overrides);
    for i=1:numel(fn),
        cfg.(fn{i}) = cfg_overrides.(fn{i});
    end;
    cfg.inputFolder  = fileparts(binaryfile);
    cfg.fullFilePath = binaryfile;
    cfg.outputFolder = outputFolder;

    hp = sorting_hyperparameters_in();

    % channel map (mirror run_kiasort_nogui)
    channel_mapping = [];
    channel_inclusion = [];
    channel_locations = [];
    if ~isempty(channelMapFile) && isfile(channelMapFile),
        cfg.channel_info = channelMapFile;
        [channel_mapping, channel_locations, channel_inclusion] = load_channel_map(channelMapFile, cfg);
    elseif isfield(cfg,'numChannels'),
        channel_mapping   = 1:cfg.numChannels;
        channel_inclusion = true(cfg.numChannels, 1);
        channel_locations = [];
    end;
    cfg.num_channel_extract = derive_num_channel_extract(channel_locations, ...
        cfg.waveform_radius, cfg.num_channel_extract);

    % progress bar (best-effort; a failure to create it must not stop the sort)
    pb = []; pbfig = [];
    try
        pbfig = figure('Name', ['KIASORT: ' label], 'NumberTitle', 'off', ...
            'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', ...
            'Position', [500 500 560 90]);
        pb = ndi.gui.component.NDIProgressBar('Parent', pbfig, ...
            'Message', 'Starting...', 'Text', ['Sorting ' label '...']);
    catch
        pb = [];
        if ~isempty(pbfig) && isvalid(pbfig), close(pbfig); end
        pbfig = [];
    end
    cleanupObj = onCleanup(@() i_closeBar(pbfig)); %#ok<NASGU>

    % Three stages, each mapped to a third of the overall bar.
    cbExtract = @(pct,msg) i_updateBar(pb, 0/3 + pct/3, msg);
    cbSort    = @(pct,msg) i_updateBar(pb, 1/3 + pct/3, msg);
    cbData    = @(pct,msg) i_updateBar(pb, 2/3 + pct/3, msg);

    kiaSort_main_extract_sample_data(cfg.fullFilePath, cfg.outputFolder, cfg, ...
        'channel_mapping',   channel_mapping, ...
        'channel_inclusion', channel_inclusion, ...
        'channel_locations', channel_locations, ...
        'progressfcn',       cbExtract);

    if ~cfg.sort_only,
        kiaSort_main_sort_samples(cfg.outputFolder, cfg, hp, 'progressfcn', cbSort);
    end;

    kiaSort_main_sortData(cfg.fullFilePath, cfg.outputFolder, cfg, 'progressfcn', cbData);

end

function i_updateBar(pb, frac, msg)
    try
        if ~isempty(pb),
            pb.Value = max(0, min(1, frac));
            if nargin>=3 && ~isempty(msg),
                pb.Message = char(msg);
            end;
            drawnow limitrate;
        end;
    catch
        % a closed/invalid bar must not abort the sort
    end
end

function i_closeBar(pbfig)
    if ~isempty(pbfig) && isvalid(pbfig),
        close(pbfig);
    end;
end
