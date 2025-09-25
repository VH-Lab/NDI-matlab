function [s] = openMINDSobj2struct(openmindsObj, cachekey)
    % OPENMINDSOBJ2STRUCT - convert an openMINDS object to a Matlab structure for creating an NDI document
    %
    % S = ndi.database.fun.openMINDSobj2struct(OPENMINDSOBJ)
    %
    % Given a cell array of openminds objects, returns a set of Matlab structures for each object.
    %
    % Requires:  https://github.com/openMetadataInitiative/openMINDS_MATLAB
    %
    % Example:
    %  p = personWithTwoAffiliations();
    %  s = ndi.database.fun.openMINDSobj2struct(p);
    %
    %

    ndi_cache = ndi.common.getCache();

    openminds_base_class = 'openminds.abstract.Schema';
    cachetype = 'openmindsconversionstack';

    initial_call = 0;

    % we have to build a stack, which we will store in a cache object, that
    % remembers if we have visited all the openMinds object

    if nargin<2
        % we are just getting started on a new conversion
        newid = ndi.ido;
        cachekey = newid.id(); % build a cache stack
        s = did.datastructures.emptystruct('openminds_type','matlab_type','openminds_id','ndi_id','fields','complete');
        initial_call = 1;
    else
        sdata = ndi_cache.lookup(cachekey, cachetype);
        s = sdata.data;
    end

    if ~iscell(openmindsObj)
        newcell = {};
        for i=1:numel(openmindsObj)
            newcell{i} = openmindsObj(i);
        end
        openmindsObj = newcell; % make it a cell no matter what
    end

    for i=1:numel(openmindsObj)

        % fill out preliminary entry

        s_here.openminds_type = char(openmindsObj{i}.X_TYPE);
        s_here.matlab_type = class(openmindsObj{i});
        s_here.openminds_id = char(openmindsObj{i}.id);
        newid = ndi.ido();
        s_here.ndi_id = newid.id();
        s_here.fields = [];
        s_here.complete = 0;

        % did we already make this?

        index = find(strcmp(s_here.openminds_id,{s.openminds_id}));

        if ~isempty(index)
            if s(index).complete
                % we already built this, skip it
                continue;
            end
        else
            index = numel(s)+1;
        end

        % if we are here, we have to start building it

        s(index) = s_here;
        % put it in the table now so the children will know it's under construction
        ndi_cache.remove(cachekey,cachetype);
        ndi_cache.add(cachekey,cachetype,s);

        fn = fieldnames(openmindsObj{i});

        for j=1:numel(fn)
            f = getfield(openmindsObj{i},fn{j});
            if isa(f, 'string')
                f = char(f); % we have to insert character arrays into the sql database
            end
            if isa(f, 'datetime')
                f = char(f);
            end
            mt = startsWith(class(f),'openminds.internal.mixedtype');
            if isa(f,'openminds.abstract.Schema') | mt
                fields_here = {};
                for k=1:numel(f)
                    if mt
                        f_here = f(k).Instance;
                    else
                        f_here = f(k);
                    end
                    s = ndi.database.fun.openMINDSobj2struct({f_here},cachekey);
                    child_index = find(strcmp(char(f_here.id),{s.openminds_id}));
                    if isempty(child_index)
                        % stop this nonsense
                        ndi_cache.remove(cachekey,cachetype);
                        error('A child was not built successfully.');
                    end
                    fields_here{k} = ['ndi://' s(child_index).ndi_id];
                end
                s_here.fields = setfield(s_here.fields,fn{j},fields_here);
            else
                s_here.fields = setfield(s_here.fields,fn{j},f);
            end
        end

        % fill the table, mark it as complete
        s_here.complete = 1;

        s(index) = s_here;

        ndi_cache.remove(cachekey,cachetype);
        ndi_cache.add(cachekey,cachetype,s);

    end

    if initial_call
        % if we were the first function, remove the cache
        ndi_cache.remove(cachekey,cachetype);
    end
