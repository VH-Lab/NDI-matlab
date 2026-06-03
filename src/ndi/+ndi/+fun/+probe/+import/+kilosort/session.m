function session(S, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.SESSION - import curated Kilosort results for all probes in a session
%
% NDI.FUN.PROBE.IMPORT.KILOSORT.SESSION(S, ...)
%
% For each 'n-trode' probe in the ndi.session S, imports the curated Kilosort
% spike sorting results by calling NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE. This is the
% import-side analog of NDI.FUN.PROBE.EXPORT.ALL_BINARY.
%
% The Kilosort output for each probe is expected in
%       [S.path]/[kilosort_dir]/[probe_elementstring]/
% (the same layout produced by NDI.FUN.PROBE.EXPORT.ALL_BINARY). Probes whose
% kilosort directory or curated files are missing are skipped with a warning.
%
% This function takes the same name/value pairs as NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kilosort_dir ('kilosort')| Name of the directory holding the kilosort output   |
% | subdir                   | Subfolder within each probe's directory holding the |
% |  ('kilosort_output')     |   curated files. '' or noSubFolder reads directly   |
% |                          |   from the probe's directory.                       |
% | noSubFolder (false)      | If true, ignore 'subdir' and read directly from the |
% |                          |   probe's directory.                                |
% | quality_labels           | String array of curation labels to import           |
% |   (["good" "mua"])        |                                                     |
% | quality_values ([1 4])   | quality_number for each label (parallel array)      |
% | waveform_source          | 'templates' or 'none'                               |
% |   ('templates')          |                                                     |
% | force (0)                | Re-import even if the checksum is unchanged          |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.EXPORT.ALL_BINARY
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    ndi.fun.probe.import.kilosort.session(S);
%

    arguments
        S
        options.kilosort_dir (1,:) char = 'kilosort'
        options.subdir (1,:) char = 'kilosort_output'
        options.noSubFolder (1,1) logical = false
        options.quality_labels (1,:) string = ["good" "mua"]
        options.quality_values (1,:) double = [1 4]
        options.waveform_source (1,:) char {mustBeMember(options.waveform_source,{'templates','none'})} = 'templates'
        options.force (1,1) double = 0
        options.verbose (1,1) double = 1
    end

    verbose = options.verbose;

    if verbose,
        disp(['Looking for n-trode probes in ' S.reference '...']);
    end;
    probe_list = S.getprobes('type','n-trode');
    if verbose,
        disp(['Found ' int2str(numel(probe_list)) ' probe(s) of type ''n-trode''.']);
    end;

    subdir = options.subdir;
    if options.noSubFolder,
        subdir = '';
    end;

    for p=1:numel(probe_list),
        elestr = probe_list{p}.elementstring();
        elestr(elestr==' ') = '_';
        kdir = fullfile(S.path, options.kilosort_dir, elestr, subdir);
        if ~isfolder(kdir) || ~isfile(fullfile(kdir,'spike_times.npy')),
            warning(['Skipping probe ' elestr ': no kilosort output found in ' kdir '.']);
            continue;
        end;
        ndi.fun.probe.import.kilosort.probe(S, probe_list{p}, ...
            'kilosort_dir', options.kilosort_dir, ...
            'subdir', options.subdir, ...
            'noSubFolder', options.noSubFolder, ...
            'quality_labels', options.quality_labels, ...
            'quality_values', options.quality_values, ...
            'waveform_source', options.waveform_source, ...
            'force', options.force, ...
            'verbose', options.verbose);
    end;

    if verbose,
        disp(['Done importing kilosort results for ' S.reference '.']);
    end;

end
