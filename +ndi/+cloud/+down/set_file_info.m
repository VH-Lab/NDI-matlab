function newDocStruct = set_file_info(docStruct,mode)
% SET_FILE_INFO - set file info parameters for different modes
%
% NEWDOCSTRUCT = SET_FILE_INFO(DOCSTRUCT, MODE)
%
% Given a document structure downloaded from ndi.cloud.api.documents.get_documents,
% set the 'delete_original' and 'ingest' fields as appropriate to the mode.
%
% The MODE can be 'local' or 'hybrid'. If MODE is 'local', then
%   'delete_original' and 'ingest' are set to 1. Otherwise,
%   the are set to 0.
%

if isfield(docStruct,'files'),
	if isfield(docStruct.files,'file_info'),
		for i=1:numel(docStruct.files.file_info),
			switch mode,
				case 'local',
					docStruct.files.file_info(i).delete_original = 1;
					docStruct.files.file_info(i).ingest = 1;
				otherwise,
					docStruct.files.file_info(i).delete_original = 0;
					docStruct.files.file_info(i).ingest = 0;
			end;
		end;
	end;
end;


