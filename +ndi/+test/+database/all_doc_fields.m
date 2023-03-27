function fn = all_doc_fields()
%
% [FN]  = ndi.test.database.all_doc_fields()
%
% Returns the field names (full form) of all document types.
%

json_filenames = ndi.test.database.load_all_docs();

fn = {};

for i=1:numel(json_filenames),
	t = vlt.file.textfile2char(json_filenames{i});
	s = jsondecode(t);
	s = rmfield(s,'document_class');
	fn_here = vlt.data.structfullfields(s);
	fn = cat(1,fn,fn_here);
end;

fn = unique(fn);
