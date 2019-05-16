function t = ndi_document2thing(ndi_document_obj, ndi_experiment_obj)
% NDI_DOCUMENT2THING - create an NDI_THING object from an NDI_DOCUMENT
%
% T = NDI_DOCUMENT2THING(NDI_DOCUMENT_OBJ, NDI_EXPERIMENT_OBJ)
%
% Create an NDI_THING object T from an NDI_DOCUMENT object that has
% a 'thing' parameter and is related to an experiment NDI_EXPERIMENT object
% that is provided.
% 

if ~isa(ndi_document_obj, 'ndi_document'),
	error(['NDI_DOCUMENT_OBJ must be of type NDI_DOCUMENT.']);
end;

if ~isfield(ndi_document_obj.document_properties, 'thing'),
	error(['NDI_DOCUMENT_OBJ does not have a ''thing'' field.']);
end;

obj_string = ndi_document_obj.document_properties.thing.ndi_thing_class;

t = eval([obj_string '(ndi_document_obj, ndi_experiment_obj);']);

