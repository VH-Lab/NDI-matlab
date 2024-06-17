function functionName = abspath2funcname(pathStr)
%abspath2funcname Get function name for .m file given as absolute pathstring
%
%   Returns package-prefixed function name given the absolute path of a .m
%   file. pathStr can be a character vector, a cell array of character
%   vectors or a string array. If the input is an array, the output will be
%   a cell array
%
%   Syntax:
%       functionName = ndi.util.abspath2funcname(pathStr)

    if isa(pathStr, 'cell')
        functionName = cellfun(@(c) ndi.util.abspath2funcname(c), ...
            pathStr, 'UniformOutput', false);
        return
    elseif isa(pathStr, 'string') && numel(pathStr) > 1
        functionName = arrayfun(@(str) ndi.util.abspath2funcname(str), ...
            pathStr, 'UniformOutput', false);
        return
    end

    % Get function name, taking package into account
    [folderPath, functionName, ext] = fileparts(pathStr);
    
    assert(strcmp(ext, '.m'), 'pathStr must point to a .m (function) file')
    
    packageName = pathstr2packagename(folderPath);
    functionName = strcat(packageName, '.', functionName);
end

function packageName = pathstr2packagename(pathStr)
%pathstr2packagename Convert a path string to a string with name of package
%
%       packageName = pathstr2packagename(pathStr)
%
%   EXAMPLE:
% 
%    pathStr =
%       '/Users/username/Documents/MATLAB/NDI-matlab/+ndi/+session'
%
%    packageName = pathstr2packagename(pathStr)
%
%    packageName =
%       'ndi.session'

    assert(isfolder(pathStr), 'Path must point to a folder.')
       
    % Split pathstr by foldernames
    splitFolderNames = strsplit(pathStr, filesep);
    
    % Find all folders that are a package
    isPackage = cellfun(@(str) strncmp(str, '+', 1), splitFolderNames );
    
    % Create output string
    packageFolderNames = splitFolderNames(isPackage);
    packageFolderNames = strrep(packageFolderNames, '+', '');
    
    packageName = strjoin(packageFolderNames, '.');
end
