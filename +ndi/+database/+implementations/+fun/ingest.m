function [b,msg] = ingest(source_filename_list, destination_filename_list, to_delete_list)
% INGEST - actually ingest files from an ndi_document file_info into a database
%
% [B,MSG] = ndi.database.implementations.fun.ingest(SOURCE_FILENAME_LIST, ...
%     DESTINATION_FILENAME_LIST, TO_DELETE_LIST]);
%
% Ingest files into a database. SOURCE_FILENAME_LIST, DESTINATION_FILENAME_LIST, and
% TO_DELETE_LIST are typically returned from ndi.database.implementations.fun.ingest_plan().
% SOURCE_FILENAME_LIST are a list of the source files to be copied, and DESTINATION_FILENAME_LIST
% are a list of locations to be written to. TO_DELETE_LIST is a list of files to be deleted.
%
% B is 1 if the operation is successful, 0 otherwise. MSG is empty ('') if there is no error and
% contains a description of the error that occurred if there was an error.
%
% See also: ndi.database.implementations.fun.ingest_plan()
%

b = 1;
msg = '';

for i=1:numel(source_filename_list),
	try,
 		% now actually ingest, yum yum
		copyfile(source_filename_list{i},destination_filename_list{i});
	catch,
		b = 0;
		msg = ['Copying: ' lasterr];
	end;
end;

for i=1:numel(to_delete_list),
	try,
		delete(to_delete_list{i});
	catch,
		b = 0;
		msg = ['Deleting: ' lasterr];
	end;
end;


