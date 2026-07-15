function session(S, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.SESSION - import KIASORT results for all probes in a session
%
% NDI.FUN.PROBE.IMPORT.KIASORT.SESSION(S, ...)
%
% For each 'n-trode' probe in the ndi.session S, imports the KIASORT spike sorting
% results by calling NDI.FUN.PROBE.IMPORT.KIASORT.PROBE. This is the import-side
% analog of NDI.FUN.PROBE.EXPORT.ALL_BINARY.
%
% The KIASORT output for each probe is expected in
%       [S.path]/[kiasort_dir]/[probe_elementstring]/[subdir]/RES_Sorted/
% (the same layout produced by NDI.FUN.PROBE.EXPORT.ALL_BINARY, with KIASORT run
% using each probe's directory as its output folder). Probes whose KIASORT output
% is missing are skipped with a warning.
%
% This function takes the same name/value pairs as NDI.FUN.PROBE.IMPORT.KIASORT.PROBE:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kiasort_dir ('kiasort')  | Name of the directory holding the KIASORT output    |
% | subdir                   | Subfolder within each probe's directory that is the |
% |  ('kiasort_output')      |   KIASORT output folder (containing RES_Sorted/).   |
% | noSubFolder (false)      | If true, ignore 'subdir' and read directly from the |
% |                          |   probe's directory.                                |
% | curated (false)          | Prefer KIASORT's '_curated' output files if present.|
% | quality_labels (["good"])| String array of curation labels to import           |
% | quality_values ([1])     | quality_number for each label (parallel array)      |
% | waveform_source          | 'samples' or 'none'                                 |
% |   ('samples')            |                                                     |
% | force (0)                | Re-import even if the checksum is unchanged          |
% | dryRun (false)           | Report what would be imported without changing the  |
% |                          |   database                                          |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE, NDI.FUN.PROBE.EXPORT.ALL_BINARY
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    ndi.fun.probe.import.kiasort.session(S);
%

    arguments
        S
        options.kiasort_dir (1,:) char = 'kiasort'
        options.subdir (1,:) char = 'kiasort_output'
        options.noSubFolder (1,1) logical = false
        options.curated (1,1) logical = false
        options.quality_labels (1,:) string = "good"
        options.quality_values (1,:) double = 1
        options.waveform_source (1,:) char {mustBeMember(options.waveform_source,{'samples','none'})} = 'samples'
        options.force (1,1) double = 0
        options.dryRun (1,1) logical = false
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
        kdir = fullfile(S.path, options.kiasort_dir, elestr, subdir);
        if ~isfolder(fullfile(kdir,'RES_Sorted')),
            warning(['Skipping probe ' elestr ': no KIASORT output found in ' fullfile(kdir,'RES_Sorted') '.']);
            continue;
        end;
        ndi.fun.probe.import.kiasort.probe(S, probe_list{p}, ...
            'kiasort_dir', options.kiasort_dir, ...
            'subdir', options.subdir, ...
            'noSubFolder', options.noSubFolder, ...
            'curated', options.curated, ...
            'quality_labels', options.quality_labels, ...
            'quality_values', options.quality_values, ...
            'waveform_source', options.waveform_source, ...
            'force', options.force, ...
            'dryRun', options.dryRun, ...
            'verbose', options.verbose);
    end;

    if verbose,
        disp(['Done importing KIASORT results for ' S.reference '.']);
    end;

end
