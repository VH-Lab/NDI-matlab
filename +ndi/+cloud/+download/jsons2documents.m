function ndiDocuments = jsons2documents(jsonpath, options)
%
% [NDIDOCUMENTS] = JSONS2DOCUMENTS(JSONPATH)
%
% Load a set of NDI documents from a set of downloaded JSON files
% at JSONPATH.
%

arguments
	jsonpath (1,:) char {mustBeFolder}
	options.verbose logical = true
end;

verbose = options.verbose;

d = dir([jsonpath filesep '*.json']);

ndiDocuments = {};

session_id = '';

for i=1:numel(d),
	d_json = did.file.textfile2char([jsonpath filesep d(i).name]);
	d_struct = jsondecode(d_json);
	if isfield(d_struct,'id'), 
		d_struct = rmfield(d_struct,'id'); % remove API field
	end;

	ndiDocuments{i} = ndi.document(d_struct.document_properties);

	if strcmp(ndiDocuments{i}.doc_class,'dataset_session_info'),
		session_id = ndiDocuments{i}.document_properties.base.session_id;
	end;
end;

if isempty(session_id),
	error(['Could not find session_id among documents specified. (You should not see this error.)']);
end;


