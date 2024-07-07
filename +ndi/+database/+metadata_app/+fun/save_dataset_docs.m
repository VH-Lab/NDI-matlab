function save_dataset_docs(S, session_id, datasetInformation)
%SAVE_DATASET_DOCS - save metadata from metadata editor as ndi.documents to dataset/session
% SAVE_DATASET_DOCS(S, TEST_NAME) 
%
% inputs:
%   S - ndi.session or ndi.dataset object
%   session_id - the session id of the incoming session or dataset
%   datasetInformation - metadata collected using the metadata app
%

documentList = ndi.database.metadata_ds_core.convertFormDataToDocuments(datasetInformation, session_id);

oldDocs = S.database_search(ndi.query('openminds.matlab_type','exact_string','openminds.core.products.Dataset'));

if ~isempty(oldDocs),
	answer = questdlg('This will replace any previously saved core metadata information in the dataset or session. Continue?','Continue?','Yes','No','Yes');
else,
	answer = 'Yes';
end;

if ~strcmp(answer,'Yes'),
	return; % leave if user said no
end;

if ~isempty(oldDocs),
	antecedents = ndi.database.fun.findallantecedents(S,[],oldDocs{:});
	S.database_rm(oldDocs);
	S.database_rm(antecedents);
end;

S.database_add(documentList); 

end

