function folderPath = toolboxdir()
% TOOLBOXDIR Returns the root directory of the NDI toolbox
%
% FOLDERPATH = TOOLBOXDIR()
%
% Returns the absolute path to the root directory of the NDI toolbox.
% This function is useful for locating resources within the toolbox
% structure regardless of the current working directory.
%
% Outputs:
%   FOLDERPATH - A string containing the absolute path to the root
%                directory of the NDI toolbox
%
% Example:
%   root_dir = ndi.toolboxdir();
%   disp(['NDI toolbox is installed at: ' root_dir]);
%
% See also:
%   FILEPARTS, MFILENAME
%

    folderPath = fileparts(fileparts(mfilename('fullpath')));
end
