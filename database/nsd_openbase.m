function obj = nsd_openbase(filename)
% NSD_OPENBASE - open an NSD_BASE object and return the appropriate object
%
% OBJ = NSD_OPENBASE(FILENAME)
%
% Reads from FILENAME (full path) to identify the type of object data contained
% within. As long as the data belongs to a class that is descendent of type
% NSD_BASE, OBJ will return the object. Otherwise, an error will occur.
%

fid = fopen(filename, 'rb'); % files will consistently use big-endian
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end;

classname = fgetl(fid);

fclose(fid);

dummyclass = eval([classname '();']);

if isa(dummyclass,'nsd_base'),
	% we have an nsd_baseobject, let's read it
	obj=feval(classname,filename,'OpenFile');
else, 
	error(['Could not read valid NSD_BASE data from file ' filename '.']);
end;

