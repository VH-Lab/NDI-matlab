function [dirName, legacyDirName] = elementDirectoryName(element)
%ELEMENTDIRECTORYNAME - the folder name that NDI uses for an element or probe
%
% [DIRNAME, LEGACYDIRNAME] = ndi.fun.file.elementDirectoryName(ELEMENT)
%
% Returns the name of the per-element working folder used by the probe export
% and spike-sorter import functions (see ndi.fun.probe.export.oneProbe,
% ndi.fun.probe.import.kilosort.probe, ndi.fun.probe.import.kiasort.probe).
%
% ELEMENT may be an ndi.element or ndi.probe object (anything that answers
% elementstring()), or the element string itself as a character vector.
%
% DIRNAME is the current, platform-independent name: the element string with
% whitespace turned into '_' and every character outside [A-Za-z0-9._-] turned
% into '-' by ndi.fun.file.pathSafeName. For an element named 'ctx' with
% reference 1 this is 'ctx_-_1'.
%
% LEGACYDIRNAME is the name that versions of NDI before this change wrote:
% the element string with whitespace turned into '_' and nothing else changed,
% which for the same element is 'ctx_|_1'. The '|' character is not legal in a
% filename on Windows. LEGACYDIRNAME is returned so that callers can keep
% reading data that was written under the old name; use
% ndi.fun.file.elementDirectory to do that resolution.
%
% See also: ndi.fun.file.elementDirectory, ndi.fun.file.pathSafeName,
%   ndi.element/elementstring

arguments
    element
end

if ischar(element) || isstring(element)
    elementString = char(element);
else
    elementString = char(element.elementstring());
end

legacyDirName = elementString;
legacyDirName(legacyDirName == ' ') = '_';

dirName = ndi.fun.file.pathSafeName(legacyDirName);
