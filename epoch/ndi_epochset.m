classdef ndi_epochset
% NDI_EPOCHSET - routines for managing a set of epochs and their dependencies
%
%

	properties (SetAccess=protected,GetAccess=public)
		
	end % properties
	properties (SetAccess=protected,GetAccess=protected)
	end % properties

	methods

		function obj = ndi_epochset()
			% NDI_EPOCHSET - constructor for NDI_EPOCHSET objects
			%
			% NDI_EPOCHSET_OBJ = NDI_EPOCHSET()
			%
			% This class has no parameters so the constructor is called with no input arguments.
			%

		end % ndi_epochset

		function n = numepochs(ndi_epochset_obj)
			% NUMEPOCHS - Number of epochs of NDI_EPOCHSET
			% 
			% N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
			%
			% Returns the number of epochs in the NDI_EPOCHSET object NDI_EPOCHSET_OBJ.
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
			% 'epochprobemap'           | Any contents information for each epoch, usually of type NDI_EPOCHPROBEMAP or empty.
			% 'epoch_clock'             | A cell array of NDI_CLOCKTYPE objects that describe the type of clocks available
			% 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each NDI_CLOCKTYPE, the start and stop
			%                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
			% 'underlying_epochs'       | A structure array of the ndi_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochprobemap'
			%
			% HASHVALUE is the hashed value of the epochtable. One can check to see if the epochtable
			% has changed with NDI_EPOCHSET/MATCHEDEPOCHTABLE.
			%
			% After it is read from disk once, the ET is stored in memory and is not re-read from disk
			% unless the user calls NDI_EPOCHSET/RESETEPOCHTABLE.
			%
				[cached_et, cached_hash] = cached_epochtable(ndi_epochset_obj);
				if isempty(cached_et) & ~isstruct(cached_et), % is it not a struct? could be a correctly computed empty epochtable, which would be struct
					et = ndi_epochset_obj.buildepochtable();
					hashvalue = hashmatlabvariable(et);
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
			% 'epochprobemap'           | Any contents information for each epoch, usually of type NDI_EPOCHPROBEMAP or empty.
			% 'epoch_clock'             | A cell array of NDI_CLOCKTYPE objects that describe the type of clocks available
			% 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each NDI_CLOCKTYPE, the start and stop
			%                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
			% 'underlying_epochs'       | A structure array of the ndi_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_id', 'epochprobemap', and 'epoch_clock'
			%
			% After it is read from disk once, the ET is stored in memory and is not re-read from disk
			% unless the user calls NDI_EPOCHSET/RESETEPOCHTABLE.
			%
				ue = emptystruct('underlying','epoch_id','epochprobemap','epoch_clock','t0_t1');
				et = emptystruct('epoch_number','epoch_id','epochprobemap','epoch_clock','t0_t1', 'underlying_epochs');
		end % buildepochtable

		function [et,hashvalue]=cached_epochtable(ndi_epochset_obj)
			% CACHED_EPOCHTABLE - return the cached epochtable of an NDI_EPOCHSET object
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
			% GETCACHE - return the NDI_CACHE and key for an NDI_EPOCHSET object
			%
			% [CACHE, KEY] = GETCACHE(NDI_EPOCHSET_OBJ)
			%
			% Returns the NDI_CACHE object CACHE and the KEY used by the NDI_EPOCHSET object NDI_EPOCHSET_OBJ.
			%
			% In this abstract class, no cache is available, so CACHE and KEY are empty. But subclasses can engage the
			% cache services of the class by returning an NDI_CACHE object and a unique key.
			%
				cache = [];
				key = [];
		end % getcache

		function ndi_epochset_obj = resetepochtable(ndi_epochset_obj)
			% RESETEPOCHTABLE - clear an NDI_EPOCHSET epochtable in memory and force it to be re-read from disk
			%
			% NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
			%
			% This function clears the internal cached memory of the epochtable, forcing it to be re-read from
			% disk at the next request.
			%
			% See also: NDI_EPOCHSET/EPOCHTABLE

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
			% Most classes that manage epochs themselves (NDI_FILENAVIGATOR,
			% NDI_DAQSYSTEM) will override this method.
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
			% EPOCHTABLEENTRY - return the entry of the EPOCHTABLE that corresonds to an EPOCHID
			%
			% ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the EPOCHTABLE entry associated with the NDI_EPOCHSET object
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
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NDI_CLOCKTYPE objects (or sub-class members).
			%
			% The abstract class always returns NDI_CLOCKTYPE('no_time')
			%
			% See also: NDI_CLOCKTYPE, T0_T1
			%
				ec = {ndi_clocktype('no_time')};
		end % epochclock

		function t0t1 = t0_t1(ndi_epochset_obj, epoch_number)
			% T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the NDI_CLOCKTYPE objects returned by EPOCHCLOCK.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: NDI_CLOCKTYPE, EPOCHCLOCK
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
			% EPOCHNODES - return all epoch nodes from an NDI_EPOCHSET object
			%
			% [NODES,UNDERLYINGNODES] = EPOCHNODES(NDI_EPOCHSET_OBJ)
			%
			% Return all EPOCHNODES for an NDI_EPOCHSET. EPOCHNODES consist of the
			% following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochprobemap'           | Any contents information for each epoch, usually of type NDI_EPOCHPROBEMAP or empty.
			% 'epoch_clock'             | A SINGLE NDI_CLOCKTYPE entry that describes the clock type of this node.
			% 't0_t1'                   | The times [t0 t1] of the beginning and end of the epoch in units of 'epoch_clock'
			% 'underlying_epochs'       | A structure array of the ndi_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_id', and 'epochprobemap'
			% 'objectname'              | A string containing the 'name' field of NDI_EPOCHSET_OBJ, if it exists. If there is no
			%                           |   'name' field, then 'unknown' is used.
			% 'objectclass'             | The object class name of the NDI_EPOCHSET_OBJ.
			%
			% EPOCHNODES are related to EPOCHTABLE entries, except 
			%    a) only 1 NDI_CLOCKTYPE is permitted per epoch node. If an entry in epoch table contains
			%       multiple NDI_CLOCKTYPE entries, then each one will have its own epoch node. This aids
			%       in the construction of the EPOCHGRAPH that helps the system map time from one epoch to another.
			%    b) EPOCHNODES contain identifying information (objectname and objectclass) to help
			%       in identifying the epoch nodes across NDI_EPOCHSET objects. 
			%
			% UNDERLYINGNODES are nodes that are directly linked to this NDI_EPOCHSET's node via 'underlying' epochs.
			%
				et = epochtable(ndi_epochset_obj);
				nodes = emptystruct('epoch_id', 'epochprobemap', 'epoch_clock','t0_t1', 'underlying_epochs', 'objectname', 'objectclass');
				if nargout>1, % only build this if we are asked to do so
					underlyingnodes = emptystruct('epoch_id', 'epochprobemap', 'epoch_clock', 't0_t1', 'underlying_epochs');
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
			% EPOCHSETNAME - the name of the NDI_EPOCHSET object, for EPOCHNODES
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
			% (an NDI_EPOCHSET object with ISSYNGRAPHROOT that returns 1).
			%
			% Note that the EPOCHNODE itself is returned as the first 'underlying' node.
			%
			% See also: ISSYNCGRAPHROOT
			%
				unodes = epochnode;
				cost = [1];   % cost has size NxN, where N is (the number of underlying nodes + 1) (1 is the search node)
				trivial_map = ndi_timemapping([1 0]);
				mapping = {trivial_map};  % we can get to ourself

				if ~issyncgraphroot(ndi_epochset_obj),
					for i=1:numel(epochnode.underlying_epochs),
						for j=1:numel(epochnode.underlying_epochs(i).epoch_clock),
							if epochnode.underlying_epochs(i).epoch_clock{j}==epochnode.epoch_clock,
								% we have found a new unode, build it and add it
								unode_here = emptystruct(fieldnames(unodes));
								unode_here(1).epoch_id = epochnode.underlying_epochs(i).epoch_id;
								unode_here(1).epochprobemap = epochnode.underlying_epochs(i).epochprobemap;
								unode_here(1).epoch_clock = epochnode.underlying_epochs(i).epoch_clock{j};
								unode_here(1).t0_t1 = epochnode.underlying_epochs(i).t0_t1{j};
								if isa(epochnode.underlying_epochs(i).underlying,'ndi_epochset'),
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
									error(['The day has come. More than one NDI_EPOCHSET underlying an epoch. Updating needed. Tell the developers.']);
								end;

								% now add the underlying nodes of the newly added underlying node, down to when issyncgraphroot == 1

								if isa(epochnode.underlying_epochs(i).underlying,'ndi_epochset'),
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
			% Compute the cost and the mapping among epochs in the EPOCHTABLE for an NDI_EPOCHSET object
			%
			% COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
			% For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
			% Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
			% The cost of each transformation is normally 1 operation. 
			% MAPPING is the NDI_TIMEMAPPING object that describes the mapping.
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
			% BUILDEPOCHGRAPH - compute the epochgraph among epochs for an NDI_EPOCHSET object
			%
			% [COST,MAPPING] = BUILDEPOCHGRAPH(NDI_EPOCHSET_OBJ)
			%
			% Compute the cost and the mapping among epochs in the EPOCHTABLE for an NDI_EPOCHSET object
			%
			% COST is an MxM matrix where M is the number of EPOCHNODES.
			% For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
			% Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
			% The cost of each transformation is normally 1 operation. 
			% MAPPING is the NDI_TIMEMAPPING object that describes the mapping.
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
			% See also: NDI_CLOCKTYPE, NDI_CLOCKTYPE/NDI_CLOCKTYPE, NDI_TIMEMAPPING, NDI_TIMEMAPPING/NDI_TIMEMAPPING, 
			% NDI_EPOCHSET/EPOCHNODES

					% Developer note: some subclasses will have the ability to go across different clock types,
					% such as going from 'dev_local_time' to 'utc'. Those subclasses will likely want to
					% override this method by first calling the base class and then adding their own entries.

				trivial_mapping = ndi_timemapping([ 1 0 ]);

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
			% CACHED_EPOCHGRAPH - return the cached epoch graph of an NDI_EPOCHSET object
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
			% ISSYNCGRAPHROOT - should this object be a root in an NDI_SYNCGRAPH epoch graph?
			%
			% B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
			%
			% This function tells an NDI_SYNCGRAPH object whether it should continue 
			% adding the 'underlying' epochs to the graph, or whether it should stop at this level.
			%
			% For NDI_EPOCHSET objects, this returns 1. For some object types (NDI_PROBE, for example)
			% this will return 0 so that the underlying NDI_DAQSYSTEM epochs are added.
				b = 1;
		end % issyncgraphroot
		

	end % methods

end % classdef

 
%discussion: If we do this
%
%how will we pick and store epoch labels for non-devices? 
%	use some absurd concatenation
%	where to store it? or construct it from the myriad of underlying records?
%

