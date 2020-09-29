function o = ndi_document2ndi_object(ndi_document_obj, ndi_session_obj)
% NDI_DOCUMENT2NDI_OBJECT - create an NDI object from an NDI_DOCUMENT
%
% O = ndi.database.fun.ndi_document2ndi_object(NDI_DOCUMENT_OBJ, NDI_SESSION_OBJ)
%
% Create an NDI object O from an ndi.document object and a related
% ndi.session object.
%
% ndi.document can also be an ndi.document ID number that will be looked up
% in the session.
% 


 % TODO: what if ndi_session_obj does not match the current session?

if ~isa(ndi_document_obj, 'ndi.document'),
	% try to look it up
	mydoc = ndi_session_obj.database_search(ndi.query('ndi_document.id','exact_string',ndi_document_obj,''));
	if numel(mydoc)==1,
		ndi_document_obj = mydoc{1};
	else,
		error(['NDI_DOCUMENT_OBJ must be of type ndi.document or an ID of a valid ndi.document.']);
	end;
end;

classname = ndi_document_obj.document_properties.document_class.class_name;

doc_string = 'ndi_document_';
index = findstr(classname,doc_string); 

if ~isempty(index),
	obj_parent_string = classname(index+numel(doc_string):end);
end;

if ~isfield(ndi_document_obj.document_properties, obj_parent_string),
	error(['NDI_DOCUMENT_OBJ does not have a ''' obj_parent_string  ''' field.']);
else,
	obj_struct = getfield(ndi_document_obj.document_properties, obj_parent_string);
	obj_string = getfield(obj_struct,['ndi_' obj_parent_string '_class']);
end;

o = eval([obj_string '(ndi_session_obj, ndi_document_obj);']);

