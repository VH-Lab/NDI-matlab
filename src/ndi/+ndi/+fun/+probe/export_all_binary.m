function export_all_binary(S, options)
% NDI.FUN.PROBE.EXPORT_ALL_BINARY - export NDI probes to binary format
%
% NDI.FUN.PROBE.EXPORT_ALL_BINARY(S, ...)
%
% Exports probe data from ndi in a format useable by external tools like Kilosort.
%
% Creates a folder 'kilosort' (by default) in the path of the ndi.session object S.
% A subdirectory with the name of each probe is created, and the raw data from
% the probe in binary format is stored as 'kilosort.bin'.
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default) | Description                                      |
% |---------------------|--------------------------------------------------|
% | kilosort_dir        | Name of output directory                         |
% |  ('kilosort')       |                                                  |
% | verbose (1)         | 0/1 Should we be verbose?                        |
% | multiplier(1/0.195) | Multiplier..assume Intan data                    |
% |---------------------|--------------------------------------------------|
%
%
% Example:
%
% prefix = '/Volumes/van-hooser-lab/Projects/Vikko_Laminar_Organization/Analyzed';
% expnames = {'2022-01-05'}; % just one experiment for now
% for i=1:numel(expnames),
%    S = ndi.session.dir([prefix filesep expnames{i}]);
%    ndi.fun.probe.export_all_binary(S,'verbose',1);
% end;
%

    arguments
        S
        options.kilosort_dir (1,:) char = 'kilosort'
        options.verbose (1,1) double = 1
        options.multiplier (1,1) double = 1/0.195
    end

    kilosort_dir = options.kilosort_dir;
    verbose = options.verbose;
    multiplier = options.multiplier;

    if verbose,
        disp(['About to look for probes in ' S.reference]);
    end;
    probe_list = S.getprobes('type','n-trode');

    if verbose,
        disp(['Found ' int2str(numel(probe_list)) ' probe(s) of type ''n-trode''.']);
    end;

    kilosort_path = [S.path filesep kilosort_dir];
    if ~isfolder(kilosort_path),
        mkdir(kilosort_path);
    end;

    for p=1:numel(probe_list),
        elestr = probe_list{p}.elementstring();
        if verbose,
            disp(['Now working on probe ' elestr '.']);
        end;
        elestr(find(elestr==' ')) = '_';
        this_path = [kilosort_path filesep elestr];
        if ~isfolder(this_path),
            mkdir(this_path);
        end;
        outfile = [this_path filesep 'kilosort.bin'];
        ndi.fun.probe.export_binary(probe_list{p}, outfile, 'verbose',verbose,'multiplier',multiplier);
    end;

    if verbose,
        disp(['Done processing ' S.reference]);
    end;
end
