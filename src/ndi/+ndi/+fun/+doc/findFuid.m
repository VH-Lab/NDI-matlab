function doc = findFuid(ndi_obj, fuid)
% FINDFUID - Find a document in an NDI dataset or session by its file UID.
%
%   DOC = ndi.fun.doc.findFuid(NDI_OBJ, FUID)
%
%   Searches an NDI dataset or session (NDI_OBJ) for a document that
%   contains a file with the unique file identifier FUID.
%
%   If a document is found, it is returned as an ndi.document object.
%   If no document is found, DOC is empty ([]). The function stops
%   searching as soon as the first match is found.
%
%   Inputs:
%   NDI_OBJ - An ndi.dataset or ndi.session object to search within.
%   FUID    - The file unique identifier (a string) to search for.
%
%   Example:
%       my_doc = ndi.fun.doc.findFuid(my_dataset, '...');
%

arguments
    ndi_obj (1,1) {mustBeA(ndi_obj, ["ndi.dataset", "ndi.session"])}
    fuid (1,:) char
end

doc = []; % Initialize output to empty

search_query = ndi.query('base.id','regexp','(.*)');
all_docs = ndi_obj.database_search(search_query);

for i=1:numel(all_docs)
    current_doc = all_docs{i};

    file_list = current_doc.current_file_list();

    for j=1:numel(file_list)
        doc_fuid = current_doc.get_fuid(file_list{j});
        if strcmp(doc_fuid, fuid)
            doc = current_doc; % Found it
            return; % Stop searching
        end
    end
end

end
