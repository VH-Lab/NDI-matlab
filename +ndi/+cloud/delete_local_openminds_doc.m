function D = delete_local_openminds_doc(D)
%DELETE_LOCAL_OPENMINDS_DOC delete the openminds documents from dataset
% 
% D = ndi.cloud.DELETE_LOCAL_OPENMINDS_DOC(D)
%
% Inputs:
%   D - a ndi.dataset.dir object
%
% Outputs:
%   D - a ndi.dataset.dir object after deleting the docs
%
p = D.getpath();
S_dataset = ndi.session.dir(p);
[ref_list,id_list] = D.session_list();
id_to_session_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
id_to_session_map(D.id()) = D;
for i=1:1:numel(id_list)
    ndi_session_obj = D.open_session(id_list{i});
    id_to_session_map(id_list{i}) = ndi_session_obj;
end

d_openminds = D.database_search( ndi.query('openMinds.fields','hasfield'));
id_to_doc_map = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:numel(d_openminds),
    d = d_openminds{i};
    session_id = d.document_properties.base.session_id;
    if ~id_to_session_map.isKey(session_id)
        error(['Session ' session_id ' is not found in the dataset']);
    end
    if isKey(id_to_doc_map, session_id)
        existingDocs = id_to_doc_map(session_id);
        existingDocs{end+1} = d_openminds{i};
        id_to_doc_map(session_id) = existingDocs;
    else
        id_to_doc_map(session_id) = {d_openminds{i}};
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
    ndi_session_obj.database_rm(d);
end
end
