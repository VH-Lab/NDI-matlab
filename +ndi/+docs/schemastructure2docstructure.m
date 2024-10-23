function docs = schemastructure2docstructure(schema, varargin)
    % schemastructure2docstructure - return documentation information from an ndi document schema
    %
    % DOCS = SCHEMASTRUCTURE2DOCSTRUCTURE(SCHEMA)
    %
    % Given an NDI schema structure (json-schema.org/draft/2019-09/schema#)
    % this function returns documentation information for all properties.
    %
    % This returns a structure array with fields:
    %   - property
    %   - doc_default_value
    %   - doc_data_type
    %   - doc_description
    %
    %

    depth = 1;

    assign(varargin{:});

    docstring = {'doc_default_value', 'doc_data_type','doc_description'};

    docs = vlt.data.emptystruct('property',docstring{:});

    fn = fieldnames(schema);

    property_match = find(strcmpi('properties',fn));
    items_match = find(strcmpi('items',fn));

    if ~isempty(property_match),
        v = getfield(schema,'properties');
        if ~isstruct(v),
            warning(['Expected ''properties'' field to be a struct.']);
            return;
        end;
        fns = fieldnames(v);

        hasdependson = find(strcmpi('depends_on',fns));
        if ~isempty(hasdependson),
            fns = fns([hasdependson 1:hasdependson-1 hasdependson+1:end]);
        end;

        for i=1:numel(fns),
            % fns{i}
            v_i = getfield(v,fns{i});
            p_here = vlt.data.emptystruct('property',docstring{:});
            if isstruct(v_i) & ~strcmp(fns{i},'depends_on'),
                if depth == 1,
                    p_here(1).property = ['**' fns{i} '**'];
                else,
                    p_here(1).property = [fns{i}];
                end;
                fnss = fieldnames(v_i);
                subproperty_match = find(strcmpi('properties',fnss));
                subitem_match = find(strcmpi('items',fnss));
                for j=1:numel(docstring),
                    ds = find(strcmpi(docstring{j},fnss));
                    if ~isempty(ds),
                        p_here(1)=setfield(p_here(1),docstring{j},...
                            getfield(v_i,docstring{j}));
                    end;
                end;
            else,
                subproperty_match = [];
                subitem_match = [];
            end;

            if ~isempty(p_here), % we have something to add
                docs(end+1) = p_here;
            end;

            if strcmpi(fns{i},'depends_on'), % special case, depends on:
                p_here = vlt.data.emptystruct('property',docstring{:});
                p_here(1).property = '**depends_on**';
                p_here(1).doc_default_value = '-';
                p_here(1).doc_data_type = 'structure';
                p_here(1).doc_description = ['Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`.'];
                docs(end+1) = p_here;

                for j=1:numel(v_i.items),
                    % first name
                    p_here = vlt.data.emptystruct('property',docstring{:});
                    if isfield(v_i.items(j).properties.name,'const'),
                        p_here(1).property = ['**depends_on**: ' v_i.items(j).properties.name.const];
                    else,
                        p_here(1).property = ['**depends_on**: *variable dependencies*'];
                    end;
                    fni = fieldnames(v_i.items(j).properties);
                    for k=1:numel(docstring),
                        ds = find(strcmpi(docstring{k},fni));
                        if ~isempty(ds),
                            p_here(1)=setfield(p_here(1),docstring{k},...
                                getfield(v_i.items(j).properties,docstring{k}));
                        end;
                    end;
                    if ~isempty(p_here),
                        docs(end+1) = p_here;
                    end;

                end;
                subitem_match = []; % we don't want to follow this type of item, we handled it
            end;

            % it remains possible that there is more to explore here
            % such as properties.thing.properties
            %  or properties.thing.items

            if ~isempty(subproperty_match) | ~isempty(subitem_match),
                pmore = ndi.docs.schemastructure2docstructure(v_i,'depth',depth+1);
                for j=1:numel(pmore),
                    if depth==1,
                        pmore(j).property = ['**' fns{i} '**.' pmore(j).property];
                    else,
                        pmore(j).property = [fns{i} '.' pmore(j).property];
                    end;
                    docs(end+1) = pmore(j);
                end;
            end;
        end;
    end;

