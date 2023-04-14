function dbfilename = doc2ingesteddbfilename(ndi_document_obj, filename)
%
% DBFILENAME = DOC2INGESTEDDBFILENAME(NDI_DOCUMENT_OBJ, FILENAME)
%
% Given an ndi.document object and its internal binary FILENAME, and if the
% file exists in an ingested form, return the full path filename in the database.
%

dbfilename = '';

[b,msg,fi_index] = ndi_document_obj.is_in_file_list(filename);

if b==0,
	error(['Document does not have a file ' filename '.']);
end;

 % if we are here, we know we have files.file_info

locs = ndi_document_obj.document_properties.files.file_info(fi_index).locations;

for i=1:numel(locs),

	if locs(i).ingest==1, % we found one we can open locally
		dbfilename = locs(i).uid;
		return;
	end;
end;

 % if we are here, we didn't find one

error(['Could find no ingested file for ' filename '.']);


