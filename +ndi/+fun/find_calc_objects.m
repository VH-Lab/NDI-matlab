function o = find_calc_objects()
% ndi.fun.find_calc_objects - find all ndi.calc.* objects in NDI and in extensions
%
% O = ndi.fun.find_calc_objects()
%
% Return all known ndi.calc.* objects that are of type 'ndi.calculator'.
%
%

ndi.globals;

myfiles = vlt.file.findfilegroups([ndi_globals.path.path filesep '+ndi' filesep '+calc'] ,{'.*\.m$'});
for i=1:numel(myfiles),
	myfiles{i} = myfiles{i}{1};
end;

for i=1:numel(ndi_globals.path.calcdoc),
	parentparent = fileparts(fileparts(ndi_globals.path.calcdoc{i}));
	if vlt.file.isfolder(parentparent),
		mynewfiles = vlt.file.findfilegroups([parentparent filesep '+ndi' filesep '+calc'], {'.*\.m$'});
		for j=1:numel(mynewfiles),
			mynewfiles{j} = mynewfiles{j}{1};
		end;
		myfiles = cat(1,myfiles,mynewfiles);
	end;
end;

for i=1:numel(myfiles),
	ind = strfind(myfiles{i},'+ndi');
	myfiles{i} = myfiles{i}(ind+1:end);
	myfiles{i} = strrep(myfiles{i},[filesep '+'],'.');
	myfiles{i} = strrep(myfiles{i},[filesep],'.');
	myfiles{i} = myfiles{i}(1:end-2); % trim .m
end;

o = myfiles;

inds = [];
for i=1:numel(o),
	if ~isempty(intersect({'ndi.calculator'},superclasses(o{i}))),
		inds(end+1) = i;
	end;
end;

o = o(inds);
