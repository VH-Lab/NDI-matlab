function S = add_to_database(S, documentList, session_id)
%ADD_TO_DATABASE Summary of this function goes here
%   Detailed explanation goes here

reference = [fixpath(S.path), '.ndi/reference.txt'];
D = ndi.dataset.dir(reference, S.path);
D.database_add(documentList);
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


