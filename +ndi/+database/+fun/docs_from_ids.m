function docs = docs_from_ids(DorS,document_ids)
    % DOCS_FROM_IDS - read ndi.document objects given an array of IDs in a single query
    %
    % DOCS = DOCS_FROM_IDS(D_OR_S, DOCUMENT_IDS)
    %
    % Retrieve a set of documents that correspond to a cell array of DOCUMENT_IDS.
    % This function is faster than similar code that searches for each document one
    % at a time because it combines the search into a single query.
    %
    % D_OR_S is an ndi.dataset or ndi.session object.
    %
    % DOCS is a cell array the same size as DOCUMENT_IDS. If the document is found, it
    % is provided in DOCS{i}. Otherwise, DOCS{i} is empty.

    if isempty(document_ids),
        docs = {};
        return;
    end;

    q = [];

    for i=1:numel(document_ids),
        q_here = ndi.query('base.id','exact_string',document_ids{i});
        if isempty(q),
            q = q_here;
        else,
            q = q | q_here;
        end;
    end;

    docs_here = DorS.database_search(q);

    docs = cell(size(document_ids));

    for i=1:numel(document_ids),
        for j=1:numel(docs_here),
            if strcmp(document_ids{i},docs_here{j}.document_properties.base.id),
                docs{i} = docs_here{j};
                break; % stop when we found it
            end;
        end;
    end;
