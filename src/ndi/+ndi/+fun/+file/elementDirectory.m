function [dirPath, dirName, isLegacy] = elementDirectory(parentDir, element)
%ELEMENTDIRECTORY - the working directory for an element or probe, with legacy fallback
%
% [DIRPATH, DIRNAME, ISLEGACY] = ndi.fun.file.elementDirectory(PARENTDIR, ELEMENT)
%
% Returns the full path of the per-element working folder inside PARENTDIR
% (typically [SESSION.path filesep 'kilosort'] or similar).
%
% ELEMENT may be an ndi.element or ndi.probe object (anything that answers
% elementstring()), or the element string itself as a character vector.
%
% The platform-independent folder name from ndi.fun.file.elementDirectoryName
% is preferred. If no folder by that name exists but a folder with the legacy
% name does -- the pre-existing form that separates the element name from its
% reference with '|', which is not a legal filename character on Windows --
% then the legacy folder is returned instead, so that data written by earlier
% versions of NDI is still found. When neither exists, the new name is
% returned, so callers that create the folder create it under the new name.
%
% ISLEGACY is true when the legacy folder was chosen.
%
% Example:
%   probedir = ndi.fun.file.elementDirectory(fullfile(S.path,'kilosort'), probe);
%
% See also: ndi.fun.file.elementDirectoryName, ndi.fun.file.pathSafeName

arguments
    parentDir {mustBeTextScalar}
    element
end

parentDir = char(parentDir);

[dirName, legacyDirName] = ndi.fun.file.elementDirectoryName(element);
isLegacy = false;

if ~strcmp(dirName, legacyDirName)
    if ~isfolder(fullfile(parentDir, dirName)) && isfolder(fullfile(parentDir, legacyDirName))
        dirName = legacyDirName;
        isLegacy = true;
    end
end

dirPath = fullfile(parentDir, dirName);
