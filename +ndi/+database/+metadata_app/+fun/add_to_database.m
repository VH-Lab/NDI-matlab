function S = add_to_database(S, documentList)
%ADD_TO_DATABASE - add a list of documents to the database
%
% S = ndi.database.metadata_app..fun.ADD_TO_DATABASE(S, DOCUMENTLIST)
%
%  Inputs:
%    S - the ndi.session.dir object or ndi.dataset.dir object
%    DOCUMENTLIST - a cell array of ndi.document objects
%
%  Outputs:
%    S - the ndi.session.dir object or ndi.dataset.dir object

reference = [fixpath(S.path), '.ndi/reference.txt'];
D = ndi.dataset.dir(reference, S.path);
[ref_list,id_list] = D.session_list();
if (isempty(ref_list))
    S.database_add(documentList);
else
    id_to_session_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
    id_to_session_map(D.id()) = D;
    for i=1:1:numel(id_list)
        ndi_session_obj = D.open_session(id_list{i});
        id_to_session_map(id_list{i}) = ndi_session_obj;
    end
    id_to_doc_map = containers.Map('KeyType', 'char', 'ValueType', 'any');;

    for i = 1:numel(documentList),
        d = documentList{i};
        session_id = d.document_properties.base.session_id;
        if ~id_to_session_map.isKey(session_id)
            error(['Session ' session_id ' is not found in the dataset']);
        end
        if isKey(id_to_doc_map, session_id)
            existingDocs = id_to_doc_map(session_id);
            existingDocs{end+1} = documentList{i};
            id_to_doc_map(session_id) = existingDocs;
        else
            id_to_doc_map(session_id) = {documentList{i}};
        end
    end

    %iterate through the id_to_doc_map and delete the openminds docs
    keys = id_to_doc_map.keys;
    for i = 1:numel(keys)
        session_id = keys{i};
        if ~id_to_doc_map.isKey(session_id)
            continue;
        end
        ndi_session_obj = id_to_session_map(session_id);
        d = id_to_doc_map(session_id);
        ndi_session_obj.database_add(d);
    end
end


% for i = 1:numel(documentList)
%     document_session_id = documentList{i}.document_properties.base.session_id;
%     if (session_id == document_session_id)
%         S.database_add(documentList{i});
%     else
%         ndi_session_obj = D.open_session(document_session_id);
%         ndi_session_obj.database_add(documentList{i});
%     end
% end
end


