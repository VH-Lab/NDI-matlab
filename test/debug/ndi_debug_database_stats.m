function out = ndi_debug_database_stats(E)
% NDI_DEBUG_DATABASE_STATS - examine an NDI database to check for inconsistencies
%
% OUT = NDI_DEBUG_DATABASE_STATS(E)
%
% Return a bunch of documents from an NDI experiment E
%

Dmissing = ndi_finddocs_missing_dependencies(E);
Dall = E.database_search({'document_class.class_name','(.*)'});
Dall2 = E.database_search({'ndi_document.id','(.*)'}); 

sq_stim = ndi_query('','isa','stimulus_presentation.json','');
stim_doc = E.database_search(sq_stim);
if ~isempty(stim_doc),
	d_dep = ndi_findalldependencies(E,[],stim_doc{1});
end;


out = workspace2struct;
out = rmfield(out,'E');
