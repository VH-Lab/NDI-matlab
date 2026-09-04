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
        obj_string = getfield(obj_struct,['ndi_' obj_parent_string '_class']);
    end

    % obj_string is read verbatim from the document's JSON payload, which can
    % arrive from an untrusted source (e.g. a dataset downloaded from NDI Cloud).
    % Check it before instantiating, then use feval: eval would execute an
    % arbitrary expression built from the field's value.
    %
    % The check is on lineage, not on a namespace prefix. That admits a lab's own
    % subclass wherever it lives, refuses any class that is not of the expected
    % type, and stays expressible in NDI-python, where third parties cannot add to
    % the ndi. namespace at all (ndi is a regular package, not a PEP 420
    % namespace package).
    requiredType = local_requiredtype(obj_parent_string);
    ndi.validators.mustBeClassnameOfType(obj_string, requiredType);
    o = feval(obj_string, ndi_session_obj, ndi_document_obj);

function requiredType = local_requiredtype(obj_parent_string)
% LOCAL_REQUIREDTYPE - the base class each reconstructable document kind produces
%
% Keys are the document property-list names that carry an 'ndi_<name>_class'
% field. Add an entry here when a new such document type is introduced.

    switch obj_parent_string
        case 'daqmetadatareader'
            requiredType = 'ndi.daq.metadatareader';
        case {'daqreader','daqreader_ndr'}
            requiredType = 'ndi.daq.reader';
        case 'daqsystem'
            requiredType = 'ndi.daq.system';
        case 'element'
            requiredType = 'ndi.element';
        case 'filenavigator'
            requiredType = 'ndi.file.navigator';
        case 'syncgraph'
            requiredType = 'ndi.time.syncgraph';
        case 'syncrule'
            requiredType = 'ndi.time.syncrule';
        otherwise
            error('ndi:database:fun:ndi_document2ndi_object:unknownDocumentType', ...
                ['Document type ''%s'' has no registered base class, so the class ' ...
                 'named in its ''ndi_%s_class'' field cannot be checked before ' ...
                 'instantiation. Register it in local_requiredtype.'], ...
                obj_parent_string, obj_parent_string);
    end
