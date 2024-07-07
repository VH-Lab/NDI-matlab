function D = make_dataset_from_docs_files(dataset_path, dataset_reference, doc_path, files_path)
%
% [D] = make_dataset_from_docs_files(DATASET_PATH, DATASET_REFERENCE, ...
%   DOC_PATH, FILES_PATH)
%
% Build an ndi.dataset.dir from a set of downloaded documents and files.
%
% DATASET_PATH is the full path of the dataset to be made.
%
% DATASET_REFERENCE is the dataset's reference.
%
% DOC_PATH is the full path of a directory with .json files of ndi.documents.
%
% FILES_PATH is the full path of a directory with the binary data files for
% the ndi.documents.
%

verbose = 1;

d = dir([doc_path filesep '*.json']);
doc_list = {};

session_id = '';

for i=1:numel(d),
	if verbose,
		disp(['Working on document ' int2str(i) ' of ' int2str(numel(d)) '.']);
	end;
	d_json = vlt.file.textfile2char([doc_path filesep d(i).name]);
	d_struct = jsondecode(d_json);
	if isfield(d_struct,'id'), 
		d_struct = rmfield(d_struct,'id'); % remove API field
	end;
	doc_obj = ndi.document(d_struct.document_properties);
	doc_obj = doc_obj.reset_file_info();

	if isfield(d_struct.document_properties,'files'),
		if isfield(d_struct.document_properties.files,'file_info'),
		    for j=1:numel(d_struct.document_properties.files.file_info),			    
			    file_uid = d_struct.document_properties.files.file_info(j).locations(1).uid;
			    file_name = d_struct.document_properties.files.file_info(j).name;
			    if verbose,
				    disp(['Adding file ' file_name '.']);
			    end;
			    file_location = [files_path filesep file_uid];
                disp(['file_name: ' file_name ': ' file_location]);
			    doc_obj = doc_obj.add_file(file_name,file_location);
		    end;
		end;
	end;

	doc_list{i} = doc_obj;

	if strcmp(doc_list{i}.doc_class,'dataset_session_info'),
		session_id = doc_list{i}.document_properties.base.session_id;
	end;
end;

if isempty(session_id),
	error(['Could not find session_id among documents specified. (You should not see this error.)']);
end;

D = ndi.dataset.dir(dataset_reference,dataset_path,doc_list);


