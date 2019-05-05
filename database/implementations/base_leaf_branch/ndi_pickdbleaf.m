function obj = ndi_pickdbleaf(filename)
% NDI_PICKDBLEAF - open an NDI_DBLEAF object and return the appropriate object
%
% OBJ = NDI_PICKDBLEAF(FILENAME)
%
% Reads from FILENAME (full path) to identify the type of object data contained
% within. As long as the data belongs to a class that is descendent of type
% NDI_DBLEAF, OBJ will return the object. Otherwise, an error will occur.
%

fid = fopen(filename, 'rb'); % files will consistently use big-endian
if fid<0,
	error(['Could not open the file ' filename ' for reading.']);
end;

classname = fgetl(fid);

fclose(fid);

dummyclass = eval([classname '();']);

if isa(dummyclass,'ndi_dbleaf'),
	% we have an ndi_dbleaf object, let's read it
	obj=feval(classname,filename,'OpenFile');
else, 
	error(['Could not read valid NDI_DBLEAF data from file ' filename '.']);
end;

