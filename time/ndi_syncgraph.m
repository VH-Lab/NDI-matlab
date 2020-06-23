classdef ndi_syncgraph < ndi_id

	properties (SetAccess=protected,GetAccess=public)
		session      % NDI_SESSION object
		rules		% cell array of NDI_SYNCRULE objects to apply
	end
	properties (SetAccess=protected,GetAccess=private)
	end

	methods
	
		function ndi_syncgraph_obj = ndi_syncgraph(varargin)
			% NDI_SYNCGRAPH - create a new NDI_SYNCGRAPH object
			%
			% NDI_SYNCGRAPH_OBJ = NDI_SYNCGRAPH(SESSION)
			% 
			% Builds a new NDI_SYNCGRAPH object and sets its SESSION
			% property to SESSION, which should be an NDI_SESSION object.
			%
			% This function can be called in another form:
			% NDI_SYNCGRAPH_OBJ = NDI_SYNCGRAPH(SESSION, NDI_DOCUMENT_OBJ)
			% where NDI_DOCUMENT_OBJ is an NDI_DOCUMENT of class ndi_document_syncgraph.
			%
			
			%need to be tested after ndi_syncrule creator is done
			if nargin == 2 && isa(varargin{1},'ndi_session') && isa(varargin{2}, 'ndi_document')
				ndi_syncgraph_obj.session = varargin{1};
				[syncgraph_doc, syncrule_doc] = ndi_syncgraph.load_all_syncgraph_docs(varargin{1},varargin{2}.id());
				ndi_syncgraph_obj.identifier = varargin{2}.id();
				for i=1:numel(syncrule_doc),
					ndi_syncgraph_obj = ndi_syncgraph_obj.addrule(ndi_document2ndi_object(syncrule_doc{i},varargin{1}));
				end;
            		else,
				session = [];

				if nargin>0,
					session = varargin{1};
				end;
	
				ndi_syncgraph_obj.session = session;

				if nargin>=2,
					if strcmp(lower(varargin{2}),lower('OpenFile')),
						error(['Load from file no longer supported.']);
						ndi_syncgraph_obj = ndi_syncgraph_obj.readobjectfile(varargin{1});
					end;
				end;
			end;
		end % ndi_syncgraph

		function b = eq(ndi_syncgraph_obj1, ndi_syncgraph_obj2)
			% EQ - are 2 NDI_SYNCGRAPH objects equal?
			%
			% B = EQ(NDI_SYNCGRAPH_OBJ1, NDI_SYNCHGRAPH_OBJ2)
			%
			% B is 1 if the NDI_SYNCGRAPH objects have equal sessions and if 
			% all syncrules are equal.
			%
				b = eq(ndi_syncgraph_obj1.session, ndi_syncgraph_obj2.session);
				b = b & (numel(ndi_syncgraph_obj1.rules)==numel(ndi_syncgraph_obj2.rules));
				if b,
					for i=1:numel(ndi_syncgraph_obj1.rules),
						b = b & (ndi_syncgraph_obj1.rules{i} == ndi_syncgraph_obj2.rules{i});
					end;
				end;
		end; % eq();

		function ndi_syncgraph_obj = addrule(ndi_syncgraph_obj, ndi_syncrule_obj)
			% ADDRULE - add an NDI_SYNCRULE to an NDI_SYNCGRAPH object
			%
			% NDI_SYNCGRAPH_OBJ = ADDRULE(NDI_SYNCGRAPH_OBJ, NDI_SYNCRULE_OBJ)
			%
			% Adds the NDI_SYNCRULE object indicated as a rule for
			% the NDI_SYNCGRAPH NDI_SYNCGRAPH_OBJ. If the NDI_SYNCRULE is already
			% there, then 
			%
			% See also: NDI_SYNCGRAPH/REMOVERULE

				if ~iscell(ndi_syncrule_obj),
					ndi_syncrule_obj = {ndi_syncrule_obj};
				end

				for i=1:numel(ndi_syncrule_obj),
					if isa(ndi_syncrule_obj{i},'ndi_syncrule'),
						% check for duplication
						match = -1;
						for j=1:numel(ndi_syncgraph_obj.rules),
							if ndi_syncgraph_obj.rules{j}==ndi_syncrule_obj{i},
								match = j;
								break;
							end
						end
						if match<0,
							ndi_syncgraph_obj.rules{end+1} = ndi_syncrule_obj{i};
						end
					else,
						error('Input not of type NDI_SYNCRULE.');
					end
				end

		end % addrule()

		function ndi_syncgraph_obj = removerule(ndi_syncgraph_obj, index)
			% REMOVERULE - remove a given NDI_SYNCRULE from an NDI_SYNCGRAPH object
			%
			% NDI_SYNCGRAPH_OBJ = REMOVERULE(NDI_SYNCGRAPH_OBJ, INDEX)
			%
			% Removes the NDI_SYNCGRAPH_OBJ.rules entry at the INDEX (or indexes) indicated.
			%
				n = numel(ndi_syncgraph_obj.rules);
				ndi_syncgraph_obj.rules = ndi_syncgraph_obj.rules(setdiff(1:n),index);

		end % removerule()

		function [ginfo,hashvalue] = graphinfo(ndi_syncgraph_obj);
			% GRAPHINFO - return the graph information 
			%
			% 
			% The graph information GINFO is a structure with the following fields:
			% Fieldname              | Description
			% ---------------------------------------------------------------------
			% nodes                  | The epochnodes (see NDI_EPOCHSET/EPOCHNODE)
			% G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
			%                        |   converting between node i and j.
			% mapping                | A cell matrix with NDI_TIMEMAPPING objects that describes the
			%                        |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
			%
				[ginfo, hashvalue] = cached_graphinfo(ndi_syncgraph_obj);
				if isempty(ginfo),
					ginfo = ndi_syncgraph_obj.buildgraphinfo();
					set_cached_graphinfo(ndi_syncgraph_obj, ginfo);
				end
		end % graphinfo
				
		function [ginfo] = buildgraphinfo(ndi_syncgraph_obj)
			% BUILDGRAPHINFO - build graph info for an NDI_SYNCGRAPH object
			%
			% [GINFO] = BUILDGRAPHINFO(NDI_SYNCGRAPH_OBJ)
			%
			% Builds from scratch the syncgraph structure GINFO from all of the devices
			% in the NDI_SYNCGRAPH_OBJ's associated 'session' property.
			%
			% The graph information GINFO is a structure with the following fields:
			% Fieldname              | Description
			% ---------------------------------------------------------------------
			% nodes                  | The epochnodes (see NDI_EPOCHSET/EPOCHNODE)
			% G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
			%                        |   converting between node i and j.
			% mapping                | A cell matrix with NDI_TIMEMAPPING objects that describes the
			%                        |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
			% diG                    | The graph data structure in Matlab for G (a 'digraph')
			%
				ginfo.nodes = emptystruct('epoch_id','epoch_session_id','epochprobemap',...
					'epoch_clock','t0_t1','underlying_epochs','objectname','objectclass');
				ginfo.G = [];
				ginfo.mapping = {};
				ginfo.diG = [];

				d = ndi_syncgraph_obj.session.daqsystem_load('name','(.*)');
				if ~iscell(d) & ~isempty(d), d = {d}; end; % make sure we are a cell

				for i=1:numel(d),
					ginfo = ndi_syncgraph_obj.addepoch(d{i}, ginfo);
				end
		end % buildgraphinfo

		function [ginfo,hashvalue]=cached_graphinfo(ndi_syncgraph_obj)
			% CACHED_GRAPHINFO - return the cached graph info of an NDI_SYNCGRAPH object
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
				if (~isempty(cache) & ~isempty(key)),
					table_entry = cache.lookup(key,'syncgraph-hash');
					if ~isempty(table_entry),
						ginfo = table_entry(1).data.graphinfo;
						hashvalue = table_entry(1).data.hashvalue;
					end;
				end
		end % cached_epochtable

		function set_cached_graphinfo(ndi_syncgraph_obj, ginfo)
			% SET_CACHED_GRAPHINFO
			%
			% SET_CACHED_GRAPHINFO(NDI_SYNCGRAPH_OBJ, GINFO)
			%
			% Set the cached graph info. Opposite of CACHE_GRAPHINFO.
			% 
			% See also: CACHE_GRAPHINFO
				[cache,key] = getcache(ndi_syncgraph_obj);
				if ~isempty(cache),
					hashvalue = hashmatlabvariable(ginfo);
					priority = 1;
					cache.remove(key,'syncgraph-hash');
					cache.add(key,'syncgraph-hash',struct('graphinfo',ginfo,'hashvalue',hashvalue),priority);
				end
		end % set_cached_graphinfo

		function ginfo = addepoch(ndi_syncgraph_obj, ndi_daqsystem_obj, ginfo)
			% ADDEPOCH - add an NDI_EPOCHSET to the graph
			% 
			% NEW_GINFO = ADDEPOCH(NDI_SYNCGRAPH_OBJ, NDI_DAQSYSTEM_OBJ, GINFO)
			%
			% Adds an NDI_EPOCHSET to the NDI_SYNCGRAPH
			%
			% Note: this does not update the cache
			% 
				% Step 1: make sure we have the right kind of input object
				if ~isa(ndi_daqsystem_obj, 'ndi_daqsystem'),
					error(['The input NDI_DAQSYSTEM_OBJ must be of class NDI_DAQSYSTEM or a subclass.']);
				end

				% Step 2: make sure it is not duplicative

				if numel(ginfo)>0,
					tf = strcmp(ndi_daqsystem_obj.name,{ginfo.nodes.objectname});
				else,
					tf = [];
				end
				if any(tf), % we already have this object
					% in the future, we'll make this method that saves time. For initial development, we'll complain
					%ginfo = updateepochs(ndi_syncgraph_obj, ndi_daqsystem_obj, ginfo);
					%return;
					error(['This graph already has epochs from ' name '.']);
				end

				% Step 3: ok, we have established it is novel, add it to our graph

					% Step 3.1: add the within-device graph to our graph

				newnodes = ndi_daqsystem_obj.epochnodes();
				[newcost,newmapping] = ndi_daqsystem_obj.epochgraph;

				oldn = numel(ginfo.nodes);
				newn = numel(newnodes);

				ginfo.nodes = cat(2,ginfo.nodes(:)',newnodes(:)');

					% developer note: will probably have to change G to a sparse matrix with zero meaning 'no connection'

				ginfo.G = [ ginfo.G inf(oldn,newn); inf(newn,oldn) newcost ] ;
				ginfo.mapping = [ ginfo.mapping cell(oldn,newn) ; cell(newn,oldn) newmapping];
				
					% Step 3.2: add any 'duh' connections ('utc' -> 'utc', etc) based purely on ndi_clocktype

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
								for k=1:numel(ndi_syncgraph_obj.rules),
									[c,m] = apply(ndi_syncgraph_obj.rules{k}, ginfo.nodes(i_), ginfo.nodes(j_));
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

		function ginfo = addunderlyingepochs(ndi_syncgraph_obj, ndi_epochset_obj, ginfo)
			% ADDUNDERLYINGEPOCH - add an NDI_EPOCHSET to the graph
			% 
			% NEW_GINFO = ADDUNDERLYINGEPOCHS(NDI_SYNCGRAPH_OBJ, NDI_EPOCHSET_OBJ, GINFO)
			%
			% Adds an NDI_EPOCHSET to the NDI_SYNCGRAPH
			%
			% Note: this DOES update the cache
			% 
				% Step 1: make sure we have the right kind of input object
				if ~isa(ndi_epochset_obj, 'ndi_epochset'),
					error(['The input NDI_EPOCHSET_OBJ must be of class NDI_EPOCHSET or a subclass.']);
				end;

				enodes = epochnodes(ndi_epochset_obj);
				% do we search for duplicates?

				for i=1:numel(enodes),
					index = ndi_findepochnode(enodes(i), ginfo.nodes);

					if isempty(index), % we don't have this one, we need to add it

						underlying_nodes = underlyingepochnodes(ndi_epochset_obj, enodes(i));

						[u_nodes,u_cost,u_mapping] = underlyingepochnodes(ndi_epochset_obj, enodes(i));

						% now we have a set of elements to add to the graph

						u_node_index_in_main = NaN(numel(u_nodes),1);
						for j=1:numel(u_nodes),
							myindex = ndi_findepochnode(u_nodes(j), ginfo.nodes);
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

				ndi_syncgraph_obj.set_cached_graphinfo(ginfo);
		end % addunderlyingnodes

		function ginfo = removeepoch(ndi_syncgraph_obj, ndi_daqsystem_obj, ginfo)
			% REMOVEEPOCHS - remove an NDI_EPOCHSET from the graph
			%
			% GINFO = REMOVEEPOCHS(NDI_SYNCGRAPH_OBJ, NDI_DAQSYSTEM_OBJ, GINFO)
			%
			% Remove all epoch nodes from the graph that are contributed by NDI_DAQSYSTEM_OBJ
			%
			% Note: this does not update the cache

				tf = find(strcmp(ndi_daqsystem_obj.name,{ginfo.nodes.objectname}));

				keep = setdiff(1:numel(ginfo.nodes));

				ginfo.G = ginfo.G(keep,keep);
				ginfo.mapping = ginfo.mapping(keep,keep);
				ginfo.nodes = ginfo.nodes(keep);
				
				Gtable = ginfo.G;
				Gtable(find(isinf(Gtable))) = 0;
				ginfo.diG = digraph(Gtable);

		end % removeepoch

		function [t_out, timeref_out, msg] = time_convert(ndi_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out)
			% TIME_CONVERT - convert time from one NDI_TIMEREFERENCE to another
			%
			% [T_OUT, TIMEREF_OUT, MSG] = TIME_CONVERT(NDI_SYNCGRAPH_OBJ, TIMEREF_IN, T_IN, REFERENT_OUT, CLOCKTYPE_OUT)
			%
			% Attempts to convert a time T_IN that is referred to by NDI_TIMEREFERENCE object TIMEREF_IN 
			% to T_OUT that is referred to by the requested REFERENT_OUT object (must be type NDI_EPOCHSET and NDI_BASE)
			% with the requested NDI_CLOCKTYPE CLOCKTYPE_OUT.
			% 
			% T_OUT is the output time with respect to the NDI_TIMEREFERENCE TIMEREF_OUT that incorporates REFERENT_OUT
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

				ginfo = graphinfo(ndi_syncgraph_obj);

				% STEP 1: identify the source node

				sourcenodeindex = ndi_findepochnode(...
					struct('objectname',epochsetname(timeref_in.referent), 'objectclass', class(timeref_in.referent),...
					'epoch_id',in_epochid, 'epoch_session_id', ndi_syncgraph_obj.session.id(), ...
					'epoch_clock', timeref_in.clocktype),...
					ginfo.nodes);

				% should be a single item now
				if numel(sourcenodeindex)>1,
					msg = ['expected start epochnode to be a single node, but it is not.'];
					return;
				elseif numel(sourcenodeindex)==0,
					% we do not have the node; add underlying epochs and try one more time
					ndi_syncgraph_obj.addunderlyingepochs(timeref_in.referent,ginfo);
					ginfo = graphinfo(ndi_syncgraph_obj);

					sourcenodeindex = ndi_findepochnode(...
						struct('objectname',epochsetname(timeref_in.referent), 'objectclass', class(timeref_in.referent),...
						'epoch_id',in_epochid, 'epoch_session_id', ndi_syncgraph_obj.session.id(), ...
						'epoch_clock', timeref_in.clocktype),...
						ginfo.nodes);

					if numel(sourcenodeindex)==0,
						msg = ['Could not find any such source node.'];
						return;
					elseif numel(sourcenodeindex)>1,
						msg = ['expected start epochnode to be a single node, but it is not.'];
						return;
					end;
					% if we made it here, we are in good shape with a sourcenodeindex that is real
				end

				if isempty(sourcenodeindex), return; end; % if we did not find it, we failed

				% STEP 2: narrow the search for the destination node. It has to match our referent and it has to 
				%     match the requested clock type

				destinationnodeindexes = ndi_findepochnode(...
					struct('objectname', epochsetname(referent_out), 'objectclass', class(referent_out), ...
					'epoch_clock', clocktype_out), ginfo.nodes);

				if isempty(destinationnodeindexes),
					% no candidate output nodes, see if any are there any from that referent
					any_referent_outs = ndi_findepochnode(...
						struct('objectname', epochsetname(referent_out), 'objectclass', class(referent_out)), ...
						ginfo.nodes);
					if isempty(any_referent_outs), % add the referent to the table and try again
						ndi_syncgraph_obj.addunderlyingepochs(referent_out,ginfo);
						[t_out,timeref_out,msg] = time_convert(ndi_syncgraph_obj, timeref_in, t_in, referent_out, clocktype_out);
						return;
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
				elseif numel(indexes)==0,
					msg = 'Cannot get there from here, no path';
					return;
				end

				destinationnodeindex = destinationnodeindexes(indexes);

				% make the timeref_out based on the node we found, use timeref of 0
				timeref_out = ndi_timereference(referent_out, ginfo.nodes(destinationnodeindex).epoch_clock, ...
					ginfo.nodes(destinationnodeindex).epoch_id, 0);

				path = shortestpath(ginfo.diG, sourcenodeindex, destinationnodeindex);

				if ~isempty(path),
					t_out = t_in-timeref_in.time;
					for i=1:numel(path)-1,
						t_out = ginfo.mapping{path(i),path(i+1)}.map(t_out);
					end
				end
		end % time_convert()

		% methods that override NDI_BASE:

		% cache

		function [cache,key] = getcache(ndi_syncgraph_obj)
			% GETCACHE - return the NDI_CACHE and key for NDI_SYNCGRAPH
			%
			% [CACHE,KEY] = GETCACHE(NDI_SYNCGRAPH_OBJ)
			%
			% Returns the CACHE and KEY for the NDI_SYNCGRAPH object.
			%
			% The CACHE is returned from the associated session.
			% The KEY is the string 'syncgraph_' followed by the object's id.
			%
			% See also: NDI_SYNCGRAPH, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_syncgraph_obj.session,'handle'),
					exp = ndi_syncgraph_obj.session;
					cache = exp.cache;
					key = ['syncgraph_' ndi_syncgraph_obj.id()];
				end
		end; % getcache()
		
                %% functions that override ndi_documentservice

		function ndi_document_obj_set = newdocument(ndi_syncgraph_obj)
			% NEWDOCUMENT - create a new NDI_DOCUMENT for an NDI_SYNCGRAPH object
			%
			% NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_SYNCGRAPH_OBJ)
			%
			% Creates an NDI_DOCUMENT object DOC that represents the
			%    NDI_SYNCRULE object.
				ndi_document_obj_set{1} = ndi_document('ndi_document_syncgraph.json',...
					'syncgraph.ndi_syncgraph_class',class(ndi_syncgraph_obj),...
					'ndi_document.id', ndi_syncgraph_obj.id(),...
					'ndi_document.session_id', ndi_syncgraph_obj.session.id());
				for i=1:numel(ndi_syncgraph_obj.rules),
					ndi_document_obj_set{end+1} = ndi_syncgraph_obj.rules{i}.newdocument();
					ndi_document_obj_set{1} = ndi_document_obj_set{1}.add_dependency_value_n('syncrule_id',ndi_syncgraph_obj.rules{i}.id());
				end;
		end; % newdocument()

		function sq = searchquery(ndi_syncgraph_obj)
			% SEARCHQUERY - create a search for this NDI_SYNCGRAPH object
			%
			% SQ = SEARCHQUERY(NDI_SYNCGRAPH_OBJ)
			%
			% Creates a search query for the NDI_SYNCGRAPH object.
			%
				sq = {'ndi_document.id', ndi_syncgraph_obj.id() , ...
					'ndi_document.session_id', ndi_syncgraph_obj.session.id() };
		end; % searchquery()


	end % methods

	methods (Static)
		function [syncgraph_doc, syncrule_docs] = load_all_syncgraph_docs(ndi_session_obj, syncgraph_doc_id)
			% LOAD_ALL_SYNCGRAPH_DOCS - load a syncgraph document and all of its syncrules
			%
			% [SYNCGRAPH_DOC, SYNCRULE_DOCS] = LOAD_ALL_SYNCGRAPH_DOCS(NDI_SESSION_OBJ,...
			%					SYNCGRAPH_DOC_ID)
			%
			% Given an NDI_SESSION object and the document identifier of an NDI_SYNCGRAPH object,
			% this function loads the NDI_DOCUMENT associated with the SYNCGRAPH (SYNCGRAPH_DOC) and all of
			% the documents of its SYNCRULES (cell array of NDI_DOCUMENTS in SYNCRULES_DOC).
			%
				syncrule_docs = {};
				syncgraph_doc = ndi_session_obj.database_search(ndi_query('ndi_document.id', 'exact_string', ...
					syncgraph_doc_id,''));
				switch numel(syncgraph_doc),
					case 0,
						syncgraph_doc = [];
						return;
					case 1,
						syncgraph_doc = syncgraph_doc{1};
					otherwise,
						error(['More than 1 document with ndi_document.id value of ' ...
							syncgraph_doc_id '. Do not know what to do.']);
				end;

				rules_id_list = syncgraph_doc.dependency_value_n('syncrule_id');
				for i=1:numel(rules_id_list),
					rules_doc = ndi_session_obj.database_search(ndi_query(...
						'ndi_document.id','exact_string',rules_id_list{i},''));
					if numel(rules_doc)~=1,
						error(['Could not find syncrule with id ' rules_id_list{i} ...
							'; found ' int2str(numel(rules_doc)) ' occurrences']);
					end;
					syncrule_docs{i} = rules_doc{1};
				end
		end; % load_all_syncgraph_docs()
	end % static methods

end % classdef ndi_syncgraph
