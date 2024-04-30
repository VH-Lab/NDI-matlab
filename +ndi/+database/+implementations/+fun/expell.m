function [b,msg] = expell(to_delete_list)
% EXPELL - actually expell files from an ndi_document file_info from a database
%
% [B,MSG] = ndi.database.implementations.fun.ingest(TO_DELETE_LIST]);
%
% Expell files from a database. TO_DELETE_LIST is a list of files to be deleted.
%
% B is 1 if the operation is successful, 0 otherwise. MSG is empty ('') if there is no error and
% contains a description of the error that occurred if there was an error.
%
% See also: ndi.database.implementations.fun.expell_plan()
%

b = 1;
msg = '';

if isempty(to_delete_list),
    return;
end;

for i=1:numel(to_delete_list),
	try,
		delete(to_delete_list{i});
	catch,
		b = 0;
		msg = ['Deleting: ' lasterr];
	end;
end;


