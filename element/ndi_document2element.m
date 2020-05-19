function t = ndi_document2element(ndi_document_obj, ndi_session_obj)
% NDI_DOCUMENT2ELEMENT - create an NDI_ELEMENT object from an NDI_DOCUMENT
%
% T = NDI_DOCUMENT2ELEMENT(NDI_DOCUMENT_OBJ, NDI_SESSION_OBJ)
%
% Create an NDI_ELEMENT object T from an NDI_DOCUMENT object that has
% a 'element' parameter and is related to an session NDI_SESSION object
% that is provided.
%
% NDI_DOCUMENT can also be an NDI_DOCUMENT ID number that will be looked up
% in the session.
% 

if ~isa(ndi_document_obj, 'ndi_document'),
	% try to look it up
	mydoc = ndi_session_obj.database_search(ndi_query('ndi_document.id','exact_string',ndi_document_obj,''));
	if numel(mydoc)==1,
		ndi_document_obj = mydoc{1};
	else,
		error(['NDI_DOCUMENT_OBJ must be of type NDI_DOCUMENT or an ID of a NDI_DOCUMENT.']);
	end;
end;

if ~isfield(ndi_document_obj.document_properties, 'element'),
	error(['NDI_DOCUMENT_OBJ does not have a ''element'' field.']);
end;

obj_string = ndi_document_obj.document_properties.element.ndi_element_class;

t = eval([obj_string '(ndi_session_obj, ndi_document_obj);']);

