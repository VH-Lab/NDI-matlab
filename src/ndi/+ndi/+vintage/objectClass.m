function objClass = objectClass(ndi_document_obj, ndi_session_obj)
%OBJECTCLASS The MATLAB class to construct for a document, in EITHER vintage.
%
%   OBJCLASS = ndi.vintage.objectClass(NDI_DOCUMENT_OBJ, NDI_SESSION_OBJ)
%
%   v1 stores the answer in a field named after the class -- `daqsystem`
%   documents carry `daqsystem.ndi_daqsystem_class`. That field name is
%   CONSTRUCTED at the read site, which is why a literal grep for it finds
%   only the writer and reports it as unread.
%
%   V_eta has no such field. R1 folded every implementation class name into
%   a `software` ENTITY, referenced by an edge -- DID-matlab
%   +migrators_j/private/jSoftware.m is called with the implementation
%   class as its NAME argument, so the string is `software.name` on the
%   other end of `software_id`. So recovering the object class is a
%   one-hop lookup rather than a field read, and it needs the session.
%
%   Errors (all named, none silent -- an unconstructable object must not
%   come back as empty):
%       NDI:vintage:noObjectClassField  v1 document, field absent
%       NDI:vintage:noSoftwareEdge      V_eta document, no software_id
%       NDI:vintage:softwareNotFound    the edge names no readable document
%       NDI:vintage:softwareHasNoName   the software entity carries no name
%
%   See also: ndi.vintage.map, ndi.database.fun.ndi_document2ndi_object.

props = ndi_document_obj.document_properties;
className = props.document_class.class_name;

[entry, vintage] = ndi.vintage.entryFor(ndi_document_obj);

if isempty(entry) || strcmp(vintage, 'v1')
    % THE ORIGINAL PATH, unchanged. `obj_parent_string` strips a legacy
    % `ndi_document_` prefix exactly as ndi_document2ndi_object always did.
    blockName = className;
    idx = strfind(blockName, 'ndi_document_');
    if ~isempty(idx)
        blockName = blockName(idx + numel('ndi_document_'):end);
    end
    if ~isfield(props, blockName)
        error('NDI:vintage:noObjectClassField', ...
            ['document of class "%s" has no "%s" block, so the object ' ...
             'class cannot be read'], className, blockName);
    end
    blk = props.(blockName);
    fieldName = ['ndi_' blockName '_class'];
    if ~isstruct(blk) || ~isfield(blk, fieldName)
        error('NDI:vintage:noObjectClassField', ...
            ['document of class "%s" has no "%s.%s", so there is no ' ...
             'MATLAB class to construct'], className, blockName, fieldName);
    end
    objClass = blk.(fieldName);
    return;
end

% V_eta, KEY LOCATION 3: an INBOUND term_assertion. Used by `element`,
% whose class name did not fold into a software entity -- it became a
% statement ABOUT the element-subject, pointing back at it by subject_id.
% So the lookup runs the other way round from the software case: search
% for the assertion, do not follow an edge off this document.
if ~isempty(entry.object_assertion)
    objClass = assertionValue(ndi_document_obj, ndi_session_obj, ...
        entry.object_assertion);
    return;
end

% A MAPPED CLASS THAT IS NOT AN NDI OBJECT AT ALL. `element_epoch` has a
% map row so the three sites that index its block by v1 name can find it,
% and v1 stores no `ndi_*_class` on it -- there is no object to build and
% never was. Refused by NAME here rather than falling through to the
% software hop, which would ask for `dependency_value('')` and report a
% missing edge, blaming the document for an absence that is a property of
% the concept.
if isempty(entry.object_field) && isempty(entry.object_edge)
    error('NDI:vintage:notAnObjectConcept', ...
        ['"%s" (v1 "%s") is not an NDI object type -- ndi.vintage.map ' ...
         'carries it for its class rename only, and v1 stored no ' ...
         'implementation class on it. There is nothing to construct.'], ...
        entry.eta_class, entry.v1_class);
end

% V_eta: one hop to the software entity.
swId = ndi_document_obj.dependency_value(entry.object_edge, 'ErrorIfNotFound', 0);
if isempty(swId)
    error('NDI:vintage:noSoftwareEdge', ...
        ['"%s" document %s carries no "%s", so the implementation class ' ...
         'v1 stored in "%s" was not preserved and no object can be built. ' ...
         'The migrator leaves this edge empty only when the source named ' ...
         'no class (+migrators_j/daqsystem.m: jSoftware returns [] for an ' ...
         'empty name).'], ...
        entry.eta_class, props.base.id, entry.object_edge, entry.object_field);
end

swDocs = ndi_session_obj.database_search( ...
    ndi.query('base.id', 'exact_string', swId, ''));
if numel(swDocs) ~= 1
    error('NDI:vintage:softwareNotFound', ...
        ['"%s".%s names software document %s and %d document(s) match; ' ...
         'the object class lives on that document'], ...
        entry.eta_class, entry.object_edge, swId, numel(swDocs));
end

swProps = swDocs{1}.document_properties;
if ~isfield(swProps, 'software') || ~isstruct(swProps.software) ...
        || ~isfield(swProps.software, 'name') || isempty(swProps.software.name)
    error('NDI:vintage:softwareHasNoName', ...
        ['software document %s carries no `name`, and `name` is where ' ...
         'jSoftware puts the implementation class string'], swId);
end
objClass = swProps.software.name;
end

function v = assertionValue(ndi_document_obj, ndi_session_obj, label)
%ASSERTIONVALUE Read a kind assertion pointing AT this document.
%   The migrator writes one `term_assertion` per kind fact, carrying
%   `subject_statement.variable.name = <label>` and the answer in
%   `term.value.name`, with `subject_id` pointing back at the subject
%   (DID-matlab +migrators_j/element.m, kindAssertion).
docId = ndi_document_obj.document_properties.base.id;
q = ndi.query('', 'isa', 'term_assertion', '') & ...
    ndi.query('subject_statement.variable.name', 'exact_string', label, '') & ...
    ndi.query('', 'depends_on', 'subject_id', docId);
docs = ndi_session_obj.database_search(q);
if numel(docs) ~= 1
    error('NDI:vintage:assertionNotFound', ...
        ['subject %s carries %d term_assertion(s) labelled "%s"; exactly ' ...
         'one holds the MATLAB class to construct. Zero means this ' ...
         'subject was never an element (or the element carried no class ' ...
         'name, which the migrator skips) -- it is not an object NDI can ' ...
         'rebuild.'], docId, numel(docs), label);
end
p = docs{1}.document_properties;
if ~isfield(p, 'term') || ~isstruct(p.term) || ~isfield(p.term, 'value') ...
        || ~isfield(p.term.value, 'name') || isempty(p.term.value.name)
    error('NDI:vintage:assertionHasNoValue', ...
        ['the "%s" assertion on subject %s carries no term.value.name'], ...
        label, docId);
end
v = p.term.value.name;
end
