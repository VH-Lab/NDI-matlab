classdef nsd_syncgraph < nsd_base

	properties (SetAccess=protected,GetAccess=public)
		experiment      % NSD_EXPERIMENT object
		rules		% cell array of NSD_SYNCRULE objects to apply
	end
	properties (SetAccess=protected,GetAccess=private)
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
					experiment = varargin{1};
				end
	
				nsd_syncgraph_obj.experiment = experiment;

				if nargin>=2,
					if strcmp(lower(varargin{2}),lower('OpenFile')),
						nsd_syncgraph_obj = nsd_syncgraph_obj.readobjectfile(varargin{1});
					end
				end

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
					if isa(nsd_syncrule_obj{i},'nsd_syncrule'),
						% check for duplication
						match = -1;
						for j=1:numel(nsd_syncgraph_obj.rules),
							if nsd_syncgraph_obj.rules{j}==nsd_syncrule_obj{i},
								match = j;
								break;
							end
						end
						if match<0,
							nsd_syncgraph_obj.rules{end+1} = nsd_syncrule_obj{i};
						end
					else,
						error('Input not of type NSD_SYNCRULE.');
					end
				end
				if ~isempty(nsd_syncgraph_obj.experiment),
					nsd_syncgraph_obj.writeobjectfile(nsd_syncgraph_obj.experiment.nsdpathname);
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
				if ~isempty(nsd_syncgraph_obj.experiment),
					nsd_syncgraph_obj.writeobjectfile(nsd_syncgraph_obj.experiment.nsdpathname);
				end
		end % removerule()

		function [ginfo,hashvalue] = graphinfo(nsd_syncgraph_obj);
			% GRAPHINFO - return the graph information 
			%
			% 
			% The graph information GINFO is a structure with the following fields:
			% Fieldname              | Description
			% ---------------------------------------------------------------------
			% nodes                  | The epochnodes (see NSD_EPOCHSET/EPOCHNODE)
			% G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
			%                        |   converting between node i and j.
			% mapping                | A cell matrix with NSD_TIMEMAPPING objects that describes the
			%                        |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
			%
				[ginfo, hashvalue] = cached_graphinfo(nsd_syncgraph_obj);
				if isempty(ginfo),
					ginfo = nsd_syncgraph_obj.buildgraphinfo();
					set_cached_graphinfo(nsd_syncgraph_obj, ginfo);
				end
		end % graphinfo
				
		function [ginfo] = buildgraphinfo(nsd_syncgraph_obj)
			% BUILDGRAPHINFO - build graph info for an NSD_SYNCGRAPH object
			%
			% [GINFO] = BUILDGRAPHINFO(NSD_SYNCGRAPH_OBJ)
			%
			% Builds from scratch the syncgraph structure GINFO from all of the devices
			% in the NSD_SYNCGRAPH_OBJ's associated 'experiment' property.
			%
			% The graph information GINFO is a structure with the following fields:
			% Fieldname              | Description
			% ---------------------------------------------------------------------
			% nodes                  | The epochnodes (see NSD_EPOCHSET/EPOCHNODE)
			% G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
			%                        |   converting between node i and j.
			% mapping                | A cell matrix with NSD_TIMEMAPPING objects that describes the
			%                        |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
			% diG                    | The graph data structure in Matlab for G (a 'digraph')
			%
				ginfo.nodes = emptystruct('epoch_id','epochcontents','epoch_clock','t0_t1','underlying_epochs','objectname','objectclass');
				ginfo.G = [];
				ginfo.mapping = {};
				ginfo.diG = [];

				d = nsd_syncgraph_obj.experiment.iodevice_load('name','(.*)');
				if ~iscell(d), d = {d}; end; % make sure we are a cell

				for i=1:numel(d),
					ginfo = nsd_syncgraph_obj.addepoch(d{i}, ginfo);
				end
		end % buildgraphinfo

		function [ginfo,hashvalue]=cached_graphinfo(nsd_syncgraph_obj)
			% CACHED_GRAPHINFO - return the cached graph info of an NSD_SYNCGRAPH object
			%
			% [GINFO, HASHVALUE] = CACHED_EPOCHTABLE(NSD_SYNCGRAPH_OBJ)
			%
			% Return the cached version of the graph info, if it exists, along with its HASHVALUE
			% (a hash number generated from the graph info). If there is no cached version,
			% GINFO and HASHVALUE will be empty.
			%
				ginfo = [];
				hashvalue = [];
				[cache,key] = getcache(nsd_syncgraph_obj);
				if (~isempty(cache) & ~isempty(key)),
					table_entry = cache.lookup(key,'syncgraph-hash');
					if ~isempty(table_entry),
						ginfo = table_entry(1).data.graphinfo;
						hashvalue = table_entry(1).data.hashvalue;
					end;
				end
		end % cached_epochtable

		function set_cached_graphinfo(nsd_syncgraph_obj, ginfo)
			% SET_CACHED_GRAPHINFO
			%
			% SET_CACHED_GRAPHINFO(NSD_SYNCGRAPH_OBJ, GINFO)
			%
			% Set the cached graph info. Opposite of CACHE_GRAPHINFO.
			% 
			% See also: CACHE_GRAPHINFO
				[cache,key] = getcache(nsd_syncgraph_obj);
				if ~isempty(cache),
					hashvalue = hashmatlabvariable(ginfo);
					priority = 1;
					cache.remove(key,'syncgraph-hash');
					cache.add(key,'syncgraph-hash',struct('graphinfo',ginfo,'hashvalue',hashvalue),priority);
				end
		end % set_cached_graphinfo

		function ginfo = addepoch(nsd_syncgraph_obj, nsd_iodevice_obj, ginfo)
			% ADDEPOCH - add an NSD_EPOCHSET to the graph
			% 
			% NEW_GINFO = ADDEPOCH(NSD_SYNCGRAPH_OBJ, NSD_IODEVICE_OBJ, GINFO)
			%
			% Adds an NSD_EPOCHSET to the NSD_SYNCGRAPH
			%
			% Note: this does not update the cache
			% 
				% Step 1: make sure we have the right kind of input object
				if ~isa(nsd_iodevice_obj, 'nsd_iodevice'),
					error(['The input NSD_IODEVICE_OBJ must be of class NSD_IODEVICE or a subclass.']);
				end

				% Step 2: make sure it is not duplicative

				if numel(ginfo)>0,
					tf = strcmp(nsd_iodevice_obj.name,{ginfo.nodes.objectname});
				else,
					tf = [];
				end
				if any(tf), % we already have this object
					% in the future, we'll make this method that saves time. For initial development, we'll complain
					%ginfo = updateepochs(nsd_syncgraph_obj, nsd_iodevice_obj, ginfo);
					%return;
					error(['This graph already has epochs from ' name '.']);
				end

				% Step 3: ok, we have established it is novel, add it to our graph

					% Step 3.1: add the within-device graph to our graph

				newnodes = nsd_iodevice_obj.epochnodes();
				[newcost,newmapping] = nsd_iodevice_obj.epochgraph;

				oldn = numel(ginfo.nodes);
				newn = numel(newnodes);

				ginfo.nodes = cat(2,ginfo.nodes(:)',newnodes(:)');

					% developer note: will probably have to change G to a sparse matrix with zero meaning 'no connection'

				ginfo.G = [ ginfo.G inf(oldn,newn); inf(newn,oldn) newcost ] ;
				ginfo.mapping = [ ginfo.mapping cell(oldn,newn) ; cell(newn,oldn) newmapping];
				
					% Step 3.2: add any 'duh' connections ('utc' -> 'utc', etc) based purely on nsd_clocktype

				% the brute force way; could be better if we expect low diversity of epoch_clocks, which we do;
				% we can do better, could search for all clocka->clockb instances

				for i=1:oldn,
					for j=oldn+1:oldn+newn,
						if i~=j,
							[ginfo.G(i,j),ginfo.mapping{i,j}] = ...
								ginfo.nodes(i).epoch_clock.epochgraph_edge(ginfo.nodes(j).epoch_clock);
							[ginfo.G(j,i),ginfo.mapping{j,i}] = ...
								ginfo.nodes(j).epoch_clock.epochgraph_edge(ginfo.nodes(i).epoch_clock);
						end;
					end
				end

					% Step 3.3: now add any connections based on applying rules

				for i=1:oldn,
					for j=oldn+1:oldn+newn,
						if i~=j,
							for k=1:2,
								if k==1,
									i_ = i;
									j_ = j;
								else,
									i_ = j;
									j_ = i;
								end;
								lowcost = Inf;
								mappinghere = [];
								for k=1:numel(nsd_syncgraph_obj.rules),
									[c,m] = apply(nsd_syncgraph_obj.rules{k}, ginfo.nodes(i_), ginfo.nodes(j_));
									if c<lowcost,
										lowcost = c;
										mappinghere = m;
									end;
								end
								ginfo.G(i_,j_) = lowcost;
								ginfo.mapping{i_,j_} = mappinghere;
							end
						end
					end
				end

				Gtable = ginfo.G;
				Gtable(find(isinf(Gtable))) = 0;
				ginfo.diG = digraph(Gtable);
			
		end % addepoch

		function ginfo = addunderlyingepochs(nsd_syncgraph_obj, nsd_epochset_obj, ginfo)
			% ADDUNDERLYINGEPOCH - add an NSD_EPOCHSET to the graph
			% 
			% NEW_GINFO = ADDUNDERLYINGEPOCHS(NSD_SYNCGRAPH_OBJ, NSD_EPOCHSET_OBJ, GINFO)
			%
			% Adds an NSD_EPOCHSET to the NSD_SYNCGRAPH
			%
			% Note: this DOES update the cache
			% 
				% Step 1: make sure we have the right kind of input object
				if ~isa(nsd_epochset_obj, 'nsd_epochset'),
					error(['The input NSD_EPOCHSET_OBJ must be of class NSD_EPOCHSET or a subclass.']);
				end;

				enodes = epochnodes(nsd_epochset_obj);
				% do we search for duplicates?

				for i=1:numel(enodes),
					index = nsd_findepochnode(enodes(i), ginfo.nodes);

					if isempty(index), % we don't have this one, we need to add it

						underlying_nodes = underlyingepochnodes(nsd_epochset_obj, enodes(i));

						[u_nodes,u_cost,u_mapping] = underlyingepochnodes(nsd_epochset_obj, enodes(i));

						% now we have a set of things to add to the graph

						u_node_index_in_main = NaN(numel(u_nodes),1);
						for j=1:numel(u_nodes),
							myindex = nsd_findepochnode(u_nodes(j), ginfo.nodes);
							if ~isempty(myindex),
								u_node_index_in_main(j) = myindex;
							end
						end

						nodenumbers2_1 = u_node_index_in_main; % what are the node numbers in the nodes to be added? or NaN if not there
						nanshere = find(isnan(nodenumbers2_1));
						nodenumbers2_1(nanshere) = numel(ginfo.nodes)+(1:numel(nanshere));

						[newG, G_indexes, numnewnodes] = mergegraph(ginfo.G, u_cost, nodenumbers2_1);
							% update mapping cell matrix, too
						mapping_upperright = cell(size(ginfo.G,1), numnewnodes);
						mapping_upperright(G_indexes.upper_right.merged) = u_mapping(G_indexes.upper_right.G2);
						mapping_lowerleft = cell(numnewnodes,size(ginfo.G,1));
						mapping_lowerleft(G_indexes.lower_left.merged) = u_mapping(G_indexes.lower_left.G2);
						mapping_lowerright = u_mapping(G_indexes.lower_right);

						ginfo.nodes = cat(2,ginfo.nodes,u_nodes(nanshere));
						ginfo.G = newG;
						ginfo.mapping = [ginfo.mapping mapping_upperright ; mapping_lowerleft mapping_lowerright ];

						% developer question: should we bother to check for links that matter?
						%                     right now, let's check that the first epochnode is connected at all

					end
				end

				Gtable = ginfo.G;
				Gtable(find(isinf(Gtable))) = 0;
				ginfo.diG = digraph(Gtable);

				nsd_syncgraph_obj.set_cached_graphinfo(ginfo);
		end % addunderlyingnodes

		function ginfo = removeepoch(nsd_syncgraph_obj, nsd_iodevice_obj, ginfo)
			% REMOVEEPOCHS - remove an NSD_EPOCHSET from the graph
			%
			% GINFO = REMOVEEPOCHS(NSD_SYNCGRAPH_OBJ, NSD_IODEVICE_OBJ, GINFO)
			%
			% Remove all epoch nodes from the graph that are contributed by NSD_IODEVICE_OBJ
			%
			% Note: this does not update the cache

				tf = find(strcmp(nsd_iodevice_obj.name,{ginfo.nodes.objectname}));

				keep = setdiff(1:numel(ginfo.nodes));

				ginfo.G = ginfo.G(keep,keep);
				ginfo.mapping = ginfo.mapping(keep,keep);
				ginfo.nodes = ginfo.nodes(keep);
				
				Gtable = ginfo.G;
				Gtable(find(isinf(Gtable))) = 0;
				ginfo.diG = digraph(Gtable);

		end % removeepoch

		function [t_out, timeref_out, msg] = time_convert(nsd_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out)
			% TIME_CONVERT - convert time from one NSD_TIMEREFERENCE to another
			%
			% [T_OUT, TIMEREF_OUT, MSG] = TIME_CONVERT(NSD_SYNCGRAPH_OBJ, TIMEREF_IN, T_IN, REFERENT_OUT, CLOCKTYPE_OUT)
			%
			% Attempts to convert a time T_IN that is referred to by NSD_TIMEREFERENCE object TIMEREF_IN 
			% to T_OUT that is referred to by the requested REFERENT_OUT object (must be type NSD_EPOCHSET and NSD_BASE)
			% with the requested NSD_CLOCKTYPE CLOCKTYPE_OUT.
			% 
			% T_OUT is the output time with respect to the NSD_TIMEREFERENCE TIMEREF_OUT that incorporates REFERENT_OUT
			% and CLOCKTYPE_OUT with the appropriate epoch and time reference.
			%
			% If the conversion cannot be made, T_OUT is empty and MSG contains a text message describing
			% why the conversion could not be made.
			%
				t_out = [];
				timeref_out = [];
				msg = '';

				% Step 0: check inputs

				if isempty(timeref_in.epoch)
					error(['Right now we do not support non-epoch input time...soon!']);
				end

				if ~isempty(timeref_in.epoch),
					if isnumeric(timeref_in.epoch) % we have an epoch number
						in_epochid = epochid(timeref_in.referent, timeref_in.epoch);
					else,
						in_epochid = timeref_in.epoch;
					end
				else,
					% we would figure this out from start and stop times
				end

				ginfo = graphinfo(nsd_syncgraph_obj);

				% STEP 1: identify the source node

				sourcenodeindex = nsd_findepochnode(...
					struct('objectname',epochsetname(timeref_in.referent), 'objectclass', class(timeref_in.referent), ...
						'epoch_id',in_epochid, 'epoch_clock', timeref_in.clocktype),...
					ginfo.nodes);

				% should be a single item now
				if numel(sourcenodeindex)>1,
					msg = ['expected start epochnode to be a single node, but it is not.'];
					return;
				elseif numel(sourcenodeindex)==0,
					% we do not have the node; add it and try again.
					nsd_syncgraph_obj.addunderlyingepochs(timeref_in.referent,ginfo);
					[t_out,timeref_out,msg] = time_convert(nsd_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out);
					return;
				end

				if isempty(sourcenodeindex), return; end; % if we did not find it, we failed

				% STEP 2: narrow the search for the destination node. It has to match our referent and it has to 
				%     match the requested clock type

				destinationnodeindexes = nsd_findepochnode(...
					struct('objectname', epochsetname(referent_out), 'objectclass', class(referent_out), 'epoch_clock', clocktype_out), ...
					ginfo.nodes);

				if isempty(destinationnodeindexes),
					% no candidate output nodes, see if any are there any from that referent
					any_referent_outs = nsd_findepochnode(...
						struct('objectname', epochsetname(referent_out), 'objectclass', class(referent_out)), ...
						ginfo.nodes);
					if isempty(any_referent_outs), % add the referent to the table and try again
						nsd_syncgraph_obj.addunderlyingepochs(referent_out,ginfo);
						[t_out,timeref_out,msg] = time_convert(nsd_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out);
					else,
						msg = ['Could not find any such destination node.'];
					end;
					return;
				end

				% STEP 3: are there any paths from our source to any of the candidate destinations?

				D = distances(ginfo.diG,sourcenodeindex,destinationnodeindexes);
				indexes = find(~isinf(D));
				if numel(indexes)>1,
					msg = 'too many matches, do not know what to do.'; 
					return
				end

				destinationnodeindex = destinationnodeindexes(indexes);

				% make the timeref_out based on the node we found, use timeref of 0
				timeref_out = nsd_timereference(referent_out, ginfo.nodes(destinationnodeindex).epoch_clock, ...
					ginfo.nodes(destinationnodeindex).epoch_id, 0);

				path = shortestpath(ginfo.diG, sourcenodeindex, destinationnodeindex);

				if ~isempty(path),
					t_out = t_in-timeref_in.time;
					for i=1:numel(path)-1,
						t_out = ginfo.mapping{path(i),path(i+1)}.map(t_out);
					end
				end
		end % time_convert()

		function saveStruct = getsavestruct(nsd_syncgraph_obj)
			% GETSAVESTRUCT - Create a structure representation of the object that is free of handles and objects
			%
			% SAVESTRUCT = GETSAVESTRUCT(NSD_SYNCGRAPH_OBJ)
			%
			% Creates a structure representation of the NSD_SYNCGRAPH_OBJ that is free of object handles
			%
			% SAVESTRUCT has the following properties:
			%
			% Fieldname                 | Description
			% -------------------------------------------------------------------------------------
			% objectfilename            | The object file name string as is
			% experiment                | the reference of the NSD_EXPERIMENT object associated with NSD_SYNCGRAPH_OBJ
			% rules                     | a structure describing each NSD_SYNCRULE with fields:
			%                           |   'class' - the object class, and 'parameters' - the parameters

				saveStruct.objectfilename = nsd_syncgraph_obj.objectfilename;

				if isa(nsd_syncgraph_obj.experiment,'nsd_experiment'),
					% though this will be replaced, it might help in debugging
					saveStruct.experiment = nsd_syncgraph_obj.experiment.reference; 
				end

				saveStruct.rules = emptystruct('class','parameters');
				for i=1:numel(nsd_syncgraph_obj.rules),
					saveStruct.rules(end+1) = struct('class',class(nsd_syncgraph_obj.rules{i}), ...
						'parameters', nsd_syncgraph_obj.rules{i}.parameters);
				end

		end % getsavestruct()

		% methods that override NSD_BASE:

		function fname = outputobjectfilename(nsd_syncgraph_obj)
			% OUTPUTOBJECTFILENAME - return the file name of an NSD_SYNCGRAPH object
			%
			% FNAME = OUTPUTOBJECTFILENAME(NSD_SYNCGRAPH_OBJ)
			%
			% Returns the filename (without parent directory) to be used to save the NSD_SYNCGRAPH
			% object. In the NSD_SYNCGRAPH class, it is [NSD_BASE_OBJ.objectfilename '.syncgraph.nsd']
			%
			%
				fname = [nsd_syncgraph_obj.objectfilename '.syncgraph.nsd'];
		end % outputobjectfilename()

		function writedata2objectfile(nsd_syncgraph_obj, fid)
			% WRITEDATA2OBJECTFILE - write NSD_SYNCGRAPH object file data to the object file FID
			%
			% WRITEDATA2OBJECTFILE(NSD_SYNCGRAPH_OBJ, FID)
			%
			% This function writes the data for the NSD_SYNCGRAPH_OBJ to the object file
			% identifier FID.
			%
			% This function assumes the FID is open for writing and it does not close the
			% the FID. This function is normally called by WRITEOBJECTFILE and is typically
			% an internal function.
			%
				saveStruct = nsd_syncgraph_obj.getsavestruct;

				saveStructString = struct2mlstr(saveStruct);
				count = fwrite(fid,saveStructString,'char');
				if count~=numel(saveStructString),
					error(['Error writing to the file ' filename '.']);
				end
		end % writedata2objectfile()

		function nsd_syncgraph_obj = readobjectfile(nsd_syncgraph_obj, filename)
			% READOBJECTFILE - read
			%
			% NSD_SYNCGRAPH_OBJ = READOBJECTFILE(NSD_SYNCGRAPH_OBJ, FILENAME)
			%
			% Reads the NSD_SYNCGRAPH_OBJ from the file FNAME (full path).
				fid = fopen(filename, 'rb');
				if fid<0,
					error(['Could not open the file ' filename ' for reading.']);
				end;
				saveStructString = char(fread(fid,Inf,'char'));
				saveStructString = saveStructString(:)'; % make sure we are a 'row'
				fclose(fid);
				saveStruct = mlstr2var(saveStructString);
				fn = setdiff(fieldnames(saveStruct),'experiment');
				values = {};
				for i=1:numel(fn),
					values{i} = getfield(saveStruct,fn{i});
				end;
				nsd_syncgraph_obj = nsd_syncgraph_obj.setproperties(fn,values);
		end; % readobjectfile

		function [obj,properties_set] = setproperties(nsd_syncgraph_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_DBLEAF object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_SYNCGRAPH_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_SYNCGRAPH_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_SYNCGRAPH_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(nsd_syncgraph_obj);
				obj = nsd_syncgraph_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if strcmp(properties{i},'rules'),
							if isstruct(values{i}),
								obj.rules = {};
								for v=1:numel(values{i}),
									eval(['obj.rules{v}=' values{i}(v).class '(values{i}(v).parameters);']);
								end
								properties_set{end+1} = 'rules';
							else,
								error(['Do not know how to add rules that aren''t a structure.']);
							end
						else,
							if properties{i}(1)~='$',
								eval(['obj.' properties{i} '= values{i};']);
								properties_set{end+1} = properties{i};
							else,
								eval(['obj.' properties{i}(2:end) '=' values{i} ';']);
								properties_set{end+1} = properties{i}(2:end);
							end
						end
					end
				end
		end % setproperties()

		% cache

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
					exp = nsd_syncgraph_obj.experiment();
					cache = exp.cache;
					key = nsd_syncgraph_obj.objectfilename;
				end
		end

	end % methods

end % classdef nsd_syncgraph
