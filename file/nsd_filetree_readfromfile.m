function ft = nsd_filetree_readfromfile(filename)
% NSD_FILETREE_READFROMFILE - Read an NSD_FILETREE or descendent object from file
%
% FT = NSD_FILETREE_READFROMFILE(FILENAME)
%
% Read an NSD_FILETREE or descendent object (like NSD_FILETREE_EPOCHDIR)
% from a full path filename.
%

fid = fopen(filename,'rb');
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end

classname = fgetl(fid);

fclose(fid);

ft = eval([classname '();']);

if isa(ft,'nsd_filetree'),
	% we have a filetree object, we can use it
	ft = ft.readobjectfile(filename);
else,
	error(['Could not read valid NSD_FILETREE object from file.']);
end;

