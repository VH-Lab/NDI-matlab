function run(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.RUN - run JRCLUST spike detection and sorting on an NDI probe
%
% NDI.FUN.PROBE.IMPORT.JRCLUST.RUN(S, PROBE, ...)
%
% Runs JRCLUST's spike detection and/or sorting on the ndi.probe (or ndi.element)
% PROBE of the ndi.session S, using the parameter file that
% NDI.FUN.PROBE.EXPORT.JRCLUST wrote for it. This is the equivalent of
%
%       jrc detect [S.path]/.JRCLUST/[element string]/jrclust.prm
%       jrc sort   [S.path]/.JRCLUST/[element string]/jrclust.prm
%
% run from the command line, and it is what NDI.GUI.APP.JRCLUST's Detect and Sort
% buttons call. JRCLUST reads the probe's sample data directly out of NDI (the
% parameter file uses the 'ndi' recording format), so no data is copied first.
%
% Results are written to JRCLUST's results file ([...]/jrclust_res.mat). Annotate
% the units next with NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE, then bring them into NDI
% with NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE.
%
% Sorting a long recording takes a long time; JRCLUST reports its progress in the
% command window.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | stage ('detect-sort')    | Which stage(s) to run: 'detect' (spike detection    |
% |                          |   only), 'sort' (clustering only; spikes must have  |
% |                          |   been detected) or 'detect-sort' (both).           |
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.JRCLUST, NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.TRACES, NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.jrclust.run(S, p{1});
%

    arguments
        S
        probe
        options.stage (1,:) char {mustBeMember(options.stage,{'detect','sort','detect-sort'})} = 'detect-sort'
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
        options.verbose (1,1) double = 1
    end

    prmFile = ndi.fun.probe.import.jrclust.requireprm(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);

    switch options.stage,
        case 'detect',      stages = {'detect'};
        case 'sort',        stages = {'sort'};
        case 'detect-sort', stages = {'detect','sort'};
    end;

    % Sorting reads the features that detection wrote; if they are gone, JRCLUST
    % stops inside SortController with 'cannot sort without features', so check here
    % and say what to do about it.
    if any(strcmp(stages,'sort')) && ~any(strcmp(stages,'detect')),
        P = ndi.fun.probe.import.jrclust.paths(S, probe, ...
            'jrclustDir', options.jrclustDir, 'prmName', options.prmName);
        if ~isfile(P.featuresFile),
            error('ndi:fun:probe:import:jrclust:run:noFeatures', ...
                ['The spike features JRCLUST needs to sort are not on disk (%s). ' ...
                'Detect the spikes first (stage ''detect'' or ''detect-sort''); if ' ...
                'they were detected before, the intermediate .jrc files have since ' ...
                'been removed and detection has to be run again.'], P.featuresFile);
        end;
    end;

    for i=1:numel(stages),
        if options.verbose,
            disp(['Running ''jrc ' stages{i} ' ' prmFile '''...']);
        end;
        try
            jrc(stages{i}, prmFile);
        catch ME
            error('ndi:fun:probe:import:jrclust:run:failed', ...
                'JRCLUST ''%s'' failed for %s: %s', stages{i}, prmFile, ME.message);
        end;
    end;

    if options.verbose,
        disp(['JRCLUST ' options.stage ' finished for ' prmFile '.']);
    end;

end % run()
