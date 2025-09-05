function d = find_calc_directories()
% FIND_CALC_DIRECTORIES - Finds all NDI calculator toolbox directories.
%
%   D = ndi.fun.find_calc_directories()
%
%   This function scans the MATLAB path for installed NDI calculator toolboxes
%   that follow the naming convention 'NDIcalc-*-matlab'.
%
%   It determines the search path by navigating three directories up from the
%   main NDI toolbox location ('ndi.toolboxdir'). This is necessary because the
%   toolboxes are typically installed as sibling directories.
%
%   Returns:
%     D (cell array): A cell array of strings, where each string is the full
%                     path to a found calculator directory. If no matching
%                     directories are found, or if the base path does not exist,
%                     it returns an empty cell array.
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

        if ~isfolder(base_path)
            warning('The base tool path could not be found: %s', base_path);
            return;
        end

        % Define the search pattern for calculator directories
        search_pattern = fullfile(base_path, 'NDIcalc*-matlab');
        
        % Find all items matching the pattern
        dir_structs = dir(search_pattern);

        % Filter for actual directories (excluding files)
        dir_structs = dir_structs([dir_structs.isdir]);
        
        if isempty(dir_structs)
            % This is a normal case, no warning is needed.
            return;
        end

        % Extract the names and build the full paths using fullfile for robustness
        dir_names = {dir_structs.name}';
        d = cellfun(@(x) fullfile(base_path, x), dir_names, 'UniformOutput', false);

    catch ME
        % Catch any unexpected errors during the process
        warning('An error occurred while trying to find calculator directories: %s', ME.message);
        % Ensure d is empty on error
        d = {}; 
    end
end
