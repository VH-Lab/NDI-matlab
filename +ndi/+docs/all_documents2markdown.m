function t = all_documents2markdown(varargin)
% ALL_DOCUMENTS2MARKDOWN - write all NDI document types to documentation folder
%
% ndi.docs.all_documents2markdown(...)
%
% Writes the documentation information for NDI document types to the documentation
% folder. 
% 
% This function takes name/value pairs that modify its behaviour:
% |---------------------------------------------------------------------|
% | Parameter (default)             | Description                       |
% |---------------------------------|-----------------------------------|
% | spaces (4)                      | Spaces to place in the table of   |
% |                                 |   contents.                       |
% | input_path                      | Location where documents are      |
% | (ndi_globals.path.documentpath) |   stored.                         |
% | output_path([ndi_globals.path...| Where should we write the markdown|
% |  .path filesep 'docs' filesep...|   files?                          |
% |  'documents' filesep])          |                                   |
% | write_yml (1)                   | 0/1 Should we write the yml       |
% |                                 |   information (table of contents) |
% |---------------------------------------------------------------------|

ndi.globals;

spaces = 4;
input_path = ndi_globals.path.documentpath;
if input_path(end)~=filesep,
	input_path(end+1) = filesep;
end;
output_path=[ndi_globals.path.path filesep 'docs' filesep 'documents' filesep];
doc_output_path = ['documents' filesep];
doc_path = [''];
write_yml = 1;

vlt.data.assign(varargin{:});

t = [];

d = dir([input_path filesep '*.json']);

for i=1:numel(d),
	[doc_path d(i).name],
	if strcmp([doc_path d(i).name],'ndi_validate_config.json'),
		continue;
	end; % special file
	doc = ndi.document([doc_path d(i).name]);
	[md,info] = ndi.docs.document2markdown(doc);
	[input_path filesep d(i).name],
	vlt.file.createpath([output_path info.localurl]);
	vlt.file.str2text([output_path info.localurl],md);
	t = cat(2,t,[repmat(' ',1,spaces) '- ' info.localurl(1:end-3) ...
		' : ''' [doc_output_path info.localurl] '''' newline]);
end;

folders = vlt.file.dirlist_trimdots(dir([input_path]));

for i=1:numel(folders),
	t = cat(2,t,[repmat(' ',1,spaces) '- ' folders{i} ':' newline]);
	tnew = ndi.docs.all_documents2markdown(...
		'spaces',spaces+2,...
		'input_path',[input_path folders{i} filesep],...
		'output_path',[output_path folders{i} filesep],...
		'doc_output_path',[doc_output_path folders{i} filesep],...
		'doc_path',[doc_path folders{i} filesep ],...
		'write_yml',0);
	t = cat(2,t,tnew);
end;

if write_yml,
	vlt.file.str2text([output_path filesep 'documents.yml'],t);
end;
