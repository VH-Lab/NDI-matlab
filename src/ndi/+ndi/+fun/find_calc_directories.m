function d = find_calc_directories()
% FIND_CALC_DIRECTORIES - Finds all NDI calculator toolbox directories.
%
%   D = ndi.fun.find_calc_directories()
%
%   This function finds installed NDI calculator toolboxes that follow the
%   naming convention 'NDIcalc-*-matlab'. It looks in two places:
%
%     1. Next to NDI-matlab, three directories up from 'ndi.toolboxdir'
%        (where ndi_install clones them, as listed in requirements.txt).
%     2. On the MATLAB path: any NDIcalc-*-matlab folder that a path entry
%        is in (for example, installed by ndi_setup / MatBox into a separate
%        add-ons folder).
%
%   Each folder is listed once.
%
%   Returns:
%     D (cell array): A cell array of strings, where each string is the full
%                     path to a found calculator directory. If no matching
%                     directories are found, it returns an empty cell array.
%
%   Example:
%     calc_dirs = ndi.fun.find_calc_directories();
%
    
    % Initialize output to an empty cell array for a clean exit on error
    d = {}; 

    try
        % Navigate three directories up from the NDI toolbox directory
        % This is more robust than assuming a fixed relative path.
        base_path = fileparts(fileparts(fileparts(ndi.toolboxdir)));

        if isfolder(base_path)
            % Define the search pattern for calculator directories
            dir_structs = dir(fullfile(base_path, 'NDIcalc*-matlab'));
            % Filter for actual directories (excluding files)
            dir_structs = dir_structs([dir_structs.isdir]);
            d = cellfun(@(x) fullfile(base_path, x), {dir_structs.name}', ...
                'UniformOutput', false);
        end

        % Also the root of each NDIcalc-*-matlab folder that a path entry is in
        entries = strsplit(path, pathsep);
        roots = regexp(entries, '^.*?[\\/]NDIcalc[^\\/]*-matlab(?=$|[\\/])', ...
            'match', 'once');
        roots = roots(~cellfun('isempty', roots));
        d = [d(:); roots(:)];

        d = unique(d, 'stable');
        d = d(cellfun(@isfolder, d));
        d = reshape(d, [], 1);

    catch ME
        % Catch any unexpected errors during the process
        warning('An error occurred while trying to find calculator directories: %s', ME.message);
        % Ensure d is empty on error
        d = {}; 
    end
end
