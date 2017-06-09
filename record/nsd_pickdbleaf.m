function obj = nsd_pickdbleaf(filename)
% NSD_PICKDBLEAF - open an NSD_DBLEAF object and return the appropriate object
%
% OBJ = NSD_PICKDBLEAF(FILENAME)
%
% Reads from FILENAME (full path) to identify the type of object data contained
% within. As long as the data belongs to a class that is descendent of type
% NSD_DBLEAF, OBJ will return the object. Otherwise, an error will occur.
%

fid = fopen(filename, 'rb'); % files will consistently use big-endian
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end;

classname = fgetl(fid);

fclose(fid);

dummyclass = eval([classname '();']);

if isa(dummyclass,'nsd_dbleaf'),
	% we have an nsd_dbleaf object, let's read it
	obj=feval(classname,filename,1);
else, 
	error(['Could not read valid NSD_DBLEAF data from file ' filename '.']);
end;

