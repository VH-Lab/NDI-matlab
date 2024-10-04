function [docs,target_path] = extract_doc_files(ndi_session_obj, target_path)
% EXTRACT_DOC_FILES - extract a copy of all ndi.documents and files to path
%
% [DOCS,TARGET_PATH] = EXTRACT_DOC_FILES(NDI_SESSION_OBJ, TARGET_PATH)
%
% Copies the ndi.document objects from an ndi.session object or an
% ndi.dataset object. The files associated with the documents DOCS
% will be placed in the directory TARGET_PATH.
% 
% If TARGE_TPATH is not given, then a subdirectory inside
% ndi.common.PathConstants.TempFolder is used and the path is returned as
% an output.
%

if nargin<2,
	ndi.globals();
	target_path = ndi.file.temp_name();
	mkdir(target_path);
end;

q_all = ndi.query('','isa','base');

d = ndi_session_obj.database_search(q_all);

files_I_made = {};

docs = d;

for i = 1:numel(d),
	if isfield(d{i}.document_properties,'files'),
		file_info = did.datastructures.emptystruct('file_name','fullpathfilename');
		fl = docs{i}.current_file_list();
		docs{i} = docs{i}.reset_file_info;
		for f = 1:numel(fl),
			file_info_here = [];
			file_info_here.file_name = fl{f};
			doc_id = d{i}.document_properties.base.id;
			file_obj = ndi_session_obj.database_openbinarydoc(doc_id,file_info_here.file_name);
			[~,uid,~] = fileparts(file_obj.fullpathfilename);
			file_info_here.fullpathfilename = [target_path filesep uid];
			try,
				copyfile(file_obj.fullpathfilename,file_info_here.fullpathfilename);
				files_I_made{end+1} = file_info_here.fullpathfilename;
			catch,
				% probably disk space error or something, bail out
				% try to recover some of the user's precious disk space
				for j=1:numel(files_I_made),
					delete(files_I_made{j});
				end;
				error(['Extraction failed: ' lasterr]);
			end;
			
			file_info(end+1) = file_info_here;
			docs{i} = docs{i}.add_file(file_info_here.file_name,file_info_here.fullpathfilename);
		end;
	end;
end;


