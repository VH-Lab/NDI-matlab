classdef nsd_syncgraph < handle

	properties (SetAccess=protected,GetAccess=public)
		experiment      % NSD_EXPERIMENT object
		nodes           % epoch nodes of the graph
		nodeobjectnames % device name of each node
		nodeobjectclass % the class of each node
		G               % the epoch node graph adjacency matrix
		mapping         % the mapping among the graph elements (cell matrix of NSD_TIMEMAPPING elements)
		rules		% cell array of NSD_SYNCRULE objects to apply
	end
	properties (SetAccess=protected,GetAccess=private)
		stored_hash_values % stored values of epochtable hash numbers
	end

	methods
	
		function nsd_syncgraph_obj = nsd_syncgraph(varargin)
			% NSD_SYNCGRAPH - create a new NSD_SYNCGRAPH object
			%
			% NSD_SYNCGRAPH_OBJ = NSD_SYNCGRAPH(EXPERIMENT)
			% 
			% Builds a new NSD_SYNCGRAPH object and sets its EXPERIMENT
			% property to EXPERIMENT, which should be an NSD_EXPERIMENT object.
			%
				experiment = [];

				if nargin>0,
					experiment = varargin{1}:
				end
	
				nsd_syncgraph_obj.experiment = experiment;
				nsd_syncgraph_obj.nodes = [];
				nsd_syncgraph_obj.nodeobjectnames = {};
				nsd_syncgraph_obj.nodeobjectclass = {};
				nsd_syncgraph_obj.stored_hash_values = emptystruct('devicename','deviceobjectclass',...
					'deviceobjectnumber','hashvalue');

		end % nsd_syncgraph

		function nsd_syncgraph_obj = addrule(nsd_syncgraph_obj, nsd_syncrule_obj)
			% ADDRULE - add an NSD_SYNCRULE to an NSD_SYNCGRAPH object
			%
			% NSD_SYNCGRAPH_OBJ = ADDRULE(NSD_SYNCGRAPH_OBJ, NSD_SYNCRULE_OBJ)
			%
			% Adds the NSD_SYNCRULE object indicated as a rule for
			% the NSD_SYNCGRAPH NSD_SYNCGRAPH_OBJ. If the NSD_SYNCRULE is already
			% there, then 
			%
			% See also: NSD_SYNCGRAPH/REMOVERULE

				if ~iscell(nsd_syncrule_obj),
					nsd_syncrule_obj = {nsd_syncrule_obj};
				end

				for i=1:numel(nsd_syncrule_obj),
					if isa(nsd_syncrule_obj,'nsd_syncrule'),
						% check for duplication
						match = -1;
						for j=1:numel(nsd_syncgraph_obj.rules),
							if nsd_syncgraph_obj.rules{j}==nsd_syncrule{i},
								match = j;
								break;
							end
						end
						if match<0,
							rules{end+1} = nsd_syncrule_obj;
						end
					else,
						error('Input not of type NSD_SYNCRULE.');
					end
				end
		end % addrule()

		function nsd_syncgraph_obj = removerule(nsd_syncgraph_obj, index)
			% REMOVERULE - remove a given NSD_SYNCRULE from an NSD_SYNCGRAPH object
			%
			% NSD_SYNCGRAPH_OBJ = REMOVERULE(NSD_SYNCGRAPH_OBJ, INDEX)
			%
			% Removes the NSD_SYNCGRAPH_OBJ.rules entry at the INDEX (or indexes) indicated.
			%
				n = numel(nsd_syncgraph_obj.rules);
				nsd_syncgraph_obj.rules = nsd_syncgraph_obj.rules(setdiff(1:n),index);
		end % removerule()


		function nsd_syncgraph_obj = addepoch(nsd_syncgraph_obj, nsd_iodevice_obj)
			% ADDEPOCH - add an NSD_EPOCHSET to the graph
			% 
			% NSD_SYNCGRAPH_OBJ = ADDEPOCH(NSD_SYNCGRAPH_OBJ, NSD_IODEVICE_OBJ)
			%
			% Adds an NSD_EPOCHSET to the NSD_SYNCGRAPH
			%
			% 
				% Step 1: make sure we have the right kind of input object
				if ~isa('nsd_iodevice'),
					error(['The input NSD_IODEVICE_OBJ must be of class NSD_IODEVICE or a subclass.']);
				end

				% Step 2: make sure it is not duplicative

				tf = strcmp(nsd_iodevice_obj.name,nsd_syncgraph_obj.nodeobjectnames);
				if any(tf), % we already have this object, just update
					nsd_syncgraph_obj = nsd_syncgraph_obj.update();
					return;
				end

				% Step 3: ok, we have established it is novel, add it to our graph

					% Step 3.1: add the within-device graph to our graph

				newnodes = nsd_iodevice_obj.epochnodes();
				newnodenames = repmat({nsd_iodevice_obj.name},numel(newnodes),1);
				newnodeclass = repmat({classname(nsd_iodevice_obj.name)},numel(newnodes),1);
				[newcost,newmapping] = nsd_device_obj.epochgraph;

				oldn = numel(nsd_syncgraph_obj.nodes);
				newn = numel(newnodes);

				update_G = [ nsd_syncgraph_obj.G zeros(oldn,newn) ; zeros(newn,oldn) newcost ];
				update_mapping = [ nsd_syncgraph_obj.mapping cell(oldn,newn) ; cell(newn,oldn) newmapping];
				update_nodes = cat(1,nsd_syncgraph_obj.nodes,newnodes);
				update_nodeobjectnames = cat(1,nsd_syncgraph_obj.nodeobjectnames,newnodenames);
				update_nodeobjectclass = cat(1,nsd_syncgraph_obj.nodeobjectclass,newnodeclass);

					% Step 3.2: add any 'duh' connections ('utc' -> 'utc', etc) based purely on nsd_clocktype

				% the brute force way; could be better if we expect low diversity of epoch_clocks, which we do; could search for all clocka->clockb instances
				for i=oldn+1:oldn+newn,
					for j=oldn+1:oldn+newn,
						[update_G(i,j),update_mapping{i,j}] = update_nodes(i).epoch_clock.epochgraph_edge(update_nodes(j).epoch_clock);
						[update_G(j,i),update_mapping{j,i}] = update_nodes(j).epoch_clock.epochgraph_edge(update_nodes(i).epoch_clock);
					end
				end

					% Step 3.3: now add any connections based on applying rules

				for i=oldn+1:oldn+newn,
					for j=oldn+1:oldn+newn,
						lowcost_forward = Inf;
						mappinghere_forward = [];
						lowcost_backward = Inf;
						mappinghere_backward = [];
						for k=1:numel(nsd_syncgraph_obj.rules),
							[c,m] = nsd_syncgraph_obj.rules(k).apply(update_nodeobjectnames{i}, update_nodes(i), ...
									update_nodeobjectnames{j}, update_modes(j));
							if c<lowcost_forward,
								lowcost_forward = c;
								mappinghere_forward = m;
							end;
							[c,m] = nsd_syncgraph_obj.rules(k).apply(update_nodeobjectnames{j}, update_nodes(j), ...
									update_nodeobjectnames{i}, update_modes(i));
							if c<lowcost_backward,
								lowcost_backward = c;
								mappinghere_backward = m;
							end;
						end
						updateG(i,j) = lowcost_forward;
						updatemapping{i,j} = mappinghere_forward;
						updateG(j,i) = lowcost_backward;
						updatemapping{j,i} = mappinghere_backward;
					end
				end
			

