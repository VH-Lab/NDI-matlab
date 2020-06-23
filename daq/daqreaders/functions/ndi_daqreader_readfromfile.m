function dr = ndi_daqreader_readfromfile(filename)
% NDI_DAQREADER_READFROMFILE - Read an NDI_DAQREADER or descendent object from file
%
% DR = NDI_DAQREADER_READFROMFILE(FILENAME)
%
% Read an NDI_DAQREADER or descendent object (like NDI_DAQREADER_EPOCHDIR)
% from a full path filename.
%

fid = fopen(filename,'rb');
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end

classname = fgetl(fid);

fclose(fid);

dr = eval([classname '();']);

if isa(dr,'ndi_daqreader'),
	% we have a daqreader object, we can use it
	dr = dr.readobjectfile(filename);
else,
	error(['Could not read valid NDI_DAQREADER object from file.']);
end;

