function t = ndi_document2thing(ndi_document_obj, ndi_experiment_obj)
% NDI_DOCUMENT2THING - create an NDI_THING object from an NDI_DOCUMENT
%
% T = NDI_DOCUMENT2THING(NDI_DOCUMENT_OBJ, NDI_EXPERIMENT_OBJ)
%
% Create an NDI_THING object T from an NDI_DOCUMENT object that has
% a 'thing' parameter and is related to an experiment NDI_EXPERIMENT object
% that is provided.
%
% NDI_DOCUMENT can also be an NDI_DOCUMENT ID number that will be looked up
% in the experiment.
% 

if ~isa(ndi_document_obj, 'ndi_document'),
	% try to look it up
	mydoc = ndi_experiment_obj.database_search(ndi_query('ndi_document.id','exact_string',ndi_document_obj,''));
	if numel(mydoc)==1,
		ndi_document_obj = mydoc{1};
	else,
		error(['NDI_DOCUMENT_OBJ must be of type NDI_DOCUMENT or an ID of a NDI_DOCUMENT.']);
	end;
end;

if ~isfield(ndi_document_obj.document_properties, 'thing'),
	error(['NDI_DOCUMENT_OBJ does not have a ''thing'' field.']);
end;

obj_string = ndi_document_obj.document_properties.thing.ndi_thing_class;

t = eval([obj_string '(ndi_experiment_obj, ndi_document_obj);']);

