function json_filenames = load_all_docs()
%
% [JSON_FILENAMES]  = ndi.test.database.load_all_docs()
%
% Searches for all JSON blank document definition files.
% The full paths of these files are returned as a cell array
% of strings.
%

ndi.globals;

json_docs = vlt.file.findfilegroups(ndi_globals.path.documentpath,...
	{'.*\.json\>'});

for i=1:numel(ndi_globals.path.calcdoc),
	more_json_docs = vlt.file.findfilegroups(ndi_globals.path.calcdoc{i},...
		{'.*\.json\>'});
	json_docs = cat(1,json_docs,more_json_docs);
end;

json_filenames = {};

for i=1:numel(json_docs),
	[parentdir,filename,ext] = fileparts(json_docs{i}{1});
	if filename(1)~='.', % ignore hidden files
		json_filenames = cat(1,json_filenames,json_docs{i}{1});
	end;
end;


