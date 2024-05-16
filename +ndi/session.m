classdef session < handle % & ndi.documentservice & % ndi.ido Matlab does not allow these subclasses because they are not handle
	% NDI.SESSION - NDI.SESSION object class

	properties (GetAccess=public, SetAccess = protected)
		reference         % A string reference for the session
		identifier        % A unique identifier
		syncgraph         % An ndi.time.syncgraph object related to this session
		cache             % An ndi.cache object for the session's use
	end
	properties (GetAccess=protected, SetAccess = protected)
		database          % An ndi.database associated with this session
	end
	methods
		function ndi_session_obj = session(reference)
			% ndi.session - Create a new ndi.session object
			%
			%   NDI_SESSION_OBJ=ndi.session(REFERENCE)
			%
			% Creates a new ndi.session object. The session has a unique
			% reference REFERENCE. This class is an abstract class and typically
			% an end user will open a specific subclass such as ndi.session.dir.
			%
			% ndi.session objects can access 0 or more ndi.daq.system objects.
			%
			% See also: ndi.session/DAQSYSTEM_ADD, ndi.session/DAQSYSTEM_RM, 
			%   ndi.session/GETPATH, ndi.session/GETREFERENCE

				ndi_session_obj.reference = reference;
				ndi_session_obj.database = [];
				ndiido = ndi.ido();
				ndi_session_obj.identifier = ndiido.id();
				ndi_session_obj.syncgraph = ndi.time.syncgraph(ndi_session_obj);
				ndi_session_obj.cache = ndi.cache();
		end

		function identifier = id(ndi_session_obj)
			% ID - return the identifier of an ndi.session object
			%
			% IDENTIFIER = ID(NDI_SESSION_OBJ)
			%
			% Returns the unique identifier of an ndi.session object.
			%
				identifier = ndi_session_obj.identifier;
		end; % id()


		%%%%%% REFERENCE METHODS
	
		function refstr = unique_reference_string(ndi_session_obj)
			% UNIQUE_REFERENCE_STRING - return the unique reference string for this session
			%
			% REFSTR = UNIQUE_REFERENCE_STRING(NDI_SESSION_OBJ)
			%
			% Returns the unique reference string for the ndi.session.
			% REFSTR is a combination of the REFERENCE property of NDI_SESSION_OBJ
			% and the UNIQUE_REFERENCE property of NDI_SESSION_OBJ, joined with a '_'.
			%
			% If you just want the reference (not unique) just access the reference
			% property (NDI_SESSION_OBJ.reference).
			%
				warning('unique_reference_string depricated, use id() instead.');
				dbstack
				refstr = [ndi_session_obj.reference '_' ndi_session_obj.identifier];
		end % unique_reference_string()

		%%%%%% DEVICE METHODS

		function ndi_session_obj = daqsystem_add(ndi_session_obj, dev)
			%DAQSYSTEM_ADD - Add a sampling device to a ndi.session object
			%
			%   NDI_SESSION_OBJ = DAQSYSTEM_ADD(NDI_SESSION_OBJ, DEV)
			%
			% Adds the device DEV to the ndi.session NDI_SESSION_OBJ
			%
			% The devices can be accessed by referencing NDI_SESSION_OBJ.device
			%  
			% See also: DAQSYSTEM_RM, ndi.session

				if ~isa(dev,'ndi.daq.system'),
					error(['dev is not a ndi.daq.system']);
				end;
				% search if the daqsystem_obj already exists in the database(based on daqsystem name and session_id)
               			 % if so, pass; otherwise, create a new document from this daqsystem_obj and add it to the database

				% make sure this daqsystem matches our session
				dev = dev.setsession(ndi_session_obj);
                
				sq = dev.searchquery();
				search_result = ndi_session_obj.database_search(sq);
				sq1 = ndi.query('','isa','daqsystem','') & ...
					ndi.query('base.name','exact_string',dev.name,'');
				search_result1 = ndi_session_obj.database_search(sq1);
				if (numel(search_result) == 0) & (numel(search_result1) == 0)
					% no match was found, can add to the database
					doc_set = dev.newdocument();
					ndi_session_obj.database_add(doc_set);
				else,
					error(['dev or dev with same name already exists in the database.']);    
				end
		end;

		function ndi_session_obj = daqsystem_rm(ndi_session_obj, dev)
			% DAQSYSTEM_RM - Remove a sampling device from an ndi.session object
			%
			% NDI_SESSION_OBJ = DAQSYSTEM_RM(NDI_SESSION_OBJ, DEV)
			%
			% Removes the device DEV from the device list.
			%
			% See also: DAQSYSTEM_ADD, ndi.session
            
				if ~isa(dev,'ndi.daq.system')
					error(['dev is not a ndi.daq.system']);
				end;
				daqsys = ndi_session_obj.daqsystem_load('name',dev.name);
				if ~isempty(daqsys) 
					if ~iscell(daqsys),
						daqsys = {daqsys};
					end;
					docs = ndi_session_obj.database_search(daqsys{1}.searchquery());
					for k=1:numel(docs), % should be 1 only, but keep deleting even if not
						for i=1:numel(docs{k}.document_properties.depends_on),
							dochere = ndi_session_obj.database_search(...
								ndi.query('base.id', 'exact_string', docs{k}.document_properties.depends_on(i).value, ''));
							ndi_session_obj.database_rm(dochere);
						end;
						ndi_session_obj.database_rm(docs); % database_rm can process single or a cell list of ndi_document_obj(s)
					end;
				else
					error(['No daqsystem named ' dev.name ' found.']);
				end;
		end; % daqsystem_rm()

		function dev = daqsystem_load(ndi_session_obj, varargin)
			% DAQSYSTEM_LOAD - Load daqsystem objects from an ndi.session
			%
			% DEV = DAQSYSTEM_LOAD(NDI_SESSION_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% DEV = DAQSYSTEM_LOAD(NDI_SESSION_OBJ)
			%
			% Returns the ndi.daq.system objects in the ndi.session with metadata parameters PARAMS1 that matches
			% VALUE1, PARAMS2 that matches VALUE2, etc.
			%
			% One can also search for 'name' as a parameter; this will be automatically changed to search
			% for database documents with fields 'base.name' equal to the corresponding value.
			%
			% If more than one object is requested, then DEV will be a cell list of matching objects.
			% Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
			%
				dev = {};
				q1 = ndi.query('','isa','daqsystem','');
				q2 = ndi.query('base.session_id','exact_string',ndi_session_obj.id(),'');
				q = q1 & q2;
				if numel(varargin)>0,
					for i=1:2:numel(varargin),
						if strcmpi(varargin{i},'name'),
							varargin{i} = 'base.name'; % case matters here
						end;
					end;
					q = q & ndi.query(varargin);
				end;
				dev_doc = ndi_session_obj.database_search(q);
				% dev is cell list of ndi.document objects
				for i=1:numel(dev_doc),
					dev{i} = ndi.database.fun.ndi_document2ndi_object(dev_doc{i},ndi_session_obj);
				end;
				
				if numel(dev)==1,
					dev = dev{1};
				end;
		end; % daqsystem_load()	

		function ndi_session_obj = daqsystem_clear(ndi_session_obj)
			% DAQSYSTEM_CLEAR - remove all DAQSYSTEM objects from an ndi.session
			%
			% NDI_SESSION_OBJ = DAQSYSTEM_CLEAR(NDI_SESSION_OBJ)
			%
			% Permanently removes all ndi.daq.system objects from an ndi.session.
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

		% ndi.documentservice methods

		function ndi_document_obj = newdocument(ndi_session_obj, document_type, varargin)
			% NEWDOCUMENT - create a new ndi.database document of type ndi.document
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SESSION_OBJ, [DOCUMENT_TYPE], 'PROPERTY1', VALUE1, ...)
			%
			% Creates an empty database document NDI_DOCUMENT_OBJ. DOCUMENT_TYPE is
			% an optional argument and can be any type that confirms to the .json
			% files in $NDI_COMMON/database_documents/*, a URL to such a file, or
			% a full path filename. If DOCUMENT_TYPE is not specified, it is taken
			% to be 'base.json'.
			%
			% If additional PROPERTY values are specified, they are set to the VALUES indicated.
			%
			% Example: mydoc = ndi_session_obj.newdocument('base','base.name','myname');
			%
				if nargin<2,
					document_type = 'base.json';
				end
				inputs = cat(2,varargin,{'base.session_id', ndi_session_obj.id()});
				ndi_document_obj = ndi.document(document_type, inputs);
		end; %newdocument()

		function sq = searchquery(ndi_session_obj)
			% SEARCHQUERY - return a search query for database objects in this session
			%
			% SQ = SEARCHQUERY(NDI_SESSION_OBJ)
			%
			% Returns a search query that will match all ndi.document objects that were generated
			% by this session.
			%
			% SQ = {'base.session_id', ndi_session_obj.id()};
			% 
			% Example: mydoc = ndi_session_obj.newdocument('base','base.name','myname');
			%
				sq = {'base.session_id', ndi_session_obj.id()};
		end; %searchquery()

		% ndi.database / ndi.document methods

		function ndi_session_obj = database_add(ndi_session_obj, document)
			%DATABASE_ADD - Add an ndi.document to an ndi.session object
			%
			% NDI_SESSION_OBJ = DATABASE_ADD(NDI_SESSION_OBJ, NDI_DOCUMENT_OBJ)
			%
			% Adds the ndi.document NDI_DOCUMENT_OBJ to the ndi.session NDI_SESSION_OBJ.
			% NDI_DOCUMENT_OBJ can also be a cell array of ndi.document objects, which will all be added
			% in turn.
			% 
			% The database can be queried by calling NDI_SESSION_OBJ/SEARCH
			%  
			% See also: DATABASE_RM, ndi.session, ndi.database, ndi.session/SEARCH

					% dev note: we should make this so it calls the database with a list of docs to
					% add instead of one at a time

				if iscell(document),
					for i=1:numel(document),
						ndi_session_obj.database_add(document{i});
					end;
					return;
				end;
				if ~isa(document,'ndi.document'),
					error(['document is not an ndi.document']);
				end;

				session_id_here = document.document_properties.base.session_id;
				if ~strcmp(session_id_here,ndi_session_obj.id()),
					if strcmp(session_id_here,ndi.session.empty_id), % ok, set it to our id
						document = document.set_session_id(ndi_session_obj.id());
					else, 
						error(['ndi.document with id ' document.document_properties.base.id ...
							' has session_id ' session_id_here ' that does not match session''s id ' ...
							ndi_session_obj.id()]);
					end;
				end;
				ndi_session_obj.database.add(document);
		end; % database_add()

		function ndi_session_obj = database_rm(ndi_session_obj, doc_unique_id, varargin)
			% DATABASE_RM - Remove an ndi.document with a given document ID from an ndi.session object
			%
			% NDI_SESSION_OBJ = DATABASE_RM(NDI_SESSION_OBJ, DOC_UNIQUE_ID)
			%   or
			% NDI_SESSION_OBJ = DATABASE_RM(NDI_SESSION_OBJ, DOC)
			%
			% Removes an ndi.document with document id DOC_UNIQUE_ID from the
			% NDI_SESSION_OBJ.database. In the second form, if an ndi.document or cell array of
			% NDI_DOCUMENTS is passed for DOC, then the document unique ids are retrieved and they
			% are removed in turn.  If DOC/DOC_UNIQUE_ID is empty, no action is taken.
			%
			% This function also takes parameters as name/value pairs that modify its behavior:
			% Parameter (default)        | Description
			% --------------------------------------------------------------------------------
			% ErrIfNotFound (0)          | Produce an error if an ID to be deleted is not found.
			%
			% See also: DATABASE_ADD, ndi.session
				ErrIfNotFound = 0;
				vlt.data.assign(varargin{:});

				if isempty(doc_unique_id),
					return;
				end; % nothing to do

				doc_list = ndi.session.docinput2docs(ndi_session_obj, doc_unique_id);
				[b,errmsg] = ndi_session_obj.validate_documents(doc_list);
				if ~b,
					error(errmsg);
				end;

				if iscell(doc_list),
					dependent_docs = ndi.database.fun.findalldependencies(ndi_session_obj,[],doc_list{:});
					if numel(dependent_docs)>1,
						warning(['Also deleting ' int2str(numel(dependent_docs)) ' dependent docs.']);
					end;
					for i=1:numel(dependent_docs),
						ndi_session_obj.database.remove(dependent_docs{i});
					end;
					for i=1:numel(doc_list), 
						ndi_session_obj.database.remove(doc_list);
					end;
				else,
					error(['Did not think we could get here..notify steve.']);
				end;
		end; % database_rm

		function ndi_document_obj = database_search(ndi_session_obj, searchparameters)
			% DATABASE_SEARCH - Search for an ndi.document in a database of an ndi.session object
			%
			% NDI_DOCUMENT_OBJ = DATABASE_SEARCH(NDI_SESSION_OBJ, SEARCHPARAMETERS)
			%
			% Given search parameters, which are a cell list {'PARAM1', VALUE1, 'PARAM2, VALUE2, ...},
			% the database associated with the ndi.session object is searched.
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

       	function [b,errmsg] = validate_documents(ndi_session_obj, document)
			% VALIDATE_DOCUMENTS - validate whether documents belong to a session
			%   
			% [B, ERRMSG] = VALIDATE_DOCUMENTS(NDI_SESSION_OBJ, DOCUMENT)
			%
			% Given an ndi.document DOCUMENT or a cell array of ndi.documents DOCUMENT,
			% determines whether all document session_ids match the sessions's id. 
			% An 'empty' session_id (all 0s, ndi.session.empty_id() ) also matches.
			%
		
				b = 1;
				errmsg = '';
				if ~iscell(document),
					document = {document};
				end;
				for i=1:numel(document),
					b = b & isa(document{i},'ndi.document');
					if ~b,
						errmsg = ['All entries of DOCUMENT must be ndi.document objects.'];
						break;
					end;
					session_id_here = document{i}.document_properties.base.session_id;
					b_ = strcmp(session_id_here,ndi_session_obj.id());
					if ~b_,
						b_= strcmp(document{i}.document_properties.base.session_id,ndi.session.empty_id());
					end;
					b = b & b_;
					if ~b,
						errmsg = ['All documents associated with the session) must have a session_id equal to the session id (document ' int2str(i) ' does not match and has session_id '  ').'];
						ndi_session_obj.id(),
						document{i}.document_properties.base.session_id,
						break;
					end;
				end;
		end; % validate_documents()

		function ndi_binarydoc_obj = database_openbinarydoc(ndi_session_obj, ndi_document_or_id, filename)
			% DATABASE_OPENBINARYDOC - open the ndi.database.binarydoc channel of an ndi.document
			%
			% NDI_BINARYDOC_OBJ = DATABASE_OPENBINARYDOC(NDI_SESSION_OBJ, NDI_DOCUMENT_OR_ID, FILENAME)
			%
			%  Return the open ndi.database.binarydoc object that corresponds to an ndi.document and
			%  NDI_DOCUMENT_OR_ID can be either the document id of an ndi.document or an ndi.document object itself.
			%  The document is opened for reading only. Document binary streams may not be edited once the
			%  document is added to the database.
			% 
			%  Note that this NDI_BINARYDOC_OBJ must be closed with ndi.session/CLOSEBINARYDOC.
			% 
				ndi_binarydoc_obj = ndi_session_obj.database.openbinarydoc(ndi_document_or_id, filename);
		end; % database_openbinarydoc

        function [tf, file_path] = database_existbinarydoc(ndi_session_obj, ndi_document_or_id, filename)
			% DATABASE_EXISTBINARYDOC - checks if an ndi.database.binarydoc exists for an ndi.document
			%
			% [TF, FILE_PATH] = DATABASE_EXISTBINARYDOC(NDI_SESSION_OBJ, NDI_DOCUMENT_OR_ID, FILENAME)
			%
			%  Return a boolean flag (TF) indicating if a binary document 
            %  exists for an ndi.document and, if it exists, the full file 
            %  path (FILE_PATH) to the file where the binary data is stored.

		    [tf, file_path] = ndi_session_obj.database.existbinarydoc(ndi_document_or_id, filename);
        end % database_existbinarydoc

		function [ndi_binarydoc_obj] = database_closebinarydoc(ndi_session_obj, ndi_binarydoc_obj)
			% DATABASE_CLOSEBINARYDOC - close an ndi.database.binarydoc 
			%
			% [NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_SESSION_OBJ, NDI_BINARYDOC_OBJ)
			%
			% Close an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be closed in the
			% database, which is why it is necessary to call this function through the session object.
			%
				ndi_binarydoc_obj = ndi_session_obj.database.closebinarydoc(ndi_binarydoc_obj);
		end; % closebinarydoc

		function ndi_session_obj = syncgraph_addrule(ndi_session_obj, rule)
			% SYNCGRAPH_ADDRULE - add an ndi.time.syncrule to the syncgraph
			%
			% NDI_SESSION_OBJ = SYNCGRAPH_ADDRULE(NDI_SESSION_OBJ, RULE)
			%
			% Adds the ndi.time.syncrule RULE to the ndi.time.syncgraph of the ndi.session
			% object NDI_SESSION_OBJ. 
			%
				ndi_session_obj.syncgraph = ndi_session_obj.syncgraph.addrule(rule);
				ndi_session_obj.syncgraph = update_syncgraph_in_db(ndi_session_obj);
		end; % syncgraph_addrule

		function ndi_session_obj = syncgraph_rmrule(ndi_session_obj, index)
			% SYNCGRAPH_RMRULE - remove an ndi.time.syncrule from the syncgraph
			%
			% NDI_SESSION_OBJ = SYNCGRAPH_RMRULE(NDI_SESSION_OBJ, INDEX)
			%
			% Removes the INDEXth ndi.time.syncrule from the ndi.time.syncgraph of the ndi.session
			% object NDI_SESSION_OBJ. 
			%
				ndi_session_obj.syncgraph = ndi_session_obj.syncgraph.removerule(index);
				ndi_session_obj.syncgraph = update_syncgraph_in_db(ndi_session_obj);
		end; % syncgraph_rmrule

		function [b,errmsg] = ingest(ndi_session_obj)
			% INGEST - ingest the raw data and synchronization information into the database
			%
			% [B,ERRMSG] = INGEST(NDI_SESSION_OBJ)
			%
			% Ingest all raw data and synchronization information into the database.
			%
				d_syncgraph = ndi_session_obj.syncgraph.ingest();
				errmsg = '';

				daqs = ndi_session_obj.daqsystem_load('name','(.*)');
                if ~iscell(daqs), 
                    daqs = {daqs};
                end;
				daq_d = {};
				b = 1;
				for i=1:numel(daqs),
					[b_here,daq_d{i}] = daqs{i}.ingest();
					b = b & b_here;
					if ~b,
						errmsg = ['Error in daq ' daqs{i}.name];
					end;
				end;
				if b==0, % things didn't go well, bail
					for i=1:numel(daqs),
						ndi_session_obj.database_rm(daq_d{i});
					end;
				else, % add the syncgraph documents and we are done
					ndi_session_obj.database_add(d_syncgraph);
				end;
		end; % ingest()

		function d = get_ingested_docs(ndi_session_obj)
			% GET_INGESTED_DOCS - get all ndi.documents related to ingested data
			%
			% D = GET_INGESTED_DOCS(NDI_SESSION_OBJ)
			%
			% Return all documents related to ingested data. Be careful; if the raw data
			% is not available on the path, then the ingested data is the only record of it.
			%
				q_i1 = ndi.query('','isa','daqreader_mfdaq_epochdata_ingested');
				q_i2 = ndi.query('','isa','daqmetadatareader_epochdata_ingested');
				q_i3 = ndi.query('','isa','epochfiles_ingested');
				q_i4 = ndi.query('','isa','syncrule_mapping');

				d = ndi_session_obj.database_search(q_i1 | q_i2 | q_i3 | q_i4);

		end; % get_ingested_docs

		function b = is_fully_ingested(ndi_session_obj)
			% IS_FULLY_INGESTED - is an ndi.session object fully ingested?
			%
			% B = IS_FULLY_INGESTED(NDI_SESSION_OBJ)
			%
			% Returns 1 if the ndi.session object NDI_SESSION_OBJ is fully
			% ingested and 0 if there are still elements on disk that would
			% need to be ingested by NDI_SESSION_OBJ.ingest() in order to 
			% be fully ingested.

					% as a proxy, we will see if there any file navigators that remain to be ingested
					% this performs no ingestion on its own

				daqs = ndi_session_obj.daqsystem_load('name','(.*)');
                if ~iscell(daqs),
                    daqs = {daqs};
                end;
				daq_d = {};
				b = 1;
				for i=1:numel(daqs),
					[docs_out] = daqs{i}.filenavigator.ingest();
					if ~isempty(docs_out),
						b = 0; 
						return;
					end;
				end;
		end; % is_fully_ingested

		%%%%%% PATH methods

		function p = getpath(ndi_session_obj)
			% GETPATH - Return the path of the session
			%
			%   P = GETPATH(NDI_SESSION_OBJ)
			%
			% Returns the path of an ndi.session object.
			%
			% The path is some sort of reference to the storage location of 
			% the session. This might be a URL, or a file directory, depending upon
			% the subclass.
			%
			% In the ndi.session class, this returns empty.
			%
			% See also: ndi.session
			p = [];
		end;

		%%%%%% REFERENCE methods

		function obj = findexpobj(ndi_session_obj, obj_name, obj_classname)
			% FINEXPDOBJ - search an ndi.session for a specific object given name and classname
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

				if vlt.matlab.isa_text(obj_classname,'ndi.probe'),
					tryprobelist = 1;
				elseif isa(obj_classname,'ndi.daq.system'),
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
			% GETPROBES - Return all NDI_PROBES that are found in ndi.daq.system epoch contents entries
			%
			% PROBES = GETPROBES(NDI_SESSION_OBJ, ...)
			%
			% Examines all ndi.daq.system entries in the NDI_SESSION_OBJ's device array
			% and returns all ndi.probe.* entries that can be constructed from each device's
			% ndi.epoch.epochprobemap entries.
			%
			% PROBES is a cell array of ndi.probe.* objects.
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
			% has a value of VALUE2, etc. Properties of probes are 'name', 'reference', and 'type', and 'subject_ID'.
			%
			%
				probestruct = [];
				devs = ndi_session_obj.daqsystem_load('name','(.*)');
				if ~isempty(devs),
					probestruct = getprobes(vlt.data.celloritem(devs,1));
				end
				for d=2:numel(devs),
					probestruct = cat(1,probestruct,getprobes(devs{d}));
				end
				probestruct = vlt.data.equnique(probestruct);
				probes = ndi.probe.fun.probestruct2probe(probestruct, ndi_session_obj);

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
			% GETELEMENTS - Return all ndi.element objects that are found in session database
			%
			% ELEMENTS = GETELEMENTS(NDI_SESSION_OBJ, ...)
			%
			% Examines all the database of NDI_SESSION_OBJ and returns all ndi.element
			% entries.
			%
			% ELEMENTS is a cell array of ndi.element.* objects.
			%
			% ELEMENTS = GETELEMENTS(NDI_SESSION_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
			%
			% returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
			% has a value of VALUE2, etc. Properties of elements are 'element.name', 'element.type',
			% 'element.direct', and 'probe.name', 'probe.type', and 'probe.reference'.
			% 
				q_E = ndi.query(ndi_session_obj.searchquery());
				q_t = ndi.query('','isa','element',''); 
				for i=1:2:numel(varargin),
					if strfind(varargin{i},'reference'),
						q_t = q_t & ndi.query(varargin{i},'exact_number',varargin{i+1},'');
					else,
						q_t = q_t & ndi.query(varargin{i},'exact_string',varargin{i+1},'');
					end;
				end;
				doc = ndi_session_obj.database_search(q_E&q_t);
				elements = {};
				for i=1:numel(doc),
					elements{i} = ndi.database.fun.ndi_document2ndi_object(doc{i}, ndi_session_obj);
				end;
		end; % getelements()

		function b = eq(e1,e2)
			% EQ - are 2 NDI_SESSIONS equal?
			% 
			% B = EQ(E1, E2)
			%
			% Returns 1 if and only if the sessions have the same unique reference number.
				if ~isa(e2,'ndi.session'),
					b = 0;
				else,
					b = strcmp(e1.id(), e2.id());
				end;
		end; % eq()

		function inputs = creator_args(ndi_session_obj)
			% CREATOR_ARGS - return the arguments needed to build an ndi.session object
			%
			% INPUTS = CREATOR_ARGS(NDI_SESSION_OBJ)
			%
			% Return the inputs necessary to create an ndi.session object. Each input
			% argument is returned as an entry in the cell array INPUTS.
			% 
			% Example:
			% INPUTS = ndi_session_obj.creator_args();
			% ndi_session_copy = ndi.session(INPUTS{:});
			%
			
				inputs{1} = ndi_session_obj.reference();
		end; % creator_args()

	end; % methods

    methods (Hidden)
        function [hCleanup, filename] = open_database(ndi_session_obj)
	        [hCleanup, filename] = ndi_session_obj.database.open();
        end
    end

	methods (Access=protected)
		function syncgraph = update_syncgraph_in_db(ndi_session_obj)
			% UPDATE_SYNCGRAPH_IN_DB - remove and re-install ndi.time.syncgraph methods in an ndi.database
			%
			% B = UPDATE_SYNCGRAPH_IN_DB(NDI_SESSION_OBJ)
			%
			% Removes the ndi.time.syncgraph (and any SYNCRULE documents) from the database in
			% NDI_SESSION_OBJ and adds it back. Useful for updating the SYNCGRAPH when
			% SYNCRULEs are added or removed.

				b = 1;

				[syncgraph_doc,syncrule_doc] = ndi.time.syncgraph.load_all_syncgraph_docs(ndi_session_obj, ...
					ndi_session_obj.syncgraph.id());

				newsyncgraph = ndi.time.syncgraph(ndi_session_obj);
				for i=1:numel(ndi_session_obj.syncgraph.rules),
					newsyncgraph = newsyncgraph.addrule(ndi_session_obj.syncgraph.rules{i});
				end;

				syncgraph = newsyncgraph;
				ndi_session_obj.syncgraph = syncgraph;

				newdocs = ndi_session_obj.syncgraph.newdocument(); % generate new documents

				% now, delete old docs and add new ones

				gooddelete = 0;
				if ~isempty(syncgraph_doc),
					ndi_session_obj.database_rm(syncgraph_doc);
				end;
				if ~isempty(syncrule_doc),
					ndi_session_obj.database_rm(syncrule_doc);
				end;
				gooddelete = 1;

				% now add new docs
				ndi_session_obj.database_add(newdocs);

				if ~gooddelete,
					error(['Could not delete old syncgraph; new syncgraph has been added to the database.']);
				end;
		end; % update_syncgraph_in_db()

	end; % methods (Protected)

	methods Static % regular static methods

		function doc_list = ndi.session.docinput2docs(ndi_session_obj, doc_input)
			% DOCINPUT2DOCS - convert an array of ndi.documents or doc_ids to documents
			%
			% [DOC_LIST,B,ERRMSG] = DOCINPUT2DOCS(NDI_SESSION_OBJ, DOC_INPUT)
			%
			% Given an input DOC_INPUT that specifies ndi.document objects,
			% return the list of ndi.document objects.
			%
			% DOC_INPUT can be a single document id (character array), or a single
			% ndi.document, or a cell array of document ids or a cell array of ndi.documents,
			% or a mixed cell array of ndi.document objects and ids.
			%
			% If all documents are found, then B is 1 and ERRMSG is ''. If a document ID
			% does not exist in the database, then one occurence is noted in ERRMSG and B is 0.
			% 
				doc_list = {};
				b = 1;

				if ~iscell(doc_input),
					doc_input = {doc_input};
				end;
				q = [];
				for i=1:numel(doc_input),
					if ~isa(doc_input{i},'ndi.document'),
						if isempty(q),
							q = ndi.query('base.id','exact_string',doc_input{i});
						else,
							q = q | ndi.query('base.id','exact_string',doc_input{i});
						end;
					end;
				end;
				docs_to_fetch = {};
				if ~isempty(q),
					docs_to_fetch = ndi_session_obj.database_search(q);
				end;
				include = [];
				for i=1:numel(doc_input),
					if isa(doc_input{i},'ndi.document'),
						doc_list{i} = doc_input{i};
					else,
						doc_list{i} = [];
						for k=1:numel(docs_to_fetch),
							if strcmp(docs_to_fetch{k}.document_properties.base.id,...
								doc_input{i}),
								doc_list{i} = docs_to_fetch{k};
								break;
							end;
						end;
					end;
					if ~isa(doc_list{i},'ndi.document'),
						b = 0;
						errmsg = ['Unable to locate document ' doc_input{i} '.'];
					else,
						include(end+1) = i;
					end;
				end;
				doc_list = doc_list(include);
		end; %docinput2docs()

		function [b,errmsg] = all_docs_in_session(docs, session_id)
			% ALL_DOCS_IN_SESSION - determines if a set of ndi documents are in a session
			%
			% [B,ERRMSG] = ALL_DOCS_IN_SESSION(DOCS, SESSION_ID)
			%
			% B is 1 if the base.session_id field of all ndi.document objects in the cell
			% array DOCS match session_id. If so, ERRMSG is empty. Otherwise, ERRMSG lists
			% the documents that are not in the session.
			%
				b = zeros(numel(docs),1);
				errmsg = ['The following documents are not in session_id ' session_id ': '];
				for i=1:numel(docs),
					session_id_here = docs{i}.document_properties.base.session_id;
					b(i) = strcmp(session_id,session_id_here);
					if ~b(i),
						errmsg = cat(2,errmsg,[session_id_here ', ']);
					end;
				end;
				if any(b),
					errmsg = errmsg(1:end-2); % trim last ', '
					errmsg(end+1) = '.';
					b = 1; % make it a scalar
				else,
					b = 0; % make it a scalar
				end;

		end; % all_docs_in_session

	end; % methods Static
	
end % classdef

