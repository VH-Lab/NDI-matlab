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

    % progress bar (best-effort; a failure to create it must not stop the sort).
    % ndi.gui.component.ProgressBarWindow docks into an open navigator's Progress
    % pane, or opens a standalone window if no navigator is open.
    pbtag = ['kiasort:' label];
    pbw = i_makeBar(['KIASORT: ' label], ['Sorting ' label], pbtag);
    cleanupObj = onCleanup(@() i_closeBar(pbw, pbtag)); %#ok<NASGU>

    % Three stages, each mapped to a third of the overall bar.
    cbExtract = @(pct,msg) i_updateBar(pbw, pbtag, 0/3 + pct/3);
    cbSort    = @(pct,msg) i_updateBar(pbw, pbtag, 1/3 + pct/3);
    cbData    = @(pct,msg) i_updateBar(pbw, pbtag, 2/3 + pct/3);

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

function pbw = i_makeBar(titleStr, labelStr, tag)
    pbw = [];
    try
        pbw = ndi.gui.component.ProgressBarWindow(titleStr);
        pbw.addBar('Label', labelStr, 'Tag', tag, 'Auto', false);
    catch
        pbw = [];
    end
end

function i_updateBar(pbw, tag, frac)
    try
        if ~isempty(pbw) && isvalid(pbw),
            pbw.updateBar(tag, max(0, min(1, frac)));
            drawnow limitrate;
        end;
    catch
        % a closed/invalid bar must not abort the sort
    end
end

function i_closeBar(pbw, tag)
    try
        if ~isempty(pbw) && isvalid(pbw),
            pbw.removeBar(tag);
        end;
    catch
    end
end
