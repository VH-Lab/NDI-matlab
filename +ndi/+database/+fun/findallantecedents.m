function [d] = findallantecedents(E, visited, varargin)
    % FINDALLANTECEDENTS - find documents that are antecedents of the provided documents
    %
    % [D] = ndi.database.fun.findallantecedents(E, VISITED, DOC1, DOC2, ...)
    %
    % Searches the database of session or dataset E and returns all documents that
    % are antecedents of the documents provided (DOC1, DOC2, ...). That is, this function
    % crawls "up" the list of 'depends_on' fields.
    %
    % If any document IDs should be considered already visited (and therefore not
    % processed or returned), provide their IDs in the cell array VISITED.
    % Otherwise, provide an empty cell array for VISITED.
    %
    % D is always a cell array of NDI.DOCUMENT objects (perhaps empty, {}).
    %
    % Example:
    %   session = ndi.session(); % replace with your session
    %   doc1 = % ... obtain an ndi.document ...
    %   doc2 = % ... obtain another ndi.document ...
    %   antecedent_docs = ndi.database.fun.findallantecedents(session, {}, doc1, doc2);
    %
    % See also: ndi.database.fun.findalldependencies()

    arguments
        E (1,1) {mustBeA(E,["ndi.session","ndi.dataset"])}
        visited (:,1) cell = {}
    end
    arguments (Repeating)
        varargin (1,1) {mustBeA(varargin,'ndi.document')}
    end
    % varargin is now a cell array where each element has been validated to be an ndi.document
    docs = varargin; % Assign to 'docs' for clarity

    d = {};
    bb = {}; % Initialize bb to an empty cell array

    % Add initial docs to visited list by their IDs
    for i=1:numel(docs)
        doc_id = docs{i}.id();
        is_visited = false;
        for v_idx = 1:numel(visited)
            if strcmp(doc_id, visited{v_idx})
                is_visited = true;
                break;
            end
        end
        if ~is_visited
            visited{end+1,1} = doc_id;
        end
    end

    for i=1:numel(docs)
        current_doc = docs{i};
        [depNames,depStruct] = dependency(current_doc);
        
        ids = {};
        if ~isempty(depStruct) && isfield(depStruct,'value') && ~isempty(depStruct(1).value) % check depStruct is not empty and has value
            % depStruct can be an array, ensure we handle all values
            for ds_idx = 1:numel(depStruct)
                if isfield(depStruct(ds_idx),'value') && ~isempty(depStruct(ds_idx).value)
                    ids{end+1} = depStruct(ds_idx).value;
                end
            end
            ids = unique(ids); % Ensure unique IDs
        end
        
        if ~isempty(ids)
            q_v = ndi.query('base.id','exact_string',ids{1});
            for k_id=2:numel(ids)
                q_v = q_v | ndi.query('base.id','exact_string',ids{k_id});
            end
            bb = E.database_search(q_v);
        else
            bb = {}; % No valid IDs to search for, so bb is empty
        end

        for j=1:numel(bb)
            id_here = bb{j}.id();
            is_visited_loop = false;
            for v_idx_loop = 1:numel(visited)
                if strcmp(id_here, visited{v_idx_loop})
                    is_visited_loop = true;
                    break;
                end
            end
            if ~is_visited_loop % we don't already know about it
                visited{end+1,1} = id_here; % Add to visited list
                d{end+1,1} = bb{j}; % Add to results
                % Recursively find antecedents for this new document
                newdocs = ndi.database.fun.findallantecedents(E,visited,bb{j});
                if ~isempty(newdocs)
                    for k=1:numel(newdocs)
                        visited = cat(1,visited,newdocs{k}.id());
                    end
                    d = cat(1,d,newdocs(:));
                end
            end
        end
    end