function [d] = findallantecedents(E, visited, varargin)
    % FINDALLANTECEDENTS - find documents that have the provided documents as dependencies
    %
    % [D] = ndi.database.fun.findallantecedents(E, VISITED, DOC1, DOC2, ...)
    %
    % Searches the database of session or dataset E and returns all documents for which
    % DOC1, DOC2, etc have a dependency. That is, this function crawls up the list of
    % 'depends_on' fields to find all documents that DOC1, DOC2 etc. depend on.
    % If any DOCS do not need to be searched, provide them in VISITED.  Otherwise, provide
    % empty for VISITED.
    %
    % D is always a cell array of NDI_DOCUMENTS (perhaps empty, {}).
    %
    % See also: ndi.database.fun.findalldependencies()

    if ~isa(E,'ndi.session') & ~isa(E,'ndi.dataset')
        error(['Input E must be an ndi.session or ndi.dataset']);
    end

    d = {};

    if isempty(visited)
        visited = {};
    end

    for i=1:numel(varargin)
        visited = cat(1,visited,{varargin{i}.id()});
    end

    for i=1:numel(varargin)
        [depNames,depStruct] = dependency(varargin{i});
        ids = {depStruct.value};
        if numel(ids)>0
            q_v = ndi.query('base.id','exact_string',ids{1});
            for j=2:numel(ids)
                q_v = q_v | ndi.query('base.id','exact_string',ids{j});
            end
        end
        bb = E.database_search(q_v);

        for j=1:numel(bb)
            id_here = bb{j}.id();
            if ~any(strcmp(id_here,visited)) % we don't already know about it
                visited = cat(1,visited,{id_here});
                d = cat(1,d,{bb{j}});
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

    if ~iscell(d)
        error(['This should always return a cell list, even if it is empty. Someelement is wrong, debug necessary.']);
    end
