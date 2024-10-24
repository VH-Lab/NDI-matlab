function [b,errmsg] = copy_session_to_dataset(ndi_session_obj, ndi_dataset_obj)
    % COPY_SESSION_TO_DATASET - copy an ingested ndi.session object to ndi.dataset object
    %
    % [B,ERRMSG] = COPY_SESSION_TO_DATASET(NDI_SESSION_OBJ, NDI_DATASET_OBJ)
    %
    % Copy the database documents of an ndi.session object to an ndi.dataset object.
    %
    % B is 1 if the operation succeeds and 0 otherwise. The copying process
    % temporarily requires 2 times the total disk space occupied by NDI_SESSION_OBJ,
    % and, long-term, requires 1 times the total disk space occupied by
    % NDI_SESSION_OBJ, which is stored in NDI_DATASET_OBJ.
    %
    % If
    %

    % Step 1, check to make sure we haven't previously copied the documents

    [refs,session_ids] = ndi_dataset_obj.session_list();

    match = strcmp(ndi_session_obj.id(), session_ids);

    if any(match),
        b = 0;
        errmsg = ['Session with ID ' ndi_session_obj.id() ...
            ' and reference ' ndi_session_obj.reference ...
            ' is already a part of ndi.dataset with ID ' ...
            ndi_dataset_obj.id() ' and reference ' ndi_dataset_obj.reference '.'];
        return;
    end;

    % Step 2, make a copy of all the documents

    [docs,target_path] = ndi.database.fun.extract_docs_files(ndi_session_obj);

    % what we want is to make a surrogate ndi.session.dir with path matching the dataset path
    % for this, we need to make sure the ndi.session.dir creator doesn't read its session_id or reference from the database
    % this needs to be true at ANY time, when it is opened again later

    are_empty_session_id_docs = 0;

    for i=1:numel(docs),
        if isempty(docs{i}.document_properties.base.session_id),
            are_empty_session_id_docs = are_empty_session_id_docs + 1;
            docs{i} = docs{i}.set_session_id(ndi_session_obj.id());
        end;
    end;

    if are_empty_session_id_docs>0,
        warning(['Found ' int2str(are_empty_session_id_docs) ' documents with empty session_id. Setting them to match the current session.']);
    end;

    ndi_session_surrogate = ndi.session.dir(ndi_session_obj.reference, ndi_dataset_obj.getpath(), ndi_session_obj.id());

    ndi_session_surrogate.database_add(docs);
