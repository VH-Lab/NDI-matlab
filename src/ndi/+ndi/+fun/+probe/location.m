function [probeLocations, probeObj] = location(S, e)
% PROBELOCATION - Return probe location documents and probe object for an NDI element
%
% [PROBELOCATIONS, PROBEOBJ] = NDI.FUN.PROBE.LOCATION(S, E)
%
% Given an NDI element E, find the NDI.PROBE object that is associated with it,
% and return all 'probeLocation' documents that are associated with that probe.
%
% This function also returns the NDI.PROBE object itself as a second output
% argument PROBEOBJ.
%
% E can be one of the following:
%   a) An NDI.ELEMENT object (or a subclass like NDI.PROBE)
%   b) The character string identifier of an NDI.ELEMENT object.
%
% S is an NDI.SESSION or NDI.DATASET object.
%
% The function travels "down" the 'underlying_element' dependency tree until
% it finds an NDI.PROBE object. Once it has the identifier for that probe, it
% searches for all documents that depend on that probe and that are of the
% 'probeLocation' class.
%
% See also: NDI.PROBE, NDI.ELEMENT, NDI.DOCUMENT
%
    arguments
        S {mustBeA(S, ["ndi.session", "ndi.dataset"])}
        e {mustBeValidElementInput(e)}
    end

% Step 1: get the element object if it's an identifier
if ischar(e)
	element_doc = S.database_search(ndi.query('ndi_document.id','exact_string',e,''));
	if isempty(element_doc)
		error(['Could not find an element with id ' e '.']);
	end
	e = ndi.database.fun.ndi_document2ndi_object(S, element_doc{1});
end

% Step 2: traverse down to the probe
current_element = e;
while ~isa(current_element, 'ndi.probe')
    % Find the link document that shows what the current element depends on.
    link_doc_q = ndi.query('','depends_on','element_id', current_element.id()) & ndi.query('','isa','ndi.document.underlying_element');
    link_doc = S.database_search(link_doc_q);

	if isempty(link_doc)
		% we are at the bottom and haven't found a probe
		error(['Could not find an ndi.probe object that is associated with element ' e.id() '.']);
    end

    % Get the ID of the actual underlying element from the link document's properties.
    underlying_element_id = link_doc{1}.document_properties.underlying_element.underlying_element_id;

    % Now, get the document for the underlying element itself.
    underlying_element_doc = S.database_search(ndi.query('ndi_document.id', 'exact_string', underlying_element_id, ''));
    if isempty(underlying_element_doc)
        error(['Database integrity error: Could not find the underlying element with id ' underlying_element_id]);
    end

    % Convert the document to an object for the next loop iteration.
    current_element = ndi.database.fun.ndi_document2ndi_object(S, underlying_element_doc{1});
end

% Step 3: we have the probe, assign output
probeObj = current_element;
probeIdentifier = probeObj.id();

% Step 4: query for the locations
q = ndi.query('','depends_on','probe_id',probeIdentifier) & ndi.query('','isa','probeLocation');
probeLocations = S.database_search(q);

end % location()

function mustBeValidElementInput(e)
    % Custom validator for the element input 'e'
    if ~(ischar(e) || isa(e, 'ndi.element'))
        eid = 'ndi:validators:mustBeValidElementInput';
        msg = 'Input must be a character string or an ndi.element object.';
        throwAsCaller(MException(eid,msg));
    end
end