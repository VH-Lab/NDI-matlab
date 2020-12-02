function t = all_documents2markdown(varargin)
% ALL_DOCUMENTS2MARKDOWN - write all NDI document types to documentation folder
%
% 
% 

ndi.globals;

spaces = 4;
input_path = ndi_globals.path.documentpath;
output_path=[ndi_globals.path.path filesep 'docs' filesep 'documents' filesep];
doc_output_path = ['documents' filesep];
write_yml = 1;

vlt.data.assign(varargin{:});

t = [];

d = dir([input_path filesep '*.json']);

for i=1:numel(d),
	[md,info] = ndi.database.fun.document2markdown(...
		[input_path filesep d(i).name]);
	vlt.file.createpath([output_path info.localurl]);
	vlt.file.str2text([output_path info.localurl],md);
	t = cat(2,t,[repmat(' ',1,spaces) info.localurl ...
		' : ''' [doc_output_path info.localurl] '''' newline]);
end;

folders = vlt.file.dirlist_trimdots(dir([input_path]));

for i=1:numel(folders),
	tnew = ndi.database.fun.all_documents2markdown(...
		'spaces',spaces+2,...
		'input_path',[input_path filesep folders{i} filesep],...
		'output_path',[output_path filesep folders{i} filesep],...
		'doc_output_path',[doc_output_path filesep folders{i} filesep],...
		'write_ylm',0);
	t = cat(2,t,tnew);
end;

if write_yml,
	vlt.file.str2text([ndi_globals.path.path filesep 'documents' filesep 'documents.yml']);
end;