%                nodes           % epoch nodes of the graph
%                nodeobjectnames % device name of each node
%                nodeobjectclass % the class of each node
%                G               % the epoch node graph adjacency matrix
%                mapping         % the mapping among the graph elements (cell matrix of NSD_TIMEMAPPING elements)

	

		end % addepoch

		function nsd_syncgraph_obj = removeepoch(nsd_syncgraph_obj, nsd_iodevice_obj)
			% REMOVEEPOCHS - remove an NSD_EPOCHSET from the graph
			%
			% REMOVEEPOCHS(NSD_SYNCGRAPH_OBJ, NSD_EPOCHSET)
			%

		end

		function nsd_syncgraph_obj = update(nsd_syncgraph_obj)
		end % update

		function b = uptodate(nsd_syncgraph_obj)

		end % uptodate

		function [cache,key] = getcache(nsd_syncgraph_obj)
			% GETCACHE - return the NSD_CACHE and key for NSD_SYNCGRAPH
			%
			% [CACHE,KEY] = GETCACHE(NSD_SYNCGRAPH_OBJ)
			%
			% Returns the CACHE and KEY for the NSD_SYNCGRAPH object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the object's objectfilename.
			%
			% See also: NSD_SYNCGRAPH, NSD_BASE

				cache = [];
				key = [];
				if isa(nsd_syncgraph_obj.experiment,'handle'),
					exp = nsd_iodevice_obj.experiment();
					cache = exp.cache;
					key = 'nsd_syncgraph'; % there can be only one
				end
		end

	end % methods

end % classdef nsd_syncgraph
