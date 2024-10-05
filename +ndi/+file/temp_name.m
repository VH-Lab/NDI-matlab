function fname = temp_name()
% TEMP_NAME - return a unique temporary file name
%
% FNAME = ndi.file.temp_name()
%
% Return the full path of a unique temporary file name that
% can be used by NDI programs.
%

i = ndi.ido();
uid = i.id();

fname = fullfile(ndi.common.PathConstants.TempFolder,uid);

