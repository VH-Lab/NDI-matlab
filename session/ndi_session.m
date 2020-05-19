classdef ndi_session < handle
	% NDI_SESSION - NDI_SESSION object class

	properties (GetAccess=public, SetAccess = protected)
		reference         % A string reference for the session
		unique_reference  % A unique code that uniquely identifies this session
		syncgraph         % An NDI_SYNCGRAPH object related to this session
		cache             % An NDI_CACHE object for the session's use
	end
	properties (GetAccess=protected, SetAccess = protected)
		database          % An NDI_DATABASE associated with this session
	end
	methods
		function ndi_session_obj = ndi_session(reference)
			% ndi_session - Create a new NDI_SESSION object
			%
			%   NDI_SESSION_OBJ=NDI_SESSION(REFERENCE)
			%
			% Creates a new NDI_SESSION object. The session has a unique
			% reference REFERENCE. This class is an abstract class and typically
			% an end user will open a specific subclass such as NDI_SESSION_DIR.
			%
			% NDI_SESSION objects can access 0 or more NDI_DAQSYSTEM objects.
			%
			% See also: NDI_SESSION/DAQSYSTEM_ADD, NDI_SESSION/DAQSYSTEM_RM, 
			%   NDI_SESSION/GETPATH, NDI_SESSION/GETREFERENCE

				ndi_session_obj.reference = reference;
				ndi_session_obj.unique_reference = ndi_unique_id;
				ndi_session_obj.database = [];
				ndi_session_obj.syncgraph = ndi_syncgraph(ndi_session_obj);
				ndi_session_obj.cache = ndi_cache();
		end

		%%%%%% REFERENCE METHODS
	
		function refstr = unique_reference_string(ndi_session_obj)
			% UNIQUE_REFERENCE_STRING - return the unique reference string for this session
			%
			% REFSTR = UNIQUE_REFERENCE_STRING(NDI_SESSION_OBJ)
			%
			% Returns the unique reference string for the NDI_SESSION.
			% REFSTR is a combination of the REFERENCE property of NDI_SESSION_OBJ
			% and the UNIQUE_REFERENCE property of NDI_SESSION_OBJ, joined with a '_'.
				warning('unique_reference_string depricated, use id() instead.');
				dbstack
				refstr = [ndi_session_obj.reference '_' ndi_session_obj.unique_reference];
		end % unique_reference_string()

		%%%%%% DEVICE METHODS

		function ndi_session_obj = daqsystem_add(ndi_session_obj, dev)
			%DAQSYSTEM_ADD - Add a sampling device to a NDI_SESSION object
			%
			%   NDI_SESSION_OBJ = DAQSYSTEM_ADD(NDI_SESSION_OBJ, DEV)
			%
			% Adds the device DEV to the NDI_SESSION NDI_SESSION_OBJ
			%
			% The devices can be accessed by referencing NDI_SESSION_OBJ.device
			%  
			% See also: DAQSYSTEM_RM, NDI_SESSION

				if ~isa(dev,'ndi_daqsystem'),
					error(['dev is not a ndi_daqsystem']);
				end;
				% search if the daqsystem_obj already exists in the database(based on daqsystem name and session_id)
               			 % if so, pass; otherwise, create a new document from this daqsystem_obj and add it to the database

				% make sure this daqsystem matches our session
				dev = dev.setsession(ndi_session_obj);
                
				sq = dev.searchquery();
				search_result = ndi_session_obj.database_search(sq);
				if numel(search_result) == 0
					% no match was found, can add to the database
					doc_set = dev.newdocument();
					ndi_session_obj.database_add(doc_set);
				else,
					error(['dev already exists in the database.']);    
				end
		end;

		function ndi_session_obj = daqsystem_rm(ndi_session_obj, dev)
			% DAQSYSTEM_RM - Remove a sampling device from an NDI_SESSION object
			%
			% NDI_SESSION_OBJ = DAQSYSTEM_RM(NDI_SESSION_OBJ, DEV)
			%
			% Removes the device DEV from the device list.
			%
			% See also: DAQSYSTEM_ADD, NDI_SESSION
            
				if ~isa(dev,'ndi_daqsystem')
					error(['dev is not a ndi_daqsystem']);
				end;
				daqsys = ndi_session_obj.daqsystem_load('name',dev.name);
				if ~isempty(daqsys) 
					docs = ndi_session_obj.database_search(daqsys.searchquery());
					if numel(docs)~=1,
						error(['More than one document found for ' dev.name ', not sure what to do.']);
					end;
					for i=1:numel(docs{1}.document_properties.depends_on),
						dochere = ndi_session_obj.database_search(...
							ndi_query('ndi_document.id', 'exact_string', docs{1}.document_properties.depends_on(i).value, ''));
						ndi_session_obj.database_rm(dochere);
					end;
					ndi_session_obj.database_rm(docs); % database_rm can process single or a cell list of ndi_document_obj(s)
				else
					error(['No daqsystem named ' dev{j}.name ' found.']);
				end;
		end; % daqsystem_rm()

		function dev = daqsystem_load(ndi_session_obj, varargin)
			% DAQSYSTEM_LOAD - Load daqsystem objects from an NDI_SESSION
			%
			% DEV = DAQSYSTEM_LOAD(NDI_SESSION_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% DEV = DAQSYSTEM_LOAD(NDI_SESSION_OBJ)
			%
			% Returns the ndi_daqsystem objects in the NDI_SESSION with metadata parameters PARAMS1 that matches
			% VALUE1, PARAMS2 that matches VALUE2, etc.
			%
			% One can also search for 'name' as a parameter; this will be automatically changed to search
			% for database documents with fields 'ndi_document.name' equal to the corresponding value.
			%
			% If more than one object is requested, then DEV will be a cell list of matching objects.
			% Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
			%
				dev = {};
				q1 = ndi_query('','isa','ndi_document_daqsystem','');
				q2 = ndi_query('ndi_document.session_id','exact_string',ndi_session_obj.id(),'');
				q = q1 & q2;
				if numel(varargin)>0,
					for i=1:2:numel(varargin),
						if strcmpi(varargin{i},'name'),
							varargin{i} = 'ndi_document.name'; % case matters here
						end;
					end;
					q = q & ndi_query(varargin);
				end;
				dev_doc = ndi_session_obj.database_search(q);
				% dev is cell list of ndi_document objects
				for i=1:numel(dev_doc),
					dev{i} = ndi_document2ndi_object(dev_doc{i},ndi_session_obj);
				end;
				
				if numel(dev)==1,
					dev = dev{1};
				end;
		end; % daqsystem_load()	

		function ndi_session_obj = daqsystem_clear(ndi_session_obj)
			% DAQSYSTEM_CLEAR - remove all DAQSYSTEM objects from an NDI_SESSION
			%
			% NDI_SESSION_OBJ = DAQSYSTEM_CLEAR(NDI_SESSION_OBJ)
			%
			% Permanently removes all NDI_DAQSYSTEM objects from an NDI_SESSION.
			%
			% Be sure you mean it!
			%
				dev = ndi_session_obj.daqsystem_load('name','(.*)');
				if ~isempty(dev) & ~iscell(dev),
					dev = {dev};
				end;
				for i=1:numel(dev),
					ndi_session_obj = ndi_session_obj.daqsystem_rm(dev{i});
				end;

		end; % daqsystem_clear();

		% NDI_DOCUMENTSERVICE methods

		function ndi_document_obj = newdocument(ndi_session_obj, document_type, varargin)
		% NEWDOCUMENT - create a new NDI_DATABASE document of type NDI_DOCUMENT
		%
		% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SESSION_OBJ, [DOCUMENT_TYPE], 'PROPERTY1', VALUE1, ...)
		%
		% Creates an empty database document NDI_DOCUMENT_OBJ. DOCUMENT_TYPE is
		% an optional argument and can be any type that confirms to the .json
		% files in $NDI_COMMON/database_documents/*, a URL to such a file, or
		% a full path filename. If DOCUMENT_TYPE is not specified, it is taken
		% to be 'ndi_document.json'.
		%
		% If additional PROPERTY values are specified, they are set to the VALUES indicated.
		%
		% Example: mydoc = ndi_session_obj.newdocument('ndi_document','ndi_document.name','myname');
		%
			if nargin<2,
				document_type = 'ndi_document.json';
			end
			inputs = cat(2,varargin,{'ndi_document.session_id', ndi_session_obj.id()});
			ndi_document_obj = ndi_document(document_type, inputs);
		end; %newdocument()

		function sq = searchquery(ndi_session_obj)
		% SEARCHQUERY - return a search query for database objects in this session
		%
		% SQ = SEARCHQUERY(NDI_SESSION_OBJ)
		%
		% Returns a search query that will match all NDI_DOCUMENT objects that were generated
		% by this session.
		%
		% SQ = {'ndi_document.session_id', ndi_session_obj.id()};
		% 
		% Example: mydoc = ndi_session_obj.newdocument('ndi_document','ndi_document.name','myname');
		%
			sq = {'ndi_document.session_id', ndi_session_obj.id()};
		end; %searchquery()

		% NDI_DATABASE / NDI_DOCUMENT methods

		function ndi_session_obj = database_add(ndi_session_obj, document)
			%DATABASE_ADD - Add an NDI_DOCUMENT to an NDI_SESSION object
			%
			% NDI_SESSION_OBJ = DATABASE_ADD(NDI_SESSION_OBJ, NDI_DOCUMENT_OBJ)
			%
			% Adds the NDI_DOCUMENT NDI_DOCUMENT_OBJ to the NDI_SESSION NDI_SESSION_OBJ.
			% NDI_DOCUMENT_OBJ can also be a cell array of NDI_DOCUMENT objects, which will all be added
			% in turn.
			% 
			% The database can be queried by calling NDI_SESSION_OBJ/SEARCH
			%  
			% See also: DATABASE_RM, NDI_SESSION, NDI_DATABASE, NDI_SESSION/SEARCH

				if iscell(document),
					for i=1:numel(document),
						ndi_session_obj.database_add(document{i});
					end;
					return;
				end;
				if ~isa(document,'ndi_document'),
					error(['document is not an NDI_DOCUMENT']);
				end;
				ndi_session_obj.database.add(document);
		end; % database_add()

		function ndi_session_obj = database_rm(ndi_session_obj, doc_unique_id, varargin)
			% DATABASE_RM - Remove an NDI_DOCUMENT with a given document ID from an NDI_SESSION object
			%
			% NDI_SESSION_OBJ = DATABASE_RM(NDI_SESSION_OBJ, DOC_UNIQUE_ID)
			%   or
			% NDI_SESSION_OBJ = DATABASE_RM(NDI_SESSION_OBJ, DOC)
			%
			% Removes an NDI_DOCUMENT with document id DOC_UNIQUE_ID from the
			% NDI_SESSION_OBJ.database. In the second form, if an NDI_DOCUMENT or cell array of
			% NDI_DOCUMENTS is passed for DOC, then the document unique ids are retrieved and they
			% are removed in turn.  If DOC/DOC_UNIQUE_ID is empty, no action is taken.
			%
			% This function also takes parameters as name/value pairs that modify its behavior:
			% Parameter (default)        | Description
			% --------------------------------------------------------------------------------
			% ErrIfNotFound (0)          | Produce an error if an ID to be deleted is not found.
			%
			% See also: DATABASE_ADD, NDI_SESSION
				ErrIfNotFound = 0;
				assign(varargin{:});

				if isempty(doc_unique_id),
					return;
				end; % nothing to do

				if ~iscell(doc_unique_id),
					if ischar(doc_unique_id), % it is a single doc id
						mydoc = ndi_session_obj.database_search(ndi_query('ndi_document.id','exact_string',doc_unique_id,''));
						if isempty(mydoc), % 
							if ErrIfNotFound,
								error(['Looked for an ndi_document matching ID ' doc_unique_id ' but found none.']);
							else,
								return; % nothing to do
							end;
						end;
						doc_unique_id = mydoc; % now a cell list
					elseif isa(doc_unique_id,'ndi_document'),
						doc_unique_id = {doc_unique_id};
					else,
						error(['Unknown input to DATABASE_RM of class ' class(doc_unique_id) '.']);
					end;
				end;

				if iscell(doc_unique_id),
					dependent_docs = ndi_findalldependencies(ndi_session_obj,[],doc_unique_id{:});
					if numel(dependent_docs)>1,
						warning(['Also deleting ' int2str(numel(dependent_docs)) ' dependent docs.']);
					end;
					for i=1:numel(dependent_docs),
						ndi_session_obj.database.remove(dependent_docs{i});
					end;
					for i=1:numel(doc_unique_id), 
						ndi_session_obj.database.remove(doc_unique_id{i});
					end;
				else,
					error(['Did not think we could get here..notify steve.']);
				end;
		end; % database_rm

		function ndi_document_obj = database_search(ndi_session_obj, searchparameters)
			% DATABASE_SEARCH - Search for an NDI_DOCUMENT in a database of an NDI_SESSION object
			%
			% NDI_DOCUMENT_OBJ = DATABASE_SEARCH(NDI_SESSION_OBJ, SEARCHPARAMETERS)
			%
			% Given search parameters, which are a cell list {'PARAM1', VALUE1, 'PARAM2, VALUE2, ...},
			% the database associated with the NDI_SESSION object is searched.
			%
			% Matches are returned in a cell list NDI_DOCUMENT_OBJ.
			%
				ndi_document_obj = ndi_session_obj.database.search(searchparameters);
		end % database_search();

		function database_clear(ndi_session_obj, areyousure)
			% DATABASE_CLEAR - deletes/removes all entries from the database associated with an session
			%
			% DATABASE_CLEAR(NDI_SESSION_OBJ, AREYOUSURE)
			%
			%   Removes all documents from the NDI_SESSION_OBJ object.
			% 
			% Use with care. If AREYOUSURE is 'yes' then the
			% function will proceed. Otherwise, it will not.
			%
				ndi_session_obj.database.clear(areyousure);
		end; % database_clear()
        
		function ndi_binarydoc_obj = database_openbinarydoc(ndi_session_obj, ndi_document_or_id)
			% DATABASE_OPENBINARYDOC - open the NDI_BINARYDOC channel of an NDI_DOCUMENT
			%
			% NDI_BINARYDOC_OBJ = DATABASE_OPENBINARYDOC(NDI_SESSION_OBJ, NDI_DOCUMENT_OR_ID)
			%
			%   Return the open NDI_BINARYDOC object that corresponds to an NDI_DOCUMENT and
			%   NDI_DOCUMENT_OR_ID can be either the document id of an NDI_DOCUMENT or an NDI_DOCUMENT object itsef.
			% 
			%  Note that this NDI_BINARYDOC_OBJ must be closed and unlocked with NDI_SESSION/CLOSEBINARYDOC.
			%  The locked nature of the binary doc is a property of the database, not the document, which is why
			%  the database is needed in the method.
			% 
				ndi_binarydoc_obj = ndi_session_obj.database.openbinarydoc(ndi_document_or_id);
		end; % database_openbinarydoc

		function [ndi_binarydoc_obj] = database_closebinarydoc(ndi_session_obj, ndi_binarydoc_obj)
			% DATABASE_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC 
			%
			% [NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_DATABASE_OBJ, NDI_BINARYDOC_OBJ)
			%
			% Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be unlocked in the
			% database, which is why it is necessary to call this function through the session object.
			%
				ndi_binarydoc_obj = ndi_session_obj.database.closebinarydoc(ndi_binarydoc_obj);
		end; % closebinarydoc

		function ndi_session_obj = syncgraph_addrule(ndi_session_obj, rule)
			% SYNCGRAPH_ADDRULE - add an NDI_SYNCRULE to the syncgraph
			%
			% NDI_SESSION_OBJ = SYNCGRAPH_ADDRULE(NDI_SESSION_OBJ, RULE)
			%
			% Adds the NDI_SYNCRULE RULE to the NDI_SYNCGRAPH of the NDI_SESSION
			% object NDI_SESSION_OBJ. 
			%
				ndi_session_obj.syncgraph = ndi_session_obj.syncgraph.addrule(rule);
				update_syncgraph_in_db(ndi_session_obj);
		end; % syncgraph_addrule

		function ndi_session_obj = syncgraph_rmrule(ndi_session_obj, index)
			% SYNCGRAPH_RMRULE - remove an NDI_SYNCRULE from the syncgraph
			%
			% NDI_SESSION_OBJ = SYNCGRAPH_RMRULE(NDI_SESSION_OBJ, INDEX)
			%
			% Removes the INDEXth NDI_SYNCRULE from the NDI_SYNCGRAPH of the NDI_SESSION
			% object NDI_SESSION_OBJ. 
			%
				ndi_session_obj.syncgraph = ndi_session_obj.syncgraph.removerule(index);
				update_syncgraph_in_db(ndi_session_obj);
		end; % syncgraph_rmrule

		%%%%%% PATH methods

		function p = getpath(ndi_session_obj)
			% GETPATH - Return the path of the session
			%
			%   P = GETPATH(NDI_SESSION_OBJ)
			%
			% Returns the path of an NDI_SESSION object.
			%
			% The path is some sort of reference to the storage location of 
			% the session. This might be a URL, or a file directory, depending upon
			% the subclass.
			%
			% In the NDI_SESSION class, this returns empty.
			%
			% See also: NDI_SESSION
			p = [];
		end;

		%%%%%% REFERENCE methods

		function obj = findexpobj(ndi_session_obj, obj_name, obj_classname)
			% FINEXPDOBJ - search an NDI_SESSION for a specific object given name and classname
			%
			% OBJ = FINDEXPOBJ(NDI_EXPERIMNENT_OBJ, OBJ_NAME, OBJ_CLASSNAME)
			%
			% Examines the DAQSYSTEM list, DATABASE, and PROBELIST for an object with name OBJ_NAME 
			% and classname OBJ_CLASSNAME. If no object is found, OBJ will be empty ([]).
			%
				obj = [];

				trydaqsystem = 0;
				trydatabase = 0;
				tryprobelist = 0;

				if isa_text(obj_classname,'ndi_probe'),
					tryprobelist = 1;
				elseif isa(obj_classname,'ndi_daqsystem'),
					trydaqsystem = 1;
				else,
					trydatabase = 1;
				end;

				if trydaqsystem,
					obj_here = ndi_session_obj.daqsystem_load('name',obj_name);
					if ~isempty(obj_here),
						if strcmp(class(obj_here),obj_classname),
							% it is our match
							obj = obj_here;
							return;
						end;
					end;
				end

				if tryprobelist,
					probes = ndi_session_obj.getprobes();
					for i=1:numel(probes),
						if strcmp(class(probes{i}),obj_classname) & strcmp(probes{i}.epochsetname,obj_name),
							obj = probes{i}; 
							return;
						end;
					end;
				end

		end; % findexpobj

		function probes = getprobes(ndi_session_obj, varargin)
			% GETPROBES - Return all NDI_PROBES that are found in NDI_DAQSYSTEM epoch contents entries
			%
			% PROBES = GETPROBES(NDI_SESSION_OBJ, ...)
			%
			% Examines all NDI_DAQSYSTEM entries in the NDI_SESSION_OBJ's device array
			% and returns all NDI_PROBE entries that can be constructed from each device's
			% NDI_EPOCHPROBEMAP entries.
			%
			% PROBES is a cell array of NDI_PROBE objects.
			%
			% One can pass additional arguments that specify the classnames of the probes
			% that are returned:
			%
			% PROBES = GETPROBES(NDI_SESSION_OBJ, CLASSMATCH )
			%
			% only probes that are members of the classes CLASSMATCH etc., are
			% returned.
			%
			% PROBES = GETPROBES(NDI_SESSION_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
			%
			% returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
			% has a value of VALUE2, etc. Properties of probes are 'name', 'reference', and 'type'.
			%
			%
				probestruct = [];
				devs = ndi_session_obj.daqsystem_load('name','(.*)');
				if ~isempty(devs),
					probestruct = getprobes(celloritem(devs,1));
				end
				for d=2:numel(devs),
					probestruct = cat(1,probestruct,getprobes(devs{d}));
				end
				probestruct = equnique(probestruct);
				probes = ndi_probestruct2probe(probestruct, ndi_session_obj);

				if numel(varargin)==1,
					include = [];
					for i=1:numel(probes),
						includehere = isa(probes{i},varargin{1});
						if includehere,
							include(end+1) = i;
						end;
					end;
					probes = probes(include);
				elseif numel(varargin)>1,
					include = [];
					for i=1:numel(probes),
						includehere = 1; 
						fn = fieldnames(probes{i});
						for j=1:2:numel(varargin),
							includehere = includehere & ~isempty(intersect(fn,varargin{j}));
							if includehere,
								value = getfield(probes{i},varargin{j});
								if ischar(varargin{j+1}),
									includehere = strcmp(value,varargin{j+1});
								else,
									includehere = (value==varargin{j+1});
								end;
							end;
						end;
						if includehere,
							include(end+1) = i;
						end;
					end;
					probes = probes(include);
				end;
		end; % getprobes

		function elements = getelements(ndi_session_obj, varargin);
			% GETELEMENTS - Return all NDI_ELEMENT objects that are found in session database
			%
			% ELEMENTS = GETELEMENTS(NDI_SESSION_OBJ, ...)
			%
			% Examines all the database of NDI_SESSION_OBJ and returns all NDI_ELEMENT
			% entries.
			%
			% ELEMENTS is a cell array of NDI_PROBE objects.
			%
			% ELEMENTS = GETELEMENTS(NDI_SESSION_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
			%
			% returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
			% has a value of VALUE2, etc. Properties of elements are 'element.name', 'element.type',
			% 'element.direct', and 'probe.name', 'probe.type', and 'probe.reference'.
			% 
				q_E = ndi_query(ndi_session_obj.searchquery());
				q_t = ndi_query('ndi_document.type','exact_string','ndi_element','');
				for i=1:2:numel(varargin),
					q_t = q_t & ndi_query(varargin{i},'exact_string',varargin{i+1},'');
				end;
				doc = ndi_session_obj.database_search(q_E&q_t);
				elements = {};
				for i=1:numel(doc),
					elements{i} = ndi_document2ndi_object(doc{i}, ndi_session_obj);
				end;
		end; % getelements()

		function b = eq(e1,e2)
			% EQ - are 2 NDI_SESSIONS equal?
			% 
			% B = EQ(E1, E2)
			%
			% Returns 1 if and only if the sessions have the same unique reference number.
				if ~isa(e2,'ndi_session'),
					b = 0;
				else,
					b = strcmp(e1.id(), e2.id());
				end;
		end; % eq()

		function identifier = id(ndi_session_obj)
			% ID - return the unique identifier for this session
			%
			% IDENTIFIER = ID(NDI_SESSION_OBJ)
			%
			% Return the unique identifier for this session.
			%
				identifier = [ndi_session_obj.reference '_' ndi_session_obj.unique_reference];
		end; % id
	end; % methods

	methods (Access=protected)
		function b = update_syncgraph_in_db(ndi_session_obj)
			% UPDATE_SYNCGRAPH_IN_DB - remove and re-install NDI_SYNCGRAPH methods in an NDI_DATABASE
			%
			% B = UPDATE_SYNCGRAPH_IN_DB(NDI_SESSION_OBJ)
			%
			% Removes the NDI_SYNCGRAPH (and any SYNCRULE documents) from the database in
			% NDI_SESSION_OBJ and adds it back. Useful for updating the SYNCGRAPH when
			% SYNCRULEs are added or removed.

				b = 1;

				[syncgraph_doc,syncrule_doc] = ndi_syncgraph.load_all_syncgraph_docs(ndi_session_obj, ...
					ndi_session_obj.syncgraph.id());

				newdocs = ndi_session_obj.syncgraph.newdocument(); % generate new documents

				% now, delete old docs and add new ones

				gooddelete = 0;
				try,
					ndi_session_obj.database_rm(syncgraph_doc);
					ndi_session_obj.database_rm(syncrule_doc);
					gooddelete = 1;
				end;
				% now add new docs
				ndi_session_obj.database_add(newdocs);

				if ~gooddelete,
					error(['Could not delete old syncgraph; new syncgraph has been added to the database.']);
				end;
		end; % update_syncgraph_in_db()
	end; % methods (Protected)
	
end % classdef

