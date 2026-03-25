function updatedDate = dateUpdated(pathName)
% DATEUPDATED Gets the last modification date of a file or folder.
%
% SYNTAX:
%   updatedDate = dateUpdated(pathName)
%
% DESCRIPTION:
%   Returns the last modification date of the specified file or folder 
%   as a standard MATLAB datetime object.
%
% INPUTS:
%   pathName - Path to the file or folder (string or character vector).

% 1. Check if the path exists (works for both files and folders)
if ~exist(pathName, 'file')
    warning('Path not found: %s', pathName);
    updatedDate = NaT; 
    return;
end

% 2. Get information using dir
% Note: Using dir on a specific path returns the info for that entity.
fileInfo = dir(pathName);

% 3. Extract the date
% If pathName is a folder, dir(pathName) returns contents. 
% To get the folder's own metadata, we use the '.' entry or index carefully.
% However, a safer cross-platform way to get the specific entity's info
% regardless of type is to ensure we aren't looking at folder contents:
if isfolder(pathName)
    % When dir is called on a folder, the '.' entry (index 1) 
    % represents the folder itself.
    info = fileInfo(strcmp({fileInfo.name}, '.'));
    
    % Fallback: if '.' isn't found for some reason, use the first entry
    if isempty(info); info = fileInfo(1); end
else
    % It's a file
    info = fileInfo(1);
end

% 4. Convert to datetime
updatedDate = datetime(info.datenum, 'ConvertFrom', 'datenum');

end