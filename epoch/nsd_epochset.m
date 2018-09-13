classdef nsd_epochset
% NSD_EPOCHSET - routines for managing a set of epochs and their dependencies
%
%

	properties (SetAccess=protected,GetAccess=public)
		
	end % properties
	properties (SetAccess=protected,GetAccess=protected)
	end % properties

	methods

		function obj = nsd_epochset()
			% NSD_EPOCHSET - constructor for NSD_EPOCHSET objects
			%
			% NSD_EPOCHSET_OBJ = NSD_EPOCHSET()
			%
			% This class has no parameters so the constructor is called with no input arguments.
			%

		end % nsd_epochset

		% okay, suppose we had

		%deleteepoch

		function n = numepochs(nsd_epochset_obj)
			% NUMEPOCHS - Number of epochs of NSD_EPOCHSET
			% 
			% N = NUMEPOCHS(NSD_EPOCHSET_OBJ)
			%
			% Returns the number of epochs in the NSD_EPOCHSET object NSD_EPOCHSET_OBJ.
			%
			% See also: EPOCHTABLE

				n = numel(epochtable(nsd_epochset_obj));

		end % numepochs

		function [et,hashvalue] = epochtable(nsd_epochset_obj)
			% EPOCHTABLE - Return an epoch table that relates the current object's epochs to underlying epochs
			%
			% [ET,HASHVALUE] = EPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochcontents'           | Any contents information for each epoch, usually of type NSD_EPOCHCONTENTS or empty.
			% 'epoch_clock'             | A cell array of NSD_CLOCKTYPE objects that describe the type of clocks available
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochcontents'
			%
			% HASHVALUE is the hashed value of the epochtable. One can check to see if the epochtable
			% has changed with NSD_EPOCHSET/MATCHEDEPOCHTABLE.
			%
			% After it is read from disk once, the ET is stored in memory and is not re-read from disk
			% unless the user calls NSD_EPOCHSET/RESETEPOCHTABLE.
			%
				[cached_et, cached_hash] = cached_epochtable(nsd_epochset_obj);
				if isempty(cached_et) & ~isstruct(cached_et), % is it not a struct? could be a correctly computed empty epochtable, which would be struct
					et = nsd_epochset_obj.buildepochtable();
					hashvalue = hashmatlabvariable(et);
					[cache,key] = getcache(nsd_epochset_obj);
					if ~isempty(cache),
						priority = 1; % use higher than normal priority
						cache.add(key,'epochtable-hash',struct('epochtable',et,'hashvalue',hashvalue),priority);
					end
				else,
					et = cached_et;
					hashvalue = cached_hash;
				end;

		end % epochtable

		function [et] = buildepochtable(nsd_epochset_obj)
			% BUILDEPOCHTABLE - Build and store an epoch table that relates the current object's epochs to underlying epochs
			%
			% [ET] = BUILDEPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochcontents'           | Any contents information for each epoch, usually of type NSD_EPOCHCONTENTS or empty.
			% 'epoch_clock'             | A cell array of NSD_CLOCKTYPE objects that describe the type of clocks available
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_id', 'epochcontents', and 'epoch_clock'
			%
			% After it is read from disk once, the ET is stored in memory and is not re-read from disk
			% unless the user calls NSD_EPOCHSET/RESETEPOCHTABLE.
			%
				ue = emptystruct('underlying','epoch_id','epochcontents','epoch_clock');
				et = emptystruct('epoch_number','epoch_id','epochcontents','epoch_clock','underlying_epochs');
		end % buildepochtable

		function [et,hashvalue]=cached_epochtable(nsd_epochset_obj)
			% CACHED_EPOCHTABLE - return the cached epochtable of an NSD_EPOCHSET object
			%
			% [ET, HASHVALUE] = CACHED_EPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% Return the cached version of the epochtable, if it exists, along with its HASHVALUE
			% (a hash number generated from the table). If there is no cached version,
			% ET and HASHVALUE will be empty.
			%
				et = [];
				hashvalue = [];
				[cache,key] = getcache(nsd_epochset_obj);
				if (~isempty(cache) & ~isempty(key)),
					table_entry = cache.lookup(key,'epochtable-hash');
					if ~isempty(table_entry),
						et = table_entry(1).data.epochtable;
						hashvalue = table_entry(1).data.hashvalue;
					end;
				end
		end % cached_epochtable

		function [cache, key] = getcache(nsd_epochset_obj)
			% GETCACHE - return the NSD_CACHE and key for an NSD_EPOCHSET object
			%
			% [CACHE, KEY] = GETCACHE(NSD_EPOCHSET_OBJ)
			%
			% Returns the NSD_CACHE object CACHE and the KEY used by the NSD_EPOCHSET object NSD_EPOCHSET_OBJ.
			%
			% In this abstract class, no cache is available, so CACHE and KEY are empty. But subclasses can engage the
			% cache services of the class by returning an NSD_CACHE object and a unique key.
			%
				cache = [];
				key = [];
		end % getcache

		function nsd_epochset_obj = resetepochtable(nsd_epochset_obj)
			% RESETEPOCHTABLE - clear an NSD_EPOCHSET epochtable in memory and force it to be re-read from disk
			%
			% NSD_EPOCHSET_OBJ = RESETEPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% This function clears the internal cached memory of the epochtable, forcing it to be re-read from
			% disk at the next request.
			%
			% See also: NSD_EPOCHSET/EPOCHTABLE

				[cache,key]=getcache(nsd_epochset_obj);
				if (~isempty(cache) & ~isempty(key)),
					cache.remove(key,'epochtable-hash');
				end
		end % resetepochtable

		function b = matchedepochtable(nsd_epochset_obj, hashvalue)
			% MATCHEDEPOCHTABLE - compare a hash number from an epochtable to the current version
			%
			% B = MATCHEDEPOCHTABLE(NSD_EPOCHSET_OBJ, HASHVALUE)
			%
			% Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
			% Otherwise, it returns 0.

				b = 0;
				[cached_et, cached_hashvalue] = cached_epochtable(nsd_epochset_obj);
				if ~isempty(cached_et),
					b = (hashvalue == cached_hashvalue);
				end
		end % matchedepochtable

		function eid = epochid(nsd_epochset_obj, epoch_number)
			% EPOCHID - Get the epoch identifier for a particular epoch
			%
			% ID = EPOCHID (NSD_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
			% If it doesn't exist, it should be created.
			%
			% The abstract class just queries the EPOCHTABLE.
			% Most classes that manage epochs themselves (NSD_FILETREE,
			% NSD_IODEVICE) will override this method.
			%
				et = epochtable(nsd_epochset_obj);
				if epoch_number > numel(et), 
					error(['epoch_number out of range (number of epochs==' int2str(numel(et)) ')']);
				end
				eid = et(epoch_number).epoch_id; 
		end % epochid

		function ec = epochclock(nsd_epochset_obj, epoch_number)
			% EPOCHCLOCK - return the NSD_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NSD_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NSD_CLOCKTYPE objects (or sub-class members).
			%
			% The abstract class always returns NSD_CLOCKTYPE('no_time')
			%
			% See also: NSD_CLOCKTYPE
			%
				ec = {nsd_clocktype('no_time')};
		end % epochclock

		function s = epoch2str(nsd_epochset_obj, number)
			% EPOCH2STR - convert an epoch number or id to a string
			%
			% S = EPOCH2STR(NSD_EPOCHSET_OBJ, NUMBER)
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

		function [nodes,underlyingnodes] = epochnodes(nsd_epochset_obj)
			% EPOCHNODES - return all epoch nodes from an NSD_EPOCHSET object
			%
			% [NODES,UNDERLYINGNODES] = EPOCHNODES(NSD_EPOCHSET_OBJ)
			%
			% Return all EPOCHNODES for an NSD_EPOCHSET. EPOCHNODES consist of the
			% following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochcontents'           | Any contents information for each epoch, usually of type NSD_EPOCHCONTENTS or empty.
			% 'epoch_clock'             | A SINGLE NSD_CLOCKTYPE entry that describes the clock type of this node.
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_id', and 'epochcontents'
			% 'objectname'              | A string containing the 'name' field of NSD_EPOCHSET_OBJ, if it exists. If there is no
			%                           |   'name' field, then 'unknown' is used.
			% 'objectclass'             | The object class name of the NSD_EPOCHSET_OBJ.
			%
			% EPOCHNODES are related to EPOCHTABLE entries, except 
			%    a) only 1 NSD_CLOCKTYPE is permitted per epoch node. If an entry in epoch table contains
			%       multiple NSD_CLOCKTYPE entries, then each one will have its own epoch node. This aids
			%       in the construction of the EPOCHGRAPH that helps the system map time from one epoch to another.
			%    b) EPOCHNODES contain identifying information (objectname and objectclass) to help
			%       in identifying the epoch nodes across NSD_EPOCHSET objects. 
			%
			% UNDERLYINGNODES are nodes that are directly linked to this NSD_EPOCHSET's node via 'underlying' epochs.
			%
				et = epochtable(nsd_epochset_obj);
				nodes = emptystruct('epoch_id', 'epochcontents', 'epoch_clock','underlying_epochs', 'objectname', 'objectclass');
				if nargout>1, % only build this if we are asked to do so
					underlyingnodes = emptystruct('epoch_id', 'epochcontents', 'epoch_clock', 'underlying_epochs');
				end

				for i=1:numel(et),
					for j=1:numel(et(i).epoch_clock),
						newnode = et(i);
						newnode = rmfield(newnode,'epoch_number');
						newnode.epoch_clock = et(i).epoch_clock{j};
						newnode.objectname = epochsetname(nsd_epochset_obj);
						newnode.objectclass = class(nsd_epochset_obj);
						nodes(end+1) = newnode;
					end
					if nargout>1,
						newunodes = underlyingepochnodes(nsd_epochset_obj,epochnode);
						underlyingnodes = cat(2,underlyingnodes,newunodes);
					end
				end
		end % epochnodes

		function name = epochsetname(nsd_epochset_obj)
			% EPOCHSETNAME - the name of the NSD_EPOCHSET object, for EPOCHNODES
			%
			% NAME = EPOCHSETNAME(NSD_EPOCHSET_OBJ)
			%
			% Returns the object name that is used when creating epoch nodes.
			%
			% If the class has a 'name' property, that property is used.
			% Otherwise, 'unknown' is used.
			%
				name = 'unknown';
				% default behavior is to use the 'name' field
				if any(strcmp('name',fieldnames(nsd_epochset_obj))),
					name = getfield(nsd_epochset_obj,'name');
				end
		end % epochsetname

		function [unodes,cost,mapping] = underlyingepochnodes(nsd_epochset_obj, epochnode)
			% UNDERLYINGEPOCHNODES - find all the underlying epochnodes of a given epochnode
			%
			% [UNODES,OBJECTNAME, OBJECTCLASS, COST,MAPPING] = UNDERLYINGEPOCHNODES(NSD_EPOCHSET_OBJ, EPOCHNODE)
			%
			% Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
			% (an NSD_EPOCHSET object with ISSYNGRAPHROOT that returns 1).
			%
			% Note that the EPOCHNODE itself is returned as the first 'underlying' node.
			%
			% See also: ISSYNCGRAPHROOT
			%
				unodes = epochnode;
				cost = [1];   % cost has size NxN, where N is (the number of underlying nodes + 1) (1 is the search node)
				trivial_map = nsd_timemapping([1 0]);
				mapping = {trivial_map};  % we can get to ourself

				if ~issyncgraphroot(nsd_epochset_obj),
					for i=1:numel(epochnode.underlying_epochs),
						for j=1:numel(epochnode.underlying_epochs(i).epoch_clock),
							if epochnode.underlying_epochs(i).epoch_clock{j}==epochnode.epoch_clock,
								% we have found a new unode, build it and add it
								unode_here = emptystruct(fieldnames(unodes));
								unode_here(1).epoch_id = epochnode.underlying_epochs(i).epoch_id;
								unode_here(1).epochcontents = epochnode.underlying_epochs(i).epochcontents;
								unode_here(1).epoch_clock = epochnode.underlying_epochs(i).epoch_clock{j};
								if isa(epochnode.underlying_epochs(i).underlying,'nsd_epochset'),
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
									error(['The day has come. More than one NSD_EPOCHSET underlying an epoch. Updating needed. Tell the developers.']);
								end;

								% now add the underlying nodes of the newly added underlying node, down to when issyncgraphroot == 1

								if isa(epochnode.underlying_epochs(i).underlying,'nsd_epochset'),
									if ~issyncgraphroot(epochnode.underlying_epochs(i).underlying)
										% we need to go deeper

										disp('this is still untested, so pay attention!');
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
												underylingepochnodes(epochnode.underlying_epochs(i).underlying);

											% incorporate new costs; 
											cost = [ cost inf(numel(unodes),numel(unodes_d)-1) ; ...
												inf(numel(unodes_d)-1,numel(unodes)) zeros(numel(unodes_d)-1,numel(unodes_d)-1) ];
											cost(numel(unodes):numel(unodes)+numel(unodes_d),numel(unodes):numel(unodes_d)) = cost_d;
											mapping = [ mapping cell(numel(unodes),numel(unodes_d)-1) ; ...
												cell(numel(unodes_d)-1,numel(unodes)) cell(numel(unodes_d)-1,numel(unodes_d)-1) ];
											mapping(numel(unodes):numel(unodes)+numel(unodes_d),numel(unodes):numel(unodes_d)) = mapping_d;
											unodes = cat(2,unodes,unodes_d);
										end
									end
								end
							end
						end
					end
				end

		end % underlyingepochnodes

		function [cost, mapping] = epochgraph(nsd_epochset_obj)
			% EPOCHGRAPH - graph of the mapping and cost of converting time among epochs
			%
			% [COST, MAPPING] = EPOCHGRAPH(NSD_EPOCHSET_OBJ)
			%
			% Compute the cost and the mapping among epochs in the EPOCHTABLE for an NSD_EPOCHSET object
			%
			% COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
			% For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
			% Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
			% The cost of each transformation is normally 1 operation. 
			% MAPPING is the NSD_TIMEMAPPING object that describes the mapping.
			%
				[cost, mapping] = cached_epochgraph(nsd_epochset_obj);
				if isempty(cost),
					[cost,mapping] = nsd_epochset_obj.buildepochgraph;
					[et,hash] = cached_epochtable(nsd_epochset_obj);
					[cache,key] = getcache(nsd_epochset_obj);
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

		function [cost, mapping] = buildepochgraph(nsd_epochset_obj)
			% BUILDEPOCHGRAPH - compute the epochgraph among epochs for an NSD_EPOCHSET object
			%
			% [COST,MAPPING] = BUILDEPOCHGRAPH(NSD_EPOCHSET_OBJ)
			%
			% Compute the cost and the mapping among epochs in the EPOCHTABLE for an NSD_EPOCHSET object
			%
			% COST is an MxM matrix where M is the number of EPOCHNODES.
			% For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
			% Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
			% The cost of each transformation is normally 1 operation. 
			% MAPPING is the NSD_TIMEMAPPING object that describes the mapping.
			%
			% In the abstract class, the following NSD_CLOCKTYPEs, if they exist, are linked across epochs with 
			% a cost of 1 and a linear mapping rule with shift 1 and offset 0:
			%   'utc' -> 'utc'
			%   'utc' -> 'approx_utc'
			%   'exp_global_time' -> 'exp_global_time'
			%   'exp_global_time' -> 'approx_exp_global_time'
			%   'dev_global_time' -> 'dev_global_time'
			%   'dev_global_time' -> 'approx_dev_global_time'
			%
			%
			% See also: NSD_CLOCKTYPE, NSD_CLOCKTYPE/NSD_CLOCKTYPE, NSD_TIMEMAPPING, NSD_TIMEMAPPING/NSD_TIMEMAPPING, 
			% NSD_EPOCHSET/EPOCHNODES

					% Developer note: some subclasses will have the ability to go across different clock types,
					% such as going from 'dev_local_time' to 'utc'. Those subclasses will likely want to
					% override this method by first calling the base class and then adding their own entries.

				trivial_mapping = nsd_timemapping([ 1 0 ]);

				nodes = epochnodes(nsd_epochset_obj);

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

		function [cost,mapping]=cached_epochgraph(nsd_epochset_obj)
			% CACHED_EPOCHGRAPH - return the cached epoch graph of an NSD_EPOCHSET object
			%
			% [COST,MAPPING] = CACHED_EPOCHGRAPH(NSD_EPOCHSET_OBJ)
			%
			% Return the cached version of the epoch graph, if it exists and is up-to-date
			% (that is, the hash number from the EPOCHTABLE of NSD_EPOCHSET_OBJ 
			% has not changed). If there is no cached version, or if it is not up-to-date,
			% COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
			% it is deleted.
			%
			% See also: NSD_EPOCHSET_OBJ/EPOCHGRAPH, NSD_EPOCHSET_OBJ/BUILDEPOCHGRAPH
			%
				cost = [];
				mapping = [];
				[cache,key] = getcache(nsd_epochset_obj);
				if ( ~isempty(cache)  & ~isempty(key) ),
					epochgraph_type = ['epochgraph-hashvalue'];
					eg_data = cache.lookup(key,epochgraph_type);
					if ~isempty(eg_data),
						if matchedepochtable(nsd_epochset_obj, eg_data(1).data.hashvalue);
							cost = eg_data(1).data.cost;
							mapping = eg_data(1).data.mapping;
						else,
							cache.remove(key,epochgraph_type); % it's out of date, clean it up
						end
					end
				end
		end % cached_epochgraph

		function b = issyncgraphroot(nsd_epochset_obj)
			% ISSYNCGRAPHROOT - should this object be a root in an NSD_SYNCGRAPH epoch graph?
			%
			% B = ISSYNCGRAPHROOT(NSD_EPOCHSET_OBJ)
			%
			% This function tells an NSD_SYNCGRAPH object whether it should continue 
			% adding the 'underlying' epochs to the graph, or whether it should stop at this level.
			%
			% For NSD_EPOCHSET objects, this returns 1. For some object types (NSD_PROBE, for example)
			% this will return 0 so that the underlying NSD_IODEVICE epochs are added.
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

