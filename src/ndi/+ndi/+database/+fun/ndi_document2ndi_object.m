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

    if ~isa(ndi_document_obj, 'ndi.document')
        % try to look it up
        mydoc = ndi_session_obj.database_search(ndi.query('base.id','exact_string',ndi_document_obj,''));
        if numel(mydoc)==1
            ndi_document_obj = mydoc{1};
        else
            error(['NDI_DOCUMENT_OBJ must be of type ndi.document or an ID of a valid ndi.document.']);
        end
    end

    % THE OBJECT-RECONSTRUCTION KEY, IN EITHER VINTAGE.
    %
    % This used to read `document_properties.<class_name>.ndi_<class_name>_class`
    % inline. That field name is CONSTRUCTED, which is why a literal grep for
    % `ndi_daqsystem_class` finds only NDI's writer and reports the field as
    % unread -- and it is the exact read a V_eta document cannot satisfy,
    % because R1 folded every implementation class name out of a field and
    % into a `software` entity behind an edge.
    %
    % ndi.vintage.objectClass answers for both vintages from one declaration.
    % For a v1 document it performs the identical read, including the legacy
    % `ndi_document_` prefix strip, so nothing about the v1 path changes.
    obj_string = ndi.vintage.objectClass(ndi_document_obj, ndi_session_obj);

    % obj_string is read verbatim from the document's JSON payload, which can
    % arrive from an untrusted source (e.g. a dataset downloaded from NDI Cloud).
    % Use feval, not eval: eval would execute an arbitrary expression built from
    % the field's value, whereas feval calls only the named constructor.
    %
    % NOTE (V2 merge, 2026-09-23): V2 added a lineage check here
    % (local_requiredtype + ndi.validators.mustBeClassnameOfType) keyed on the
    % v1-only document block name `obj_parent_string`. The vintage read above
    % (ndi.vintage.objectClass) that V_eta requires abstracts that key away and
    % returns the MATLAB class directly, so the v1-only key is not available and
    % the check could not be carried over as-is. Re-adding a vintage-aware
    % lineage check is a follow-up for the team.
    o = feval(obj_string, ndi_session_obj, ndi_document_obj);
