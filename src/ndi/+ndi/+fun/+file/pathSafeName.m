function safeName = pathSafeName(name)
%PATHSAFENAME - convert a string into a file/folder name that is legal on all platforms
%
% SAFENAME = ndi.fun.file.pathSafeName(NAME)
%
% Returns a version of NAME that is legal as a single file or folder name on
% Windows, macOS, and Linux, and that survives a trip through a URL or a zip
% archive without escaping.
%
% The returned name is drawn from the portable character set
% [A-Za-z0-9._-] only:
%   - whitespace and control characters become '_'
%   - every other character outside the portable set becomes '-'
%     (this includes the characters Windows forbids outright:  < > : " / \ | ? * )
%   - trailing '.' characters are removed (Windows silently strips them)
%   - a name that matches a Windows reserved device name (CON, PRN, AUX, NUL,
%     COM1-COM9, LPT1-LPT9), with or without an extension, is prefixed with '_'
%   - an empty result becomes 'x'
%
% This is the sanitizer used by ndi.fun.file.elementDirectoryName to build the
% per-element working directories used by the probe export and spike-sorter
% import functions. Earlier versions of NDI used ndi.element/elementstring
% directly, which embeds a ' | ' separator; '|' is not a legal filename
% character on Windows.
%
% Example:
%   ndi.fun.file.pathSafeName('ctx_|_1')   % returns 'ctx_-_1'
%
% See also: ndi.fun.file.elementDirectoryName, ndi.fun.file.elementDirectory

arguments
    name {mustBeTextScalar}
end

s = char(name);

% whitespace and control characters -> '_'
isWhiteOrControl = (double(s) < 32) | (double(s) == 127) | (s == ' ');
s(isWhiteOrControl) = '_';

% everything outside the portable set -> '-'
isPortable = (s >= 'A' & s <= 'Z') | (s >= 'a' & s <= 'z') | ...
    (s >= '0' & s <= '9') | (s == '_') | (s == '-') | (s == '.');
s(~isPortable) = '-';

% Windows drops trailing dots from file and folder names
while ~isempty(s) && s(end) == '.'
    s(end) = [];
end

if isempty(s)
    s = 'x';
end

% Windows reserved device names are illegal with or without an extension
reserved = {'CON','PRN','AUX','NUL', ...
    'COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9', ...
    'LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9'};
dotIndex = find(s == '.', 1);
if isempty(dotIndex)
    baseName = s;
else
    baseName = s(1:dotIndex-1);
end
if any(strcmpi(baseName, reserved))
    s = ['_' s];
end

safeName = s;
