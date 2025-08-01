classdef syncgraph < ndi.ido

    properties (SetAccess=protected,GetAccess=public)
        session      % ndi.session object
        rules        % cell array of ndi.time.syncrule objects to apply
    end
    properties (SetAccess=protected,GetAccess=private)
    end

    methods

        function ndi_syncgraph_obj = syncgraph(varargin)
            % ndi.time.syncgraph - create a new ndi.time.syncgraph object
            %
            % NDI_SYNCGRAPH_OBJ = ndi.time.syncgraph(SESSION)
            %
            % Builds a new ndi.time.syncgraph object and sets its SESSION
            % property to SESSION, which should be an ndi.session object.
            %
            % This function can be called in another form:
            % NDI_SYNCGRAPH_OBJ = ndi.time.syncgraph(SESSION, NDI_DOCUMENT_OBJ)
            % where NDI_DOCUMENT_OBJ is an ndi.document of class syncgraph.
            %

            % need to be tested after ndi.time.syncrule creator is done
            if nargin == 2 && isa(varargin{1},'ndi.session') && isa(varargin{2}, 'ndi.document')
                ndi_syncgraph_obj.session = varargin{1};
                [syncgraph_doc, syncrule_doc] = ndi.time.syncgraph.load_all_syncgraph_docs(varargin{1},varargin{2}.id());
                ndi_syncgraph_obj.identifier = varargin{2}.id();
                for i=1:numel(syncrule_doc)
                    ndi_syncgraph_obj = ndi_syncgraph_obj.addrule(ndi.database.fun.ndi_document2ndi_object(syncrule_doc{i},varargin{1}));
                end
            else
                session = [];

                if nargin>0
                    session = varargin{1};
                end

                ndi_syncgraph_obj.session = session;

                if nargin>=2
                    if strcmp(lower(varargin{2}),lower('OpenFile'))
                        error(['Load from file no longer supported.']);
                        ndi_syncgraph_obj = ndi_syncgraph_obj.readobjectfile(varargin{1});
                    end
                end
            end
        end % ndi.time.syncgraph

        function b = eq(ndi_syncgraph_obj1, ndi_syncgraph_obj2)
            % EQ - are 2 ndi.time.syncgraph objects equal?
            %
            % B = EQ(NDI_SYNCGRAPH_OBJ1, NDI_SYNCHGRAPH_OBJ2)
            %
            % B is 1 if the ndi.time.syncgraph objects have equal sessions and if
            % all syncrules are equal.
            %
            b = eq(ndi_syncgraph_obj1.session, ndi_syncgraph_obj2.session);
            b = b & (numel(ndi_syncgraph_obj1.rules)==numel(ndi_syncgraph_obj2.rules));
            if b
                for i=1:numel(ndi_syncgraph_obj1.rules)
                    b = b & (ndi_syncgraph_obj1.rules{i} == ndi_syncgraph_obj2.rules{i});
                end
            end
        end % eq();

        function ndi_syncgraph_obj = addrule(ndi_syncgraph_obj, ndi_syncrule_obj)
            % ADDRULE - add an ndi.time.syncrule to an ndi.time.syncgraph object
            %
            % NDI_SYNCGRAPH_OBJ = ADDRULE(NDI_SYNCGRAPH_OBJ, NDI_SYNCRULE_OBJ)
            %
            % Adds the ndi.time.syncrule object indicated as a rule for
            % the ndi.time.syncgraph NDI_SYNCGRAPH_OBJ. If the ndi.time.syncrule is already
            % there, then
            %
            % See also: ndi.time.syncgraph/REMOVERULE

            if ~iscell(ndi_syncrule_obj)
                ndi_syncrule_obj = {ndi_syncrule_obj};
            end

            did_add = 0;
            for i=1:numel(ndi_syncrule_obj)
                if isa(ndi_syncrule_obj{i},'ndi.time.syncrule')
                    % check for duplication
                    match = -1;
                    for j=1:numel(ndi_syncgraph_obj.rules)
                        if ndi_syncgraph_obj.rules{j}==ndi_syncrule_obj{i}
                            match = j;
                            break;
                        end
                    end
                    if match<0
                        did_add = 1;
                        ndi_syncgraph_obj.rules{end+1} = ndi_syncrule_obj{i};
                    end
                else
                    error('Input not of type ndi.time.syncrule.');
                end
            end
            if did_add
                ndi_syncgraph_obj.remove_cached_graphinfo();
            end
        end % addrule()

        function ndi_syncgraph_obj = removerule(ndi_syncgraph_obj, index)
            % REMOVERULE - remove a given ndi.time.syncrule from an ndi.time.syncgraph object
            %
            % NDI_SYNCGRAPH_OBJ = REMOVERULE(NDI_SYNCGRAPH_OBJ, INDEX)
            %
            % Removes the NDI_SYNCGRAPH_OBJ.rules entry at the INDEX (or indexes) indicated.
            %
            n = numel(ndi_syncgraph_obj.rules);
            ndi_syncgraph_obj.rules = ndi_syncgraph_obj.rules(setdiff(1:n),index);
            ndi_syncgraph_obj.remove_cached_graphinfo();

        end % removerule()

        function [ginfo,hashvalue] = graphinfo(ndi_syncgraph_obj)
            % GRAPHINFO - return the graph information
            %
            %
            % The graph information GINFO is a structure with the following fields:
            % Fieldname              | Description
            % ---------------------------------------------------------------------
            % nodes                  | The epochnodes (see ndi.epoch.epochset/EPOCHNODE)
            % G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
            %                        |   converting between node i and j.
            % mapping                | A cell matrix with ndi.time.timemapping objects that describes the
            %                        |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
            %
            [ginfo, hashvalue] = cached_graphinfo(ndi_syncgraph_obj);
            if isempty(ginfo)
                ginfo = ndi_syncgraph_obj.buildgraphinfo();
                set_cached_graphinfo(ndi_syncgraph_obj, ginfo);
            end
        end % graphinfo

        function [ginfo] = buildgraphinfo(ndi_syncgraph_obj)
            % BUILDGRAPHINFO - build graph info for an ndi.time.syncgraph object
            %
            % [GINFO] = BUILDGRAPHINFO(NDI_SYNCGRAPH_OBJ)
            %
            % Builds from scratch the syncgraph structure GINFO from all of the devices
            % in the NDI_SYNCGRAPH_OBJ's associated 'session' property.
            %
            % The graph information GINFO is a structure with the following fields:
            % Fieldname              | Description
            % ---------------------------------------------------------------------
            % nodes                  | The epochnodes (see ndi.epoch.epochset/EPOCHNODE)
            % G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
            %                        |   converting between node i and j.
            % mapping                | A cell matrix with ndi.time.timemapping objects that describes the
            %                        |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
            % diG                    | The graph data structure in Matlab for G (a 'digraph')
            % syncRule_IDs           | The document IDs of the syncrules
            % syncRule_G             | The syncRule graph matrix; if syncRule_G(i,j)==k, then syncRule_IDs{k}
            %                        |   was used to determine G(i,j) and mapping{i,j}
            %
            ginfo.nodes = vlt.data.emptystruct('epoch_id','epoch_session_id','epochprobemap',...
                'epoch_clock','t0_t1','underlying_epochs','objectname','objectclass');
            ginfo.G = [];
            ginfo.mapping = {};
            ginfo.diG = [];
            ginfo.syncRuleIDs = {};
            ginfo.syncRuleG = [];

            % update syncRuleIDs

            for i=1:numel(ndi_syncgraph_obj.rules)
                ginfo.syncRuleIDs{i} = ndi_syncgraph_obj.rules{i}.id();
            end

            d = ndi_syncgraph_obj.session.daqsystem_load('name','(.*)');
            if ~iscell(d) & ~isempty(d), d = {d}; end % make sure we are a cell

            for i=1:numel(d)
                ginfo = ndi_syncgraph_obj.addepoch(d{i}, ginfo);
            end
        end % buildgraphinfo

        function [ginfo,hashvalue]=cached_graphinfo(ndi_syncgraph_obj)
            % CACHED_GRAPHINFO - return the cached graph info of an ndi.time.syncgraph object
            %
            % [GINFO, HASHVALUE] = CACHED_EPOCHTABLE(NDI_SYNCGRAPH_OBJ)
            %
            % Return the cached version of the graph info, if it exists, along with its HASHVALUE
            % (a hash number generated from the graph info). If there is no cached version,
            % GINFO and HASHVALUE will be empty.
            %
            ginfo = [];
            hashvalue = [];
            [cache,key] = getcache(ndi_syncgraph_obj);
            if (~isempty(cache) & ~isempty(key))
                table_entry = cache.lookup(key,'syncgraph-hash');
                if ~isempty(table_entry)
                    ginfo = table_entry(1).data.graphinfo;
                    hashvalue = table_entry(1).data.hashvalue;
                    ginfo = ndi.time.syncgraph.cache2ginfo(ginfo);
                end
            end
        end % cached_epochtable

        function remove_cached_graphinfo(ndi_syncgraph_obj)
            % REMOVE_CACHED_GRAPHINFO
            %
            % REMOVE_CACHED_GRAPHINFO(NDI_SYNCGRAPH_OBJ)
            %
            % Remove the cached graph info.
            %
            % See also: CACHE_GRAPHINFO, SET_CACHE_GRAPHINFO
            [cache,key] = getcache(ndi_syncgraph_obj);
            if ~isempty(cache)
                cache.remove(key,'syncgraph-hash');
            end
        end % remove_cached_graphinfo

        function set_cached_graphinfo(ndi_syncgraph_obj, ginfo)
            % SET_CACHED_GRAPHINFO
            %
            % SET_CACHED_GRAPHINFO(NDI_SYNCGRAPH_OBJ, GINFO)
            %
            % Set the cached graph info. Opposite of CACHE_GRAPHINFO.
            %
            % See also: CACHE_GRAPHINFO
            [cache,key] = getcache(ndi_syncgraph_obj);
            if ~isempty(cache)
                hashvalue = 0; % why use this? vlt.data.hashmatlabvariable(ginfo);
                priority = 1;
                cache.remove(key,'syncgraph-hash');
                ginfo_small = ndi.time.syncgraph.ginfo2cache(ginfo);
                cache.add(key,'syncgraph-hash',struct('graphinfo',ginfo_small,'hashvalue',hashvalue),priority);
            end
        end % set_cached_graphinfo

        function d = ingest(ndi_syncgraph_obj)
            % INGEST - create objects to be ingested to store the latest syncgraph
            %
            % D = INGEST(NDI_SYNCGRAPH_OBJ)
            %
            % Create ingestion documents from the current syncrules, devices, and epochs.
            %
            % First, this function removes the existing syncgraph and rebuilds it,
            % in case any epochs have been added since the last run.
            %
            % Existing sync mappings will not be overwritten.
            %
            d = {};
            mylog = ndi.common.getLogger();
            mylog.msg('system',5,['Recalculating syncgraph...']);

            epoch_node_fields = {'epoch_id','epoch_session_id','epochprobemap','epoch_clock','t0_t1','objectname','objectclass'};

            remove_cached_graphinfo(ndi_syncgraph_obj);

            syncgraph_id = ndi_syncgraph_obj.id();

            ginfo = graphinfo(ndi_syncgraph_obj); % this will rebuild the syncgraph

            d_i = ndi_syncgraph_obj.get_ingested();

            [I,J] = find(ginfo.syncRuleG);
            for i=1:numel(I)
                % check for match in saved list
                match = 0;
                for k=1:numel(d_i)
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_a.epoch_id,...
                        ginfo.nodes(I(i)).epoch_id);
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_b.epoch_id,...
                        ginfo.nodes(J(i)).epoch_id);
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_a.epoch_clock,...
                        ginfo.nodes(I(i)).epoch_clock.ndi_clocktype2char());
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_b.epoch_clock,...
                        ginfo.nodes(J(i)).epoch_clock.ndi_clocktype2char());
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_a.objectname,...
                        ginfo.nodes(I(i)).objectname);
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_b.objectname,...
                        ginfo.nodes(J(i)).objectname);
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_a.epoch_session_id,...
                        ginfo.nodes(I(i)).epoch_session_id);
                    if ~test, continue; end
                    test = strcmp(d_i{k}.document_properties.syncrule_mapping.epochnode_b.epoch_session_id,...
                        ginfo.nodes(J(i)).epoch_session_id);
                    if ~test, continue; end
                    % if we are still here, we match
                    match = k;
                    disp(['We matched!']);
                end

                if match==0 % we don't have it already saved
                    sync_mapping_struct = [];
                    sync_mapping_struct.cost = ginfo.G(I(i),J(i));
                    sync_mapping_struct.mapping = ginfo.mapping{I(i),J(i)}.mapping;
                    sync_mapping_struct.epochnode_a = [];
                    sync_mapping_struct.epochnode_b = [];
                    for f=1:numel(epoch_node_fields)
                        sync_mapping_struct.epochnode_a = ...
                            setfield(sync_mapping_struct.epochnode_a,...
                            epoch_node_fields{f},...
                            getfield(ginfo.nodes(I(i)),epoch_node_fields{f}));
                        sync_mapping_struct.epochnode_b = ...
                            setfield(sync_mapping_struct.epochnode_b,...
                            epoch_node_fields{f},...
                            getfield(ginfo.nodes(J(i)),epoch_node_fields{f}));
                    end
                    sync_mapping_struct.epochnode_a.epochprobemap = sync_mapping_struct.epochnode_a.epochprobemap.serialize();
                    sync_mapping_struct.epochnode_b.epochprobemap = sync_mapping_struct.epochnode_b.epochprobemap.serialize();
                    sync_mapping_struct.epochnode_a.epoch_clock = sync_mapping_struct.epochnode_a.epoch_clock.ndi_clocktype2char();
                    sync_mapping_struct.epochnode_b.epoch_clock = sync_mapping_struct.epochnode_b.epoch_clock.ndi_clocktype2char();
                    d{end+1} = ndi.document('syncrule_mapping','syncrule_mapping',sync_mapping_struct) + ndi_syncgraph_obj.session.newdocument();
                    d{end} = d{end}.set_dependency_value('syncgraph_id',syncgraph_id);
                    d{end} = d{end}.set_dependency_value('syncrule_id',ginfo.syncRuleIDs{ginfo.syncRuleG(I(i),J(i))});
                end
            end

        end % ingest

        function d = get_ingested(ndi_syncgraph_obj)
            % GET_INGESTED - get ingested documents for an ndi.syncgraph object
            %
            % D = GET_INGESTED(NDI_SYNCGRAPH_OBJ)
            %
            % Get current ingested sync mappings.
            %
            q_savedRules = ndi.query('','isa','syncrule_mapping') & ...
                ndi.query('','depends_on','syncgraph_id',ndi_syncgraph_obj.id());
            %  ( ndi.query('syncrule_mapping.epochnode_a.objectname','exact_string',ndi_daqsystem_obj.name) | ...
            %    ndi.query('syncrule_mapping.epochnode_b.objectname','exact_string',ndi_daqsystem_obj.name));
            d = ndi_syncgraph_obj.session.database_search(q_savedRules);
        end % get_ingested()

        function ginfo = addepoch(ndi_syncgraph_obj, ndi_daqsystem_obj, ginfo)
            % ADDEPOCH - add an ndi.epoch.epochset to the graph
            %
            % NEW_GINFO = ADDEPOCH(NDI_SYNCGRAPH_OBJ, NDI_DAQSYSTEM_OBJ, GINFO)
            %
            % Adds an ndi.epoch.epochset to the ndi.time.syncgraph
            %
            % Note: this does not update the cache
            %

            % Step 1: make sure we have the right kind of input object
            if ~isa(ndi_daqsystem_obj, 'ndi.daq.system')
                error(['The input NDI_DAQSYSTEM_OBJ must be of class ndi.daq.system or a subclass.']);
            end

            % Step 2: make sure it is not duplicative

            if numel(ginfo)>0
                tf = strcmp(ndi_daqsystem_obj.name,{ginfo.nodes.objectname});
            else
                tf = [];
            end
            if any(tf) % we already have this object
                % in the future, we'll make this method that saves time. For initial development, we'll complain
                % ginfo = updateepochs(ndi_syncgraph_obj, ndi_daqsystem_obj, ginfo);
                % return;
                error(['This graph already has epochs from ' name '.']);
            end

            % Step 3: ok, we have established it is novel, add it to our graph

            % Step 3.1: add the within-device graph to our graph

            newnodes = ndi_daqsystem_obj.epochnodes();
            [newcost,newmapping] = ndi_daqsystem_obj.epochgraph;

            oldn = numel(ginfo.nodes);
            newn = numel(newnodes);

            ginfo.nodes = cat(2,ginfo.nodes(:)',newnodes(:)');

            ginfo.G = [ ginfo.G inf(oldn,newn); inf(newn,oldn) newcost ] ;
            ginfo.mapping = [ ginfo.mapping cell(oldn,newn) ; cell(newn,oldn) newmapping];
            ginfo.syncRuleG = [ ginfo.syncRuleG  zeros(oldn,newn); zeros(newn,oldn) zeros(size(newcost)) ];

            % Step 3.2: add any 'duh' connections ('utc' -> 'utc', etc) based purely on ndi.time.clocktype

            % the brute force way; could be better if we expect low diversity of epoch_clocks, which we do;
            % we can do better, could search for all clocka->clockb instances

            for i=1:oldn
                for j=oldn+1:oldn+newn
                    if i~=j
                        [ginfo.G(i,j),ginfo.mapping{i,j}] = ...
                            ginfo.nodes(i).epoch_clock.epochgraph_edge(ginfo.nodes(j).epoch_clock);
                        [ginfo.G(j,i),ginfo.mapping{j,i}] = ...
                            ginfo.nodes(j).epoch_clock.epochgraph_edge(ginfo.nodes(i).epoch_clock);
                        delta = abs(ginfo.nodes(i).t0_t1(1)-ginfo.nodes(j).t0_t1(1));
                    end
                end
            end

            % Step 3.3: now add any connections based on applying rules

            % first load any saved rules

            q_savedRules = ndi.query('','isa','syncrule_mapping') & ...
                ndi.query('','depends_on','syncgraph_id',ndi_syncgraph_obj.id()) & ...
                ( ndi.query('syncrule_mapping.epochnode_a.objectname','exact_string',ndi_daqsystem_obj.name) | ...
                ndi.query('syncrule_mapping.epochnode_b.objectname','exact_string',ndi_daqsystem_obj.name));
            savedRules = ndi_syncgraph_obj.session.database_search(q_savedRules);

            for i=1:oldn
                for j=oldn+1:oldn+newn
                    if i~=j
                        for k=1:2
                            if k==1
                                i_ = i;
                                j_ = j;
                            else
                                i_ = j;
                                j_ = i;
                            end
                            lowcost = Inf;
                            mappinghere = [];
                            match = 0;
                            for K=1:numel(ndi_syncgraph_obj.rules)
                                % check here to see if we have a match already saved
                                [c,m] = ndi.time.syncgraph.checkingestedrules(savedRules, ginfo.syncRuleIDs{K}, ginfo.nodes(i_), ginfo.nodes(j_));
                                if isempty(c)
                                    [c,m] = apply(ndi_syncgraph_obj.rules{K}, ginfo.nodes(i_), ginfo.nodes(j_));
                                end
                                if c<lowcost
                                    lowcost = c;
                                    mappinghere = m;
                                    match = K;
                                end
                            end
                            if isempty(mappinghere) & ~isinf(lowcost)
                                error('this is an error. notify developers. we did not think we could get here.');
                            end
                            ginfo.G(i_,j_) = lowcost;
                            ginfo.mapping{i_,j_} = mappinghere;
                            if match
                                ginfo.syncRuleG(i_,j_) = K;
                            end
                        end
                    end
                end
            end

            Gtable = ginfo.G;
            Gtable(find(isinf(Gtable))) = 0;
            ginfo.diG = digraph(Gtable);

        end % addepoch

        function ginfo = addunderlyingepochs(ndi_syncgraph_obj, ndi_epochset_obj, ginfo)
            % ADDUNDERLYINGEPOCHS - add an ndi.epoch.epochset to the graph
            %
            % NEW_GINFO = ADDUNDERLYINGEPOCHS(NDI_SYNCGRAPH_OBJ, NDI_EPOCHSET_OBJ, GINFO)
            %
            % Adds an ndi.epoch.epochset to the ndi.time.syncgraph
            %
            % Note: this DOES update the cache
            %
            % Step 1: make sure we have the right kind of input object
            if ~isa(ndi_epochset_obj, 'ndi.epoch.epochset')
                error(['The input NDI_EPOCHSET_OBJ must be of class ndi.epoch.epochset or a subclass.']);
            end

            enodes = epochnodes(ndi_epochset_obj);
            % do we search for duplicates?
 
            mylog = ndi.common.getLogger();
            for i=1:numel(enodes)
                mylog.msg('system',5,['Working through graph, element ' int2str(i) ' of ' int2str(numel(enodes)) '...']);

                index = ndi.epoch.findepochnode(enodes(i), ginfo.nodes);

                if isempty(index) % we don't have this one, we need to add it

                    % underlying_nodes = underlyingepochnodes(ndi_epochset_obj, enodes(i));

                    [u_nodes,u_cost,u_mapping] = underlyingepochnodes(ndi_epochset_obj, enodes(i));

                    % now we have a set of elements to add to the graph

                    u_node_index_in_main = NaN(numel(u_nodes),1);
                    for j=1:numel(u_nodes)
                        myindex = ndi.epoch.findepochnode(u_nodes(j), ginfo.nodes);
                        if ~isempty(myindex)
                            u_node_index_in_main(j) = myindex;
                        end
                    end

                    nodenumbers2_1 = u_node_index_in_main; % what are the node numbers in the nodes to be added? or NaN if not there
                    nanshere = find(isnan(nodenumbers2_1));
                    nodenumbers2_1(nanshere) = numel(ginfo.nodes)+(1:numel(nanshere));

                    [newG, G_indexes, numnewnodes] = vlt.graph.mergegraph(ginfo.G, u_cost, nodenumbers2_1);
                    [newSyncRuleG, newSyncRuleG_indexes, numnewnodes] = vlt.graph.mergegraph(ginfo.syncRuleG, 0*u_cost, nodenumbers2_1);
                    newSyncRuleG(isinf(newSyncRuleG)) = 0;
                    newSyncRuleG(isnan(newSyncRuleG)) = 0; % trying
                    mapping_upperright = cell(size(ginfo.G,1), numnewnodes);
                    mapping_upperright(G_indexes.upper_right.merged) = u_mapping(G_indexes.upper_right.G2);
                    mapping_lowerleft = cell(numnewnodes,size(ginfo.G,1));
                    mapping_lowerleft(G_indexes.lower_left.merged) = u_mapping(G_indexes.lower_left.G2);
                    mapping_lowerright = u_mapping(G_indexes.lower_right);

                    ginfo.nodes = cat(2,ginfo.nodes,u_nodes(nanshere));
                    ginfo.G = newG;
                    ginfo.mapping = [ginfo.mapping mapping_upperright ; mapping_lowerleft mapping_lowerright ];
                    syncRulesmall = spalloc(size(newSyncRuleG,1),size(newSyncRuleG,2),nnz(newSyncRuleG));
                    syncRulesmall(:) = newSyncRuleG(:);
                    ginfo.syncRuleG = syncRulesmall; % seems to hog memory without sparse reconversion

                    % developer question: should we bother to check for links that matter?
                    %                     right now, let's check that the first epochnode is connected at all
                end
            end

            % make sure all utc and exp_global_time clocks map onto one another
            c_utc = ndi.time.clocktype('utc');
            c_exp_global_time = ndi.time.clocktype('exp_global_time');
            equivalent_clock_list = {c_utc, c_exp_global_time};
            for i=1:numel(equivalent_clock_list)
                matches = find(cellfun(@(x) eq(x,equivalent_clock_list{i}),{ginfo.nodes.epoch_clock}));
                for j=1:numel(matches)
                    for k=1:numel(matches)
                        if (matches(j)~=matches(k)) &  strcmp(ginfo.nodes(matches(i)).objectname,ginfo.nodes(matches(j)).objectname)
                            % self is still 1, and across-object maps are still 1
                            ginfo.G(matches(j),matches(k)) = 77;
                            ginfo.mapping{matches(j),matches(k)} = ndi.time.timemapping([1 0]);
                        end
                    end
                end
            end

            Gtable = ginfo.G;
            Gtable(find(isinf(Gtable))) = 0;
            ginfo.diG = digraph(Gtable);

            ndi_syncgraph_obj.set_cached_graphinfo(ginfo);
        end % addunderlyingnodes

        function ginfo = removeepoch(ndi_syncgraph_obj, ndi_daqsystem_obj, ginfo)
            % REMOVEEPOCH - remove an ndi.epoch.epochset from the graph
            %
            % GINFO = REMOVEEPOCH(NDI_SYNCGRAPH_OBJ, NDI_DAQSYSTEM_OBJ, GINFO)
            %
            % Remove all epoch nodes from the graph that are contributed by NDI_DAQSYSTEM_OBJ
            %
            % Note: this does not update the cache

            tf = find(strcmp(ndi_daqsystem_obj.name,{ginfo.nodes.objectname}));

            keep = setdiff(1:numel(ginfo.nodes));

            ginfo.G = ginfo.G(keep,keep);
            ginfo.mapping = ginfo.mapping(keep,keep);
            ginfo.nodes = ginfo.nodes(keep);
            ginfo.syncRuleG = ginfo.syncRuleG(keep,keep);

            Gtable = ginfo.G;
            Gtable(find(isinf(Gtable))) = 0;
            ginfo.diG = digraph(Gtable);

        end % removeepoch

        function [t_out, timeref_out, msg] = time_convert(ndi_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out)
            % TIME_CONVERT - convert time from one ndi.time.timereference to another
            %
            % [T_OUT, TIMEREF_OUT, MSG] = TIME_CONVERT(NDI_SYNCGRAPH_OBJ, TIMEREF_IN, T_IN, REFERENT_OUT, CLOCKTYPE_OUT)
            %
            % Attempts to convert a time T_IN that is referred to by ndi.time.timereference object TIMEREF_IN
            % to T_OUT that is referred to by the requested REFERENT_OUT object (must be type ndi.epoch.epochset and NDI_BASE)
            % with the requested ndi.time.clocktype CLOCKTYPE_OUT.
            %
            % T_OUT is the output time with respect to the ndi.time.timereference TIMEREF_OUT that incorporates REFERENT_OUT
            % and CLOCKTYPE_OUT with the appropriate epoch and time reference.
            %
            % If the conversion cannot be made, T_OUT is empty and MSG contains a text message describing
            % why the conversion could not be made.
            %

            arguments
                ndi_syncgraph_obj (1,1) ndi.time.syncgraph
                timeref_in (1,1) ndi.time.timereference
                t_in double
                referent_out (1,1) ndi.epoch.epochset
                clocktype_out (1,1) ndi.time.clocktype
            end
            t_out = [];
            timeref_out = [];
            msg = '';
            et = NaN;

            % Step 0: check inputs

            in_epochid = '';

            if ~isempty(timeref_in.epoch)
                if isnumeric(timeref_in.epoch) % we have an epoch number
                    in_epochid = epochid(timeref_in.referent, timeref_in.epoch);
                else
                    in_epochid = timeref_in.epoch;
                end
            else
                % this only works with a global type clock
                ndi.time.clocktype.assertGlobal(timeref_in.clocktype);
                et = timeref_in.referent.epochtable();
                for j=1:numel(et)
                    index = find(cellfun(@(x) eq(x,timeref_in.clocktype),et(j).epoch_clock));
                    if ~isempty(index)
                        if et(j).t0_t1{index}(1)<=(timeref_in.time+t_in) && (timeref_in.time+t_in)<=et(j).t0_t1{index}(2) 
                            in_epochid = et(j).epoch_id;
                            break;
                        end
                    end
                end
                if isempty(in_epochid)
                    error(['Did not find parent epoch for timeref.']);
                end
            end

            if (timeref_in.referent == referent_out)
                % we do not need to consult the syncgraph, we know the epoch
                if (timeref_in.clocktype==clocktype_out)
                    t_out = t_in; 
                    timeref_out = ndi.time.timereference(referent_out,clocktype_out,in_epochid,timeref_in.time);
                else
                    if isequaln(et,NaN)
                        et = timeref_in.referent.epochtable();
                    end;
                    id_match = find(strcmp({et.epoch_id},in_epochid));
                    if isempty(id_match)
                        error('ndi.time.syncgraph error: unexpected missing epoch, thought this could not happen.');
                    end
                    j1 = find(et(id_match).epoch_clock==timeref_in.clocktype);
                    j2 = find(et(id_match).epoch_clock==clocktype_out);
                    if isempty(j2)
                        error(['No clock type ' clocktype_out.type ' for requested referent.']);
                    end
                    corrected_t0t1 = et(id_match).t0_t1{j1} - timeref_in.time;
                    t_out = vlt.math.rescale(t_in, corrected_t0t1, et(id_match).t0_t1{j2},'noclip');
                    timeref_out = ndi.time.timereference(referent_out,clocktype_out,in_epochid,0);
                end
                return
            end

            ginfo = graphinfo(ndi_syncgraph_obj);

            % STEP 1: identify the source node

            sourcenodeindex = ndi.epoch.findepochnode(...
                struct('objectname',epochsetname(timeref_in.referent), 'objectclass', class(timeref_in.referent),...
                'epoch_id',in_epochid, 'epoch_session_id', ndi_syncgraph_obj.session.id(), ...
                'epoch_clock', timeref_in.clocktype),...
                ginfo.nodes);

            % should be a single item now
            if numel(sourcenodeindex)>1
                msg = ['expected start epochnode to be a single node, but it is not.'];
                return;
            elseif numel(sourcenodeindex)==0
                % we do not have the node; add underlying epochs and try one more time
                ndi_syncgraph_obj.addunderlyingepochs(timeref_in.referent,ginfo);
                ginfo = graphinfo(ndi_syncgraph_obj);

                sourcenodeindex = ndi.epoch.findepochnode(...
                    struct('objectname',epochsetname(timeref_in.referent), 'objectclass', class(timeref_in.referent),...
                    'epoch_id',in_epochid, 'epoch_session_id', ndi_syncgraph_obj.session.id(), ...
                    'epoch_clock', timeref_in.clocktype),...
                    ginfo.nodes);

                if numel(sourcenodeindex)==0
                    msg = ['Could not find any such source node.'];
                    return;
                elseif numel(sourcenodeindex)>1
                    msg = ['expected start epochnode to be a single node, but it is not.'];
                    return;
                end
                % if we made it here, we are in good shape with a sourcenodeindex that is real
            end

            if isempty(sourcenodeindex), return; end % if we did not find it, we failed

            % STEP 2: narrow the search for the destination node. It has to match our referent and it has to
            %     match the requested clock type

            destinationNodeProperties = struct('objectname', epochsetname(referent_out), 'objectclass', class(referent_out), ...
                'epoch_clock', clocktype_out);
            if ndi.time.clocktype.isGlobal(clocktype_out) & ndi.time.clocktype.isGlobal(timeref_in.clocktype)
                destinationNodeProperties.time_value = timeref_in.time+t_in;
            end

            destinationnodeindexes = ndi.epoch.findepochnode(...
                destinationNodeProperties, ginfo.nodes);

            if isempty(destinationnodeindexes)
                % no candidate output nodes, see if any are there any from that referent
                any_referent_outs = ndi.epoch.findepochnode(...
                    struct('objectname', epochsetname(referent_out), 'objectclass', class(referent_out)), ...
                    ginfo.nodes);
                if isempty(any_referent_outs) % add the referent to the table and try again
                    new_ginfo = ndi_syncgraph_obj.addunderlyingepochs(referent_out,ginfo);
                    if numel(new_ginfo.nodes)~=numel(ginfo.nodes) % if we added a node, we can keep searching
                        [t_out,timeref_out,msg] = time_convert(ndi_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out);
                        return;
                    end
                end
                % if we are still here, we failed in our search
                msg = ['Could not find any such destination node.'];
                return;
            end

            % STEP 3: are there any paths from our source to any of the candidate destinations?
            D = distances(ginfo.diG,sourcenodeindex,destinationnodeindexes);
            indexes = find(~isinf(D));
            if numel(indexes)>1
                [minDistance,minIndex] = min(D);
                indexes = indexes(minIndex);
            elseif numel(indexes)==0
                msg = 'Cannot get there from here, no path';
                return;
            end

            destinationnodeindex = destinationnodeindexes(indexes);

            % make the timeref_out based on the node we found, use timeref of 0
            timeref_out = ndi.time.timereference(referent_out, ginfo.nodes(destinationnodeindex).epoch_clock, ...
                ginfo.nodes(destinationnodeindex).epoch_id, 0);

            path = shortestpath(ginfo.diG, sourcenodeindex, destinationnodeindex);
            if ~isempty(path)
                t_out = t_in-timeref_in.time;
                for i=1:numel(path)-1
                    t_out = ginfo.mapping{path(i),path(i+1)}.map(t_out);
                end
            end
        end % time_convert()

        % methods that override NDI_BASE:

        % cache

        function [cache,key] = getcache(ndi_syncgraph_obj)
            % GETCACHE - return the NDI_CACHE and key for ndi.time.syncgraph
            %
            % [CACHE,KEY] = GETCACHE(NDI_SYNCGRAPH_OBJ)
            %
            % Returns the CACHE and KEY for the ndi.time.syncgraph object.
            %
            % The CACHE is returned from the associated session.
            % The KEY is the string 'syncgraph_' followed by the object's id.
            %
            % See also: ndi.time.syncgraph, NDI_BASE

            cache = [];
            key = [];
            if isa(ndi_syncgraph_obj.session,'handle')
                exp = ndi_syncgraph_obj.session;
                cache = exp.cache;
                key = ['syncgraph_' ndi_syncgraph_obj.id()];
            end
        end % getcache()

        %% functions that override ndi.documentservice

        function ndi_document_obj_set = newdocument(ndi_syncgraph_obj)
            % NEWDOCUMENT - create a new ndi.document for an ndi.time.syncgraph object
            %
            % NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_SYNCGRAPH_OBJ)
            %
            % Creates an ndi.document object DOC that represents the
            %    ndi.time.syncrule object.
            ndi_document_obj_set{1} = ndi.document('syncgraph',...
                'syncgraph.ndi_syncgraph_class',class(ndi_syncgraph_obj),...
                'base.id', ndi_syncgraph_obj.id(),...
                'base.session_id', ndi_syncgraph_obj.session.id());
            for i=1:numel(ndi_syncgraph_obj.rules)
                ndi_document_obj_set{end+1} = ndi_syncgraph_obj.rules{i}.newdocument();
                ndi_document_obj_set{1} = ndi_document_obj_set{1}.add_dependency_value_n('syncrule_id',ndi_syncgraph_obj.rules{i}.id());
            end
        end % newdocument()

        function sq = searchquery(ndi_syncgraph_obj)
            % SEARCHQUERY - create a search for this ndi.time.syncgraph object
            %
            % SQ = SEARCHQUERY(NDI_SYNCGRAPH_OBJ)
            %
            % Creates a search query for the ndi.time.syncgraph object.
            %
            sq = ndi.query({'base.id', ndi_syncgraph_obj.id() , ...
                'base.session_id', ndi_syncgraph_obj.session.id() });
        end % searchquery()
    end % methods

    methods (Static)
        function [syncgraph_doc, syncrule_docs] = load_all_syncgraph_docs(ndi_session_obj, syncgraph_doc_id)
            % LOAD_ALL_SYNCGRAPH_DOCS - load a syncgraph document and all of its syncrules
            %
            % [SYNCGRAPH_DOC, SYNCRULE_DOCS] = LOAD_ALL_SYNCGRAPH_DOCS(NDI_SESSION_OBJ,...
            %                    SYNCGRAPH_DOC_ID)
            %
            % Given an ndi.session object and the document identifier of an ndi.time.syncgraph object,
            % this function loads the ndi.document associated with the SYNCGRAPH (SYNCGRAPH_DOC) and all of
            % the documents of its SYNCRULES (cell array of NDI_DOCUMENTS in SYNCRULES_DOC).
            %
            syncrule_docs = {};
            syncgraph_doc = ndi_session_obj.database_search(ndi.query('base.id', 'exact_string', ...
                syncgraph_doc_id,''));
            switch numel(syncgraph_doc)
                case 0
                    syncgraph_doc = [];
                    return;
                case 1
                    syncgraph_doc = syncgraph_doc{1};
                otherwise
                    error(['More than 1 document with base.id value of ' ...
                        syncgraph_doc_id '. Do not know what to do.']);
            end

            rules_id_list = syncgraph_doc.dependency_value_n('syncrule_id','ErrorIfNotFound',0);
            for i=1:numel(rules_id_list)
                rules_doc = ndi_session_obj.database_search(ndi.query(...
                    'base.id','exact_string',rules_id_list{i},''));
                if numel(rules_doc)~=1
                    error(['Could not find syncrule with id ' rules_id_list{i} ...
                        '; found ' int2str(numel(rules_doc)) ' occurrences']);
                end
                syncrule_docs{i} = rules_doc{1};
            end
        end % load_all_syncgraph_docs()

        function [c,m] = checkingestedrules(ingested_syncrule_docs, ndi_syncrule_obj_id, gnode_i, gnode_j)
            % CHECKINGESTEDRULES - check for a mapping between two nodes in the ingested syncrules
            %
            % [C,M] = CHECKINGESTEDRULES(INGESTED_SYNCRULE_DOCS, NDI_SYNCRULE_OBJ, GNODE_I, GNODE_J)
            %
            % Check a set of ingested syncrule documents to see if there is any information about
            % a mapping between graphnodes GNODE_I and GNODE_J.
            %
            % If there is, the mapping M with the lowest cost C is returned. Otherwise, C is Inf and
            % M is empty.
            %

            matches = [];
            c = Inf*ones(numel(ingested_syncrule_docs),1);
            m = cell(numel(ingested_syncrule_docs),1);

            for i=1:numel(ingested_syncrule_docs)
                test = strcmp(ingested_syncrule_docs{i}.dependency_value('syncrule_id'), ndi_syncrule_obj_id);
                if ~test, continue; end
                test = strcmp(gnode_i.epoch_id,ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_a.epoch_id);
                if ~test, continue; end
                test = strcmp(gnode_i.epoch_session_id,ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_a.epoch_session_id);
                if ~test, continue; end
                test = strcmp(gnode_i.epoch_clock.ndi_clocktype2char(),ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_a.epoch_clock);
                if ~test, continue; end
                test = strcmp(gnode_j.epoch_id,ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_b.epoch_id);
                if ~test, continue; end
                test = strcmp(gnode_j.epoch_session_id,ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_b.epoch_session_id);
                if ~test, continue; end
                test = strcmp(gnode_j.epoch_clock.ndi_clocktype2char(),ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_b.epoch_clock);
                if ~test, continue; end
                test = strcmp(gnode_i.objectname,ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_a.objectname);
                if ~test, continue; end
                test = strcmp(gnode_j.objectname,ingested_syncrule_docs{i}.document_properties.syncrule_mapping.epochnode_b.objectname);
                if ~test, continue; end

                c(i) = ingested_syncrule_docs{i}.document_properties.syncrule_mapping.cost;
                m{i} = ingested_syncrule_docs{i}.document_properties.syncrule_mapping.mapping;

            end

            [min_c,min_c_loc] = min(c);
            if isinf(c)
                m = [];
            else
                c = min_c;
                m = ndi.time.timemapping(m{min_c_loc});
            end
        end

        function ginfo_small = ginfo2cache(ginfo)
        % GINFO2CACHE Make a smaller version of the GINFO for storage in the cache
        %
        % GINFO_SMALL = GINFO2CACHE(GINFO)
        % 
            tf = ~cellfun(@isempty,ginfo.mapping(:));
            mapping_linear = ginfo.mapping(tf);
            G_sparse = ginfo.G;
            G_sparse(isinf(G_sparse)) = 0;
            G_sparse = sparse(G_sparse);
            ginfo_small.nodes = ginfo.nodes;
            ginfo_small.G_sparse = G_sparse;
            ginfo_small.mapping_linear = mapping_linear;
            ginfo_small.mapping_indexes = find(tf);
            ginfo_small.diG = ginfo.diG;
            ginfo_small.syncRuleIDs = ginfo.syncRuleIDs;
            ginfo_small.syncRuleG = ginfo.syncRuleG;
        end

        function ginfo_big = cache2ginfo(ginfo_small)
        % CACHE2GINFO Make a regular GINFO from the smaller information stored in the cache
        %
        % GINFO_BIG = GINFO2CACHE(GINFO_SMALL)
        % 
           if ~isfield(ginfo_small,'mapping_linear')
               ginfo_big = ginfo_small; % no compression
               return;
           end
           ginfo_big.nodes = ginfo_small.nodes;
           G = full(ginfo_small.G_sparse);
           G(G==0) = Inf;
           ginfo_big.G = G;
           ginfo_big.mapping = cell(numel(ginfo_big.nodes),numel(ginfo_big.nodes));
           ginfo_big.mapping(ginfo_small.mapping_indexes) = ginfo_small.mapping_linear;
           ginfo_big.diG = ginfo_small.diG;
           ginfo_big.syncRuleIDs = ginfo_small.syncRuleIDs;
           ginfo_big.syncRuleG = ginfo_small.syncRuleG;
        end % cache2ginfo

    end % static methods

end % classdef ndi.time.syncgraph
