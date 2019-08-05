function ft = ndi_filenavigator_readfromfile(filename)
% NDI_FILENAVIGATOR_READFROMFILE - Read an NDI_FILENAVIGATOR or descendent object from file
%
% FT = NDI_FILENAVIGATOR_READFROMFILE(FILENAME)
%
% Read an NDI_FILENAVIGATOR or descendent object (like NDI_FILENAVIGATOR_EPOCHDIR)
% from a full path filename.
%

fid = fopen(filename,'rb');
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end

classname = fgetl(fid);

fclose(fid);

ft = eval([classname '();']);

if isa(ft,'ndi_filenavigator'),
	% we have a filenavigator object, we can use it
	ft = ft.readobjectfile(filename);
else,
	error(['Could not read valid NDI_FILENAVIGATOR object from file.']);
end;

