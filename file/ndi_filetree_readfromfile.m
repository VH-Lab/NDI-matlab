function ft = ndi_filetree_readfromfile(filename)
% NDI_FILETREE_READFROMFILE - Read an NDI_FILETREE or descendent object from file
%
% FT = NDI_FILETREE_READFROMFILE(FILENAME)
%
% Read an NDI_FILETREE or descendent object (like NDI_FILETREE_EPOCHDIR)
% from a full path filename.
%

fid = fopen(filename,'rb');
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end

classname = fgetl(fid);

fclose(fid);

ft = eval([classname '();']);

if isa(ft,'ndi_filetree'),
	% we have a filetree object, we can use it
	ft = ft.readobjectfile(filename);
else,
	error(['Could not read valid NDI_FILETREE object from file.']);
end;

