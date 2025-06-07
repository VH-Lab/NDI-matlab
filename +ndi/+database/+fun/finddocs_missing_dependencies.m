function d = finddocs_missing_dependencies(E, varargin)
    % FINDDOCS_MISSING_DEPENDENCIES - find documents that have dependencies on documents that do not exist
    %
    % D = ndi.database.fun.finddocs_missing_dependencies(E)
    %
    % Searches the database of session E and returns all documents that have a
    % dependency ('depends_on') field for which the 'value' field does not
    % correspond to an existing document.
    %
    % The following form:
    %
    % D = ndi.database.fun.finddocs_missing_dependencies(E, NAME1, NAME2, ...)
    %
    % works similarly except that it only examines variables with depends_on
    % fields with names NAME1, NAME2, etc.
    %

    documents_observed = {}; % keep track of what we have seen so we don't have to search multiple times

    d = E.database_search(ndi.query('depends_on','hasfield','',''));

    if ~iscell(d), d = {d}; end

    for i=1:numel(d)
        documents_observed{end+1} = d{i}.id();
    end

    include = [];

    for i=1:numel(d)
        for j=1:numel(d{i}.document_properties.depends_on)
            if nargin>1
                match = any(strcmpi(d{i}.document_properties.depends_on(j).name,varargin));
            else
                match = 1;
            end
            if match
                id_here = d{i}.document_properties.depends_on(j).value;
                if ~isempty(id_here)
                    if any(strcmpi(d{i}.document_properties.depends_on(j).value,documents_observed))
                        % we've got it already
                    else   % we need to look more
                        dhere = E.database_search(ndi.query('base.id','exact_string',id_here,''));
                        if ~isempty(dhere)
                            if ~iscell(dhere), dhere = {dhere}; end
                            documents_observed{end+1} = dhere{1}.id();
                        else % no match
                            include(end+1) = i;
                            break; % move on to next document, skip for loop over j
                        end
                    end
                end
            end
        end
    end

    d = d(include);
