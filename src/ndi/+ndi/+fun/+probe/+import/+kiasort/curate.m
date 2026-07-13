function fig = curate(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.CURATE - open KIASORT's curation UI for a probe's sort
%
% FIG = NDI.FUN.PROBE.IMPORT.KIASORT.CURATE(S, PROBE, ...)
%
% Opens KIASORT's interactive curation interface (kiaSort_curate_results) in a new
% window for the KIASORT results of PROBE in the ndi.session S. Curation is
% non-destructive to the raw sort - it writes '*_curated.h5' files - and can be run
% as many times as you like; import the curated result afterwards with
% ndi.fun.probe.import.kiasort.probe(..., 'curated', true).
%
% KIASORT must be on the MATLAB path (kiaSort_curate_results and the kiaSort_*_configs
% functions must be visible). The probe must already have been sorted (its KIASORT
% output folder must contain RES_Sorted); run it with ndi.fun.probe.import.kiasort.run.
%
% Name/value pairs:
%   kiasort_dir ('kiasort')     - directory (within S.path) holding the export/output.
%   binaryFileName ('kiasort.bin') - the exported binary in the probe's folder.
%   subdir ('kiasort_output')   - the KIASORT output subfolder (holds RES_Sorted).
%
% Returns FIG, the uifigure hosting the curation UI.
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.RUN, NDI.FUN.PROBE.IMPORT.KIASORT.PROBE

    arguments
        S
        probe
        options.kiasort_dir (1,:) char = 'kiasort'
        options.binaryFileName (1,:) char = 'kiasort.bin'
        options.subdir (1,:) char = 'kiasort_output'
    end

    needed = {'kiaSort_curate_results','kiaSort_main_configs', ...
        'kiaSort_extended_configs','kiaSort_hidden_configs'};
    for i=1:numel(needed),
        if exist(needed{i},'file')~=2,
            error(['%s was not found on the MATLAB path. Add KIASORT to the path ' ...
                '(e.g. addpath(genpath(''/path/to/KIASORT''))) before curating.'], needed{i});
        end;
    end;

    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    probedir = fullfile(S.path, options.kiasort_dir, elestr);
    outputFolder = fullfile(probedir, options.subdir);
    if ~isfolder(fullfile(outputFolder,'RES_Sorted')),
        error(['No KIASORT results found for probe %s (looked for %s). Run KIASORT first ' ...
            'with ndi.fun.probe.import.kiasort.run.'], elestr, fullfile(outputFolder,'RES_Sorted'));
    end;

    % Build the KIASORT config the same way run_kiasort_nogui does, then point it at
    % this probe's output folder (the curation UI reads RES_Sorted / Sorted_Samples
    % from cfg.outputFolder).
    cfg = kiaSort_main_configs();
    cfg = kiaSort_extended_configs(cfg);
    cfg = kiaSort_hidden_configs(cfg);

    et = probe.epochtable();
    nch = ndi.fun.probe.channelCount(probe);
    if isempty(nch) && ~isempty(et),
        t0 = et(1).t0_t1{1}(1);
        [d,~] = probe.readtimeseries(et(1).epoch_id, t0, t0);
        nch = size(d,2);
    end;
    if ~isempty(nch), cfg.numChannels = nch; end;
    if ~isempty(et), cfg.samplingFrequency = probe.samplerate(et(1).epoch_id); end;
    cfg.dataType     = 'int16';
    cfg.fullFilePath = fullfile(probedir, options.binaryFileName);
    cfg.inputFolder  = probedir;
    cfg.outputFolder = outputFolder;
    cfg.altResFolder = ''; % curation checks this; ensure it exists and is empty

    c = ndi.gui.cloudColors();
    fig = uifigure('Name', ['KIASORT curation: ' elestr], ...
        'Position', [100 100 1150 720], 'Color', c.offWhite, ...
        'Tag', 'ndi.fun.probe.import.kiasort.curate');
    panel = uigridlayout(fig, [1 1], 'Padding', [0 0 0 0]);

    kiaSort_curate_results(cfg, panel, c.offWhite, fig);
end
