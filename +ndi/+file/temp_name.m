function fname = tempname()
% TEMPNAME - return a unique temporary file name
%
% FNAME = ndi.file.tempname()
%
% Return the full path of a unique temporary file name that
% can be used by NDI programs.
%

ndi.globals;

i = ndi.ido();
uid = i.id();

fname = fullfile(ndi.common.PathConstants.TempFolder,uid);

