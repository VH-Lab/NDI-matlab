function p = ndi_document2probe(ndi_document_obj, ndi_session_obj)
% NDI_DOCUMENT2PROBE - create an NDI_PROBE object from an NDI_DOCUMENT
%
% P = NDI_DOCUMENT2PROBE(NDI_DOCUMENT_OBJ, NDI_SESSION_OBJ)
%
% Create an NDI_PROBE object P from an NDI_DOCUMENT object that has
% a 'probe' parameter and is related to an session NDI_SESSION object
% that is provided.
% 

if ~isa(ndi_document_obj, 'ndi_document'),
	error(['NDI_DOCUMENT_OBJ must be of type NDI_DOCUMENT.']);
end;

if ~isfield(ndi_document_obj.document_properties, 'probe'),
	error(['NDI_DOCUMENT_OBJ does not have a ''probe'' field.']);
end;

reference = ndi_document_obj.document_properties.probe.reference;
type = ndi_document_obj.document_properties.probe.type;
name = ndi_document_obj.document_properties.probe.name;

p = getprobes(ndi_session_obj, 'name', name, 'type', type, 'reference', reference);

if isempty(p),
	p = [];
else,
	if numel(p)>1,
		error(['More than one probe matched, do not know what to do, should not happen.']);
	end;
	p = p{1}; % return exactly 1 probe
end;

