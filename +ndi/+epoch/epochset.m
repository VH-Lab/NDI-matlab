classdef epochset
    % NDI_EPOCHSET - routines for managing a set of epochs and their dependencies
    %
    %

    properties (SetAccess=protected,GetAccess=public)

    end % properties
    properties (SetAccess=protected,GetAccess=protected)
    end % properties

    methods

        function obj = epochset()
            % ndi.epoch.epochset - constructor for ndi.epoch.epochset objects
            %
            % NDI_EPOCHSET_OBJ = ndi.epoch.epochset()
            %
            % This class has no parameters so the constructor is called with no input arguments.
            %

        end % ndi.epoch.epochset

        function n = numepochs(ndi_epochset_obj)
            % NUMEPOCHS - Number of epochs of ndi.epoch.epochset
            %
            % N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
            %
            % Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
            %
            % See also: EPOCHTABLE
            n = numel(epochtable(ndi_epochset_obj));
        end % numepochs

        function [et,hashvalue] = epochtable(ndi_epochset_obj)
            % EPOCHTABLE - Return an epoch table that relates the current object's epochs to underlying epochs
            %
            % [ET,HASHVALUE] = EPOCHTABLE(NDI_EPOCHSET_OBJ)
            %
            % ET is a structure array with the following fields:
            % Fieldname:                | Description
            % ------------------------------------------------------------------------
            % 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
            % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
            %                           |   This epoch ID uniquely specifies the epoch.
            % 'epoch_session_id'           | The session ID that contains this epoch
            % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
            % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
            % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
            %                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
            % 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
            %                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochprobemap'
            %
            % HASHVALUE is the hashed value of the epochtable. One can check to see if the epochtable
            % has changed with ndi.epoch.epochset/MATCHEDEPOCHTABLE.
            %
            % After it is read from disk once, the ET is stored in memory and is not re-read from disk
            % unless the user calls ndi.epoch.epochset/RESETEPOCHTABLE.
            %
            [cached_et, cached_hash] = cached_epochtable(ndi_epochset_obj);
            if isempty(cached_et) & ~isstruct(cached_et), % is it not a struct? could be a correctly computed empty epochtable, which would be struct
                et = ndi_epochset_obj.buildepochtable();
                hashvalue = vlt.data.hashmatlabvariable(et);
                [cache,key] = getcache(ndi_epochset_obj);
                if ~isempty(cache),
                    priority = 1; % use higher than normal priority
                    cache.add(key,'epochtable-hash',struct('epochtable',et,'hashvalue',hashvalue),priority);
                end
            else,
                et = cached_et;
                hashvalue = cached_hash;
            end;

        end % epochtable

        function epochobjectarray = getepocharray(ndi_epochset_obj)
            % EPOCHTABLE2EPOCHARRAY - convert an epochtable to an array of ndi.epoch objects
            % 
            % E = EPOCHTABLE2EPOCHARRAY(ET, EPOCHSET_OBJECT)
            %
            % Given ET an epochtable of an ndi.epoch.epochset object, produce an array
            % of ndi.epoch objects. It is assumed that the epochtable was generated
            % by the ndi.epoch.epochset object EPOCHSET_OBJECT.
            %

            [et, ~] = ndi_epochset_obj.epochtable();
            
            epochobjectarray = ndi.epoch.empty();
            for i=1:numel(et),
                underlying_epochs = ndi.epoch.empty();
                for j=1:numel(et(i).underlying_epochs)
                   epm = vlt.data.conditional(isempty(et(i).underlying_epochs(j).epochprobemap),...
                        ndi.epoch.epochprobemap.empty(), et(i).underlying_epochs(j).epochprobemap);
                   if iscell(et(i).underlying_epochs(j).underlying),
                       underlying_files = et(i).underlying_epochs(j).underlying;
                       underlying_epochset_object = ndi.epoch.epochset.empty();
                   else,
                       underlying_files = {};
                       underlying_epochset_object = et(i).underlying_epochs(j).underlying;
                   end;
                   e_underlying_here = ndi.epoch('epoch_number',0,...
                       'epoch_id',et(i).underlying_epochs(j).epoch_id,...
                       'epoch_session_id',et(i).underlying_epochs(j).epoch_session_id,...
                       'epochprobemap',epm,...
                       'epoch_clock',[et(i).underlying_epochs(j).epoch_clock{:}],...
                       't0_t1', et(i).underlying_epochs(j).t0_t1,...
                       'epochset_object', underlying_epochset_object,...
                       'underlying_epochs',ndi.epoch.empty(),...
                       'underlying_files', underlying_files);
                   underlying_epochs(end+1) = e_underlying_here; %#ok<AGROW>
                end;
                epm = vlt.data.conditional(isempty(et(i).epochprobemap),...
                        ndi.epoch.epochprobemap.empty(), et(i).epochprobemap);
                e_here = ndi.epoch('epoch_number',et(i).epoch_number,...
                    'epoch_id',et(i).epoch_id,...
                    'epoch_session_id',et(i).epoch_session_id,...
                    'epochprobemap',epm,...
                    'epoch_clock', [et(i).epoch_clock{:}],...
                    't0_t1', et(i).t0_t1,...
                    'epochset_object', ndi_epochset_obj,...
                    'underlying_epochs', underlying_epochs,...
                    'underlying_files',{});
                epochobjectarray(end+1) = e_here; %#ok<AGROW>
            end
        end

        function [et] = buildepochtable(ndi_epochset_obj)
            % BUILDEPOCHTABLE - Build and store an epoch table that relates the current object's epochs to underlying epochs
            %
            % [ET] = BUILDEPOCHTABLE(NDI_EPOCHSET_OBJ)
            %
            % ET is a structure array with the following fields:
            % Fieldname:                | Description
            % ------------------------------------------------------------------------
            % 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
            % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
            %                           |   This epoch ID uniquely specifies the epoch.
            % 'epoch_session_id'        | The session ID that contains this epoch
            % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
            % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
            % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
            %                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
            % 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
            %                           |   It contains fields 'underlying', 'epoch_id', 'epochprobemap', and 'epoch_clock'
            %
            % After it is read from disk once, the ET is stored in memory and is not re-read from disk
            % unless the user calls ndi.epoch.epochset/RESETEPOCHTABLE.
            %
            ue = vlt.data.emptystruct('underlying','epoch_id','epoch_session_id','epochprobemap','epoch_clock','t0_t1');
            et = vlt.data.emptystruct('epoch_number','epoch_id','epoch_session_id','epochprobemap','epoch_clock',...
                't0_t1', 'underlying_epochs');
        end % buildepochtable

        function [et,hashvalue]=cached_epochtable(ndi_epochset_obj)
            % CACHED_EPOCHTABLE - return the cached epochtable of an ndi.epoch.epochset object
            %
            % [ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
            %
            % Return the cached version of the epochtable, if it exists, along with its HASHVALUE
            % (a hash number generated from the table). If there is no cached version,
            % ET and HASHVALUE will be empty.
            %
            et = [];
            hashvalue = [];
            [cache,key] = getcache(ndi_epochset_obj);
            if (~isempty(cache) & ~isempty(key)),
                table_entry = cache.lookup(key,'epochtable-hash');
                if ~isempty(table_entry),
                    et = table_entry(1).data.epochtable;
                    hashvalue = table_entry(1).data.hashvalue;
                end;
            end
        end % cached_epochtable

        function [cache, key] = getcache(ndi_epochset_obj)
            % GETCACHE - return the NDI_CACHE and key for an ndi.epoch.epochset object
            %
            % [CACHE, KEY] = GETCACHE(NDI_EPOCHSET_OBJ)
            %
            % Returns the NDI_CACHE object CACHE and the KEY used by the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
            %
            % In this abstract class, no cache is available, so CACHE and KEY are empty. But subclasses can engage the
            % cache services of the class by returning an NDI_CACHE object and a unique key.
            %
            cache = [];
            key = [];
        end % getcache

        function ndi_epochset_obj = resetepochtable(ndi_epochset_obj)
            % RESETEPOCHTABLE - clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk
            %
            % NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
            %
            % This function clears the internal cached memory of the epochtable, forcing it to be re-read from
            % disk at the next request.
            %
            % See also: ndi.epoch.epochset/EPOCHTABLE

            [cache,key]=getcache(ndi_epochset_obj);
            if (~isempty(cache) & ~isempty(key)),
                cache.remove(key,'epochtable-hash');
            end
        end % resetepochtable

        function b = matchedepochtable(ndi_epochset_obj, hashvalue)
            % MATCHEDEPOCHTABLE - compare a hash number from an epochtable to the current version
            %
            % B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
            %
            % Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
            % Otherwise, it returns 0.

            b = 0;
            [cached_et, cached_hashvalue] = cached_epochtable(ndi_epochset_obj);
            if ~isempty(cached_et),
                b = (hashvalue == cached_hashvalue);
            end
        end % matchedepochtable

        function eid = epochid(ndi_epochset_obj, epoch_number)
            % EPOCHID - Get the epoch identifier for a particular epoch
            %
            % ID = EPOCHID (NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
            %
            % Returns the epoch identifier string for the epoch EPOCH_NUMBER.
            % If it doesn't exist, it should be created. EPOCH_NUMBER can be
            % a number of an EPOCH ID string.
            %
            % The abstract class just queries the EPOCHTABLE.
            % Most classes that manage epochs themselves (ndi.file.navigator,
            % ndi.daq.system) will override this method.
            %
            et = epochtable(ndi_epochset_obj);
            if isnumeric(epoch_number),
                if epoch_number > numel(et),
                    error(['epoch_number out of range (number of epochs==' int2str(numel(et)) ')']);
                end
                eid = et(epoch_number).epoch_id;
            else,  % verify the epoch_id string
                index = find(strcmpi(epoch_number,{et.epoch_id}));
                if isempty(index),
                    error(['epoch_number is a string but does not correspond to any epoch_id']);
                end
                eid = et(index).epoch_id; % gets the capitalization exactly right
            end
        end % epochid

        function et_entry = epochtableentry(ndi_epochset_obj, epoch_number)
            % EPOCHTABLEENTRY - return the entry of the EPOCHTABLE that corresponds to an EPOCHID
            %
            % ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
            %
            % Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
            % that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
            % epoch or the EPOCHID of the epoch.
            %
            et = ndi_epochset_obj.epochtable();
            eid = ndi_epochset_obj.epochid(epoch_number);
            index = find(strcmpi(eid,{et.epoch_id}));
            if isempty(index),
                error(['epoch_number does not correspond to a valid epoch.']);
            end;
            et_entry = et(index);
        end % epochtableentry

        function ec = epochclock(ndi_epochset_obj, epoch_number)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % EC = EPOCHCLOCK(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
            %
            % Return the clock types available for this epoch as a cell array
            % of ndi.time.clocktype objects (or sub-class members).
            %
            % The abstract class always returns ndi.time.clocktype('no_time')
            %
            % See also: ndi.time.clocktype, T0_T1
            %
            ec = {ndi.time.clocktype('no_time')};
        end % epochclock

        function t0t1 = t0_t1(ndi_epochset_obj, epoch_number)
            % T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
            %
            % T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
            %
            % Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
            % in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
            %
            % The abstract class always returns {[NaN NaN]}.
            %
            % See also: ndi.time.clocktype, EPOCHCLOCK
            %
            t0t1 = {[NaN NaN]};
        end % t0t1

        function s = epoch2str(ndi_epochset_obj, number)
            % EPOCH2STR - convert an epoch number or id to a string
            %
            % S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
            %
            % Returns the epoch NUMBER in the form of a string. If it is a simple
            % integer, then INT2STR is used to produce a string. If it is an epoch
            % identifier string, then it is returned.
            if isnumeric(number)
                s = int2str(number);
            elseif iscell(number), % a cell array of strings
                s = [];
                for i=1:numel(number),
                    if (i>2)
                        s=cat(2,s,[', ']);
                    end;
                    s=cat(2,s,number{i});
                end
            elseif ischar(number),
                s = number;
            else,
                error(['Unknown epoch number or identifier.']);
            end;
        end % epoch2str()

        % epochgraph

        function [nodes, underlyingnodes] = epochnodes(ndi_epochset_obj)
            % EPOCHNODES - return all epoch nodes from an ndi.epoch.epochset object
            %
            % [NODES,UNDERLYINGNODES] = EPOCHNODES(NDI_EPOCHSET_OBJ)
            %
            % Return all EPOCHNODES for an ndi.epoch.epochset. EPOCHNODES consist of the
            % following fields:
            % Fieldname:                | Description
            % ------------------------------------------------------------------------
            % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
            %                           |   This epoch ID uniquely specifies the epoch within the session.
            % 'epoch_session_id'           | The ID of the session that contains the epoch
            % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
            % 'epoch_clock'             | A SINGLE ndi.time.clocktype entry that describes the clock type of this node.
            % 't0_t1'                   | The times [t0 t1] of the beginning and end of the epoch in units of 'epoch_clock'
            % 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
            %                           |   It contains fields 'underlying', 'epoch_id', and 'epochprobemap'
            % 'objectname'              | A string containing the 'name' field of NDI_EPOCHSET_OBJ, if it exists. If there is no
            %                           |   'name' field, then 'unknown' is used.
            % 'objectclass'             | The object class name of the NDI_EPOCHSET_OBJ.
            %
            % EPOCHNODES are related to EPOCHTABLE entries, except
            %    a) only 1 ndi.time.clocktype is permitted per epoch node. If an entry in epoch table contains
            %       multiple ndi.time.clocktype entries, then each one will have its own epoch node. This aids
            %       in the construction of the EPOCHGRAPH that helps the system map time from one epoch to another.
            %    b) EPOCHNODES contain identifying information (objectname and objectclass) to help
            %       in identifying the epoch nodes across ndi.epoch.epochset objects.
            %
            % UNDERLYINGNODES are nodes that are directly linked to this ndi.epoch.epochset's node via 'underlying' epochs.
            %
            et = epochtable(ndi_epochset_obj);
            nodes = vlt.data.emptystruct('epoch_id', 'epoch_session_id', 'epochprobemap', ...
                'epoch_clock','t0_t1', 'underlying_epochs', 'objectname', 'objectclass');
            if nargout>1, % only build this if we are asked to do so
                underlyingnodes = vlt.data.emptystruct('epoch_id', 'epoch_session_id', 'epochprobemap', ...
                    'epoch_clock', 't0_t1', 'underlying_epochs');
            end

            for i=1:numel(et),
                for j=1:numel(et(i).epoch_clock),
                    newnode = et(i);
                    newnode = rmfield(newnode,'epoch_number');
                    newnode.epoch_clock = et(i).epoch_clock{j};
                    newnode.t0_t1 = et(i).t0_t1{j};
                    newnode.objectname = epochsetname(ndi_epochset_obj);
                    newnode.objectclass = class(ndi_epochset_obj);
                    nodes(end+1) = newnode;
                end
                if nargout>1,
                    newunodes = underlyingepochnodes(ndi_epochset_obj,epochnode);
                    underlyingnodes = cat(2,underlyingnodes,newunodes);
                end
            end
        end % epochnodes

        function name = epochsetname(ndi_epochset_obj)
            % EPOCHSETNAME - the name of the ndi.epoch.epochset object, for EPOCHNODES
            %
            % NAME = EPOCHSETNAME(NDI_EPOCHSET_OBJ)
            %
            % Returns the object name that is used when creating epoch nodes.
            %
            % If the class has a 'name' property, that property is used.
            % Otherwise, 'unknown' is used.
            %
            name = 'unknown';
            % default behavior is to use the 'name' field
            if any(strcmp('name',fieldnames(ndi_epochset_obj))),
                name = getfield(ndi_epochset_obj,'name');
            end
        end % epochsetname

        function [unodes,cost,mapping] = underlyingepochnodes(ndi_epochset_obj, epochnode)
            % UNDERLYINGEPOCHNODES - find all the underlying epochnodes of a given epochnode
            %
            % [UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
            %
            % Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
            % (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
            %
            % Note that the EPOCHNODE itself is returned as the first 'underlying' node.
            %
            % See also: ISSYNCGRAPHROOT
            %
            unodes = epochnode;
            cost = [1];   % cost has size NxN, where N is (the number of underlying nodes + 1) (1 is the search node)
            trivial_map = ndi.time.timemapping([1 0]);
            mapping = {trivial_map};  % we can get to ourself

            utc = ndi.time.clocktype('utc');
            if unodes(1).epoch_clock == utc,
                % add a dev_local_time mapping
                unode_here = unodes(1);
                unode_here.t0_t1 = [0 diff(unodes(1).t0_t1)];
                unode_here.epoch_clock = ndi.time.clocktype('dev_local_time');
                unodes(2) = unode_here;
                cost(1,2) = 1;
                cost(2,1) = 1;
                cost(2,2) = 1;
                utc_2_local_map = ndi.time.timemapping([1 -unodes(1).t0_t1(1)]);
                local_map_2_utc = ndi.time.timemapping([1 unodes(1).t0_t1(1)]);
                mapping{1,2} = utc_2_local_map;
                mapping{2,1} = local_map_2_utc;
                mapping{2,2} = trivial_map;
            end;

            if ~issyncgraphroot(ndi_epochset_obj),
                for i=1:numel(epochnode.underlying_epochs),
                    for j=1:numel(epochnode.underlying_epochs(i).epoch_clock),
                        if epochnode.underlying_epochs(i).epoch_clock{j}==epochnode.epoch_clock,
                            % we have found a new unode, build it and add it
                            unode_here = vlt.data.emptystruct(fieldnames(unodes));
                            unode_here(1).epoch_id = epochnode.underlying_epochs(i).epoch_id;
                            unode_here(1).epoch_session_id = epochnode.underlying_epochs(i).epoch_session_id;
                            unode_here(1).epochprobemap = epochnode.underlying_epochs(i).epochprobemap;
                            unode_here(1).epoch_clock = epochnode.underlying_epochs(i).epoch_clock{j};
                            unode_here(1).t0_t1 = epochnode.underlying_epochs(i).t0_t1{j};
                            if isa(epochnode.underlying_epochs(i).underlying,'ndi.epoch.epochset'),
                                etd = epochtable(epochnode.underlying_epochs(i).underlying);
                                z = find(strcmp(unode_here.epoch_id, {etd.epoch_id}));
                                if ~isempty(z),
                                    unode_here(1).underlying_epochs = etd(z);
                                    unode_here(1).underlying_epochs = rmfield(unode_here(1).underlying_epochs,'epoch_number');
                                end
                            end
                            unode_here(1).objectclass = class(epochnode.underlying_epochs(i).underlying);
                            unode_here(1).objectname = epochnode.underlying_epochs(i).underlying.epochsetname;

                            unodes(end+1) = unode_here;

                            % and add costs

                            cost(1,numel(unodes)) = 1; %
                            mapping{1,numel(unodes)} = trivial_map;
                            cost(numel(unodes),1) = 1; %
                            mapping{numel(unodes),1} = trivial_map;
                            cost(numel(unodes),numel(unodes)) = 1; %  % connect to self
                            mapping{numel(unodes),numel(unodes)} = trivial_map;

                            % developer node: if we ever have multiple devices underlying an epoch,
                            %                 then  this needs editing

                            if numel(epochnode.underlying_epochs(i).underlying) > 1,
                                error(['The day has come. More than one ndi.epoch.epochset underlying an epoch. Updating needed. Tell the developers.']);
                            end;

                            % now add the underlying nodes of the newly added underlying node, down to when issyncgraphroot == 1

                            if isa(epochnode.underlying_epochs(i).underlying,'ndi.epoch.epochset'),
                                if ~issyncgraphroot(epochnode.underlying_epochs(i).underlying)
                                    % we need to go deeper

                                    epochnode_d = epochnodes(epochnode.underlying_epochs(i).underlying);
                                    match = 0;
                                    z = find(strcmp(epochnode.underlying_epochs(i).epoch_id, {epochnode_d.epoch_id}));
                                    for zi = 1:numel(z),
                                        if (epochnode.epoch_clock==epochnode_d(z(zi)).epoch_clock)
                                            match = z(zi);
                                            break;
                                        end
                                    end
                                    if match,
                                        [unodes_d, cost_d, mapping_d] = ...
                                            underlyingepochnodes(epochnode.underlying_epochs(i).underlying, epochnode_d(match));

                                        % unodes_d(1) is already in our list

                                        % incorporate new costs;
                                        cost = [ cost inf(numel(unodes),numel(unodes_d)-1) ; ...
                                            inf(numel(unodes_d)-1,numel(unodes)) zeros(numel(unodes_d)-1,numel(unodes_d)-1) ];
                                        cost(numel(unodes):numel(unodes)+numel(unodes_d)-1,numel(unodes):numel(unodes)+numel(unodes_d)-1) = ...
                                            cost_d+cost(numel(unodes),numel(unodes));
                                        mapping = [ mapping cell(numel(unodes),numel(unodes_d)-1) ; ...
                                            cell(numel(unodes_d)-1,numel(unodes)) cell(numel(unodes_d)-1,numel(unodes_d)-1) ];
                                        mapping(numel(unodes):numel(unodes)+numel(unodes_d)-1,numel(unodes):numel(unodes)+numel(unodes_d)-1) = mapping_d;
                                        unodes = cat(2,unodes,unodes_d(2:end)); % unodes_d(1) already in our list
                                    end
                                end
                            end
                        end
                    end
                end
            end

        end % underlyingepochnodes

        function [cost, mapping] = epochgraph(ndi_epochset_obj)
            % EPOCHGRAPH - graph of the mapping and cost of converting time among epochs
            %
            % [COST, MAPPING] = EPOCHGRAPH(NDI_EPOCHSET_OBJ)
            %
            % Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
            %
            % COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
            % For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
            % Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
            % The cost of each transformation is normally 1 operation.
            % MAPPING is the ndi.time.timemapping object that describes the mapping.
            %
            [cost, mapping] = cached_epochgraph(ndi_epochset_obj);
            if isempty(cost),
                [cost,mapping] = ndi_epochset_obj.buildepochgraph;
                [et,hash] = cached_epochtable(ndi_epochset_obj);
                [cache,key] = getcache(ndi_epochset_obj);
                if ~isempty(cache),
                    epochgraph_type = ['epochgraph-hashvalue'];
                    priority = 1; % use higher than normal priority
                    data.cost = cost;
                    data.mapping = mapping;
                    data.hashvalue = hash;
                    cache.add(key,epochgraph_type,data,priority);
                end
            end;
        end % epochgraph

        function [cost, mapping] = buildepochgraph(ndi_epochset_obj)
            % BUILDEPOCHGRAPH - compute the epochgraph among epochs for an ndi.epoch.epochset object
            %
            % [COST,MAPPING] = BUILDEPOCHGRAPH(NDI_EPOCHSET_OBJ)
            %
            % Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
            %
            % COST is an MxM matrix where M is the number of EPOCHNODES.
            % For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
            % Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
            % The cost of each transformation is normally 1 operation.
            % MAPPING is the ndi.time.timemapping object that describes the mapping.
            %
            % In the abstract class, the following NDI_CLOCKTYPEs, if they exist, are linked across epochs with
            % a cost of 1 and a linear mapping rule with shift 1 and offset 0:
            %   'utc' -> 'utc'
            %   'utc' -> 'approx_utc'
            %   'exp_global_time' -> 'exp_global_time'
            %   'exp_global_time' -> 'approx_exp_global_time'
            %   'dev_global_time' -> 'dev_global_time'
            %   'dev_global_time' -> 'approx_dev_global_time'
            %
            %
            % See also: ndi.time.clocktype, ndi.time.clocktype/ndi.time.clocktype, ndi.time.timemapping, ndi.time.timemapping/ndi.time.timemapping,
            % ndi.epoch.epochset/EPOCHNODES

            % Developer note: some subclasses will have the ability to go across different clock types,
            % such as going from 'dev_local_time' to 'utc'. Those subclasses will likely want to
            % override this method by first calling the base class and then adding their own entries.

            trivial_mapping = ndi.time.timemapping([ 1 0 ]);

            nodes = epochnodes(ndi_epochset_obj);

            cost = inf(numel(nodes));
            mapping = cell(numel(nodes));

            for i=1:numel(nodes),
                for j=1:numel(nodes),
                    if j==i,
                        cost(i,j) = 1;
                        mapping{i,j} = trivial_mapping;
                    else,
                        [cost(i,j),mapping{i,j}] = nodes(i).epoch_clock.epochgraph_edge(nodes(j).epoch_clock);
                    end
                end
            end

        end % buildepochgraph

        function [cost,mapping]=cached_epochgraph(ndi_epochset_obj)
            % CACHED_EPOCHGRAPH - return the cached epoch graph of an ndi.epoch.epochset object
            %
            % [COST,MAPPING] = CACHED_EPOCHGRAPH(NDI_EPOCHSET_OBJ)
            %
            % Return the cached version of the epoch graph, if it exists and is up-to-date
            % (that is, the hash number from the EPOCHTABLE of NDI_EPOCHSET_OBJ
            % has not changed). If there is no cached version, or if it is not up-to-date,
            % COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
            % it is deleted.
            %
            % See also: NDI_EPOCHSET_OBJ/EPOCHGRAPH, NDI_EPOCHSET_OBJ/BUILDEPOCHGRAPH
            %
            cost = [];
            mapping = [];
            [cache,key] = getcache(ndi_epochset_obj);
            if ( ~isempty(cache)  & ~isempty(key) ),
                epochgraph_type = ['epochgraph-hashvalue'];
                eg_data = cache.lookup(key,epochgraph_type);
                if ~isempty(eg_data),
                    if matchedepochtable(ndi_epochset_obj, eg_data(1).data.hashvalue);
                        cost = eg_data(1).data.cost;
                        mapping = eg_data(1).data.mapping;
                    else,
                        cache.remove(key,epochgraph_type); % it's out of date, clean it up
                    end
                end
            end
        end % cached_epochgraph

        function b = issyncgraphroot(ndi_epochset_obj)
            % ISSYNCGRAPHROOT - should this object be a root in an ndi.time.syncgraph epoch graph?
            %
            % B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
            %
            % This function tells an ndi.time.syncgraph object whether it should continue
            % adding the 'underlying' epochs to the graph, or whether it should stop at this level.
            %
            % For ndi.epoch.epochset objects, this returns 1. For some object types (ndi.probe.*, for example)
            % this will return 0 so that the underlying ndi.daq.system epochs are added.
            b = 1;
        end % issyncgraphroot

    end % methods

end % classdef
