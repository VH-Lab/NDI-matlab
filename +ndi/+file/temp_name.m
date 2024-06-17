function fname = temp_name()
% TEMPNAME - return a unique temporary file name
%
% FNAME = ndi.file.temp_name()
%
% Return the full path of a unique temporary file name that
% can be used by NDI programs.
%

ndi.globals;

i = ndi.ido();
uid = i.id();

fname = fullfile(ndi_globals.path.temppath,uid);

