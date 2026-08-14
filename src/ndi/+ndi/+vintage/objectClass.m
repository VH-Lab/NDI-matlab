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
