function S = make_session_from_docs_files(session_path, session_reference, doc_path, files_path)
%
% [S] = make_session_from_docs_files(SESSION_PATH, SESSION_REFERENCE, ...
%   DOC_PATH, FILES_PATH)
%
% Build an ndi.session from a set of downloaded documents and files.
%
% SESSION_PATH is the full path of the session to be made.
%
% DOC_PATH is the full path of a directory with .json files of ndi.documents.
%
% FILES_PATH is the full path of a directory with the binary data files for
% the ndi.documents.
%

verbose = 1;

d = dir([doc_path filesep '*.json']);

doc_list = {};

for i=1:numel(d),
	if verbose,
		disp(['Working on document ' int2str(i) ' of ' int2str(numel(d)) '.']);
	end;
	d_json = vlt.file.textfile2char([doc_path filesep d(i).name]);
	d_struct = jsondecode(d_json)
	if isfield(d_struct,'id'), 
		d_struct = rmfield(d_struct,'id'); % remove API field
	end;
	doc_obj = ndi.document(d_struct);
	doc_obj = doc_obj.reset_file_info();

	if isfield(d_struct,'files'),
		for j=1:numel(d_struct.files),
			
			file_uid = d_struct.files.file_info(j).locations(1).uid;
            file_name = d_struct.files.file_list(j);
            if verbose,
				disp(['Adding file ' file_name '.']);
			end;
            if strcmp(d_struct.files.file_info.locations.location_type,'url') 
                file_location = d_struct.files.file_list(j);
                doc_obj = doc_obj.add_file(file_name,file_location, 'location_type', 'url');
            else 
                file_location = [files_path filesep file_uid];
                doc_obj = doc_obj.add_file(file_name,file_location);
            end
			
		end;
	end;

	doc_list{i} = doc_obj;
end;

S = ndi.session.dir(session_reference,session_path);
S.database_add(doc_list);


