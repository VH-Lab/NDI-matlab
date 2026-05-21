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

    classname = ndi_document_obj.document_properties.document_class.class_name;

    doc_string = 'ndi_document_';
    index = findstr(classname,doc_string);

    if ~isempty(index)
        obj_parent_string = classname(index+numel(doc_string):end);
    else
        obj_parent_string = classname;
    end

    if ~isfield(ndi_document_obj.document_properties, obj_parent_string)
        error(['NDI_DOCUMENT_OBJ does not have a ''' obj_parent_string  ''' field.']);
    else
        obj_struct = getfield(ndi_document_obj.document_properties, obj_parent_string);
        obj_string = resolveReconstructorClass(obj_parent_string, obj_struct);
    end

    o = eval([obj_string '(ndi_session_obj, ndi_document_obj);']);
end

function obj_string = resolveReconstructorClass(obj_parent_string, obj_struct)
    % resolveReconstructorClass - determine the MATLAB class to
    % `eval()` for the document's reconstruction.
    %
    % did_v1 stored this class name on the body under
    % `<parent>.ndi_<parent>_class`. Most V_delta migrators pass
    % the field through unchanged, but a few drop it on the
    % grounds that the stored value was a constant across every
    % instance of the class (so the migration loses no
    % information). For those classes we know the class name from
    % the document class itself and resolve it here.

    % Override map: V_delta class name -> MATLAB constructor class.
    % daqreader_ndr always reconstructs as ndi.daq.reader.mfdaq.ndr
    % (verified: every v1 daqreader_ndr blank stored the same value;
    % did-schema#50 / did-matlab#135 audit).
    overrides = struct( ...
        'daqreader_ndr', 'ndi.daq.reader.mfdaq.ndr');

    legacyField = ['ndi_' obj_parent_string '_class'];
    if isfield(obj_struct, legacyField) && ~isempty(obj_struct.(legacyField))
        obj_string = obj_struct.(legacyField);
        return;
    end
    if isfield(overrides, obj_parent_string)
        obj_string = overrides.(obj_parent_string);
        return;
    end
    error('NDI:database:fun:noReconstructorClass', ...
        ['Cannot determine MATLAB reconstructor class for ' ...
         'document class "%s": neither the legacy field "%s" ' ...
         'nor a known override is available.'], ...
        obj_parent_string, legacyField);
