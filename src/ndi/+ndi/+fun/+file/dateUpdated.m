function updatedDate = dateUpdated(fileName)
%DATEUPDATED Gets the last modification date of a file.
%
% SYNTAX:
%   updatedDate = dateUpdated(fileName)
%
% DESCRIPTION:
%   dateUpdated(fileName) returns the last modification (last updated) date
%   of the specified file as a standard MATLAB datetime object. It uses the
%   built-in, cross-platform `dir` function and is a reliable way to get
%   file metadata on any operating system.
%
% INPUTS:
%   fileName - Path to the file (string or character vector).
%
% OUTPUTS:
%   updatedDate - A datetime object representing the last modification time.
%                 Returns NaT (Not-a-Time) if the file does not exist.

% 1. Check if the file exists.
if ~isfile(fileName)
    warning('File not found: %s', fileName);
    updatedDate = NaT; % NaT stands for "Not-a-Time"
    return;
end

% 2. Get file information using the built-in dir function.
fileInfo = dir(fileName);

% 3. Convert the file's serial date number to a standard datetime object.
% The '.datenum' field is the most reliable, locale-independent source.
updatedDate = datetime(fileInfo(1).datenum, 'ConvertFrom', 'datenum');

end