function folders = findCalculators(installDir, options)
% FINDCALCULATORS - folders of the NDIcalc-*-matlab repositories installed
%
%   FOLDERS = findCalculators(INSTALLDIR) returns, as a string column, the
%   NDIcalc-*-matlab folders next to NDI-matlab in INSTALLDIR (where
%   ndi_install puts them) and, unless SearchPath is false, the ones whose
%   folders are on the MATLAB path. Each folder is listed once.
%
%   FOLDERS = findCalculators(INSTALLDIR, SearchPath=false) looks in
%   INSTALLDIR only (used when checking a clone other than the running one).

    arguments
        installDir (1,1) string
        options.SearchPath (1,1) logical = true
    end

    folders = strings(0, 1);
    if strlength(installDir) > 0 && isfolder(installDir)
        d = dir(fullfile(installDir, 'NDIcalc*-matlab'));
        d = d([d.isdir]);
        folders = [folders; fullfile(string(installDir), string({d.name}'))];
    end

    if options.SearchPath
        entries = strsplit(path, pathsep);
        % The root of each NDIcalc-*-matlab folder that a path entry is in.
        roots = string(regexp(entries, '^.*?[\\/]NDIcalc[^\\/]*-matlab(?=$|[\\/])', ...
            'match', 'once'));
        roots = roots(strlength(roots) > 0);
        folders = [folders; roots(:)];
    end

    folders = unique(folders, 'stable');
    folders = folders(isfolder(folders));
end
