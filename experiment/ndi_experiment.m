classdef ndi_experiment < handle
	% NDI_EXPERIMENT - NDI_EXPERIMENT object class

	properties (GetAccess=public, SetAccess = protected)
		reference         % A string reference for the experiment
		unique_reference  % A unique code that uniquely identifies this experiment
		daqsystem          % An array of NDI_DAQSYSTEM objects associated with this experiment
		syncgraph         % An NDI_SYNCGRAPH object related to this experiment
		cache             % An NDI_CACHE object for the experiment's use
	end
	properties (GetAccess=protected, SetAccess = protected)
		database          % An NDI_DATABASE associated with this experiment
	end
	methods
		function ndi_experiment_obj = ndi_experiment(reference)
			% ndi_experiment - Create a new NDI_EXPERIMENT object
			%
			%   NDI_EXPERIMENT_OBJ=NDI_EXPERIMENT(REFERENCE)
			%
			% Creates a new NDI_EXPERIMENT object. The experiment has a unique
			% reference REFERENCE. This class is an abstract class and typically
			% an end user will open a specific subclass such as NDI_EXPERIMENT_DIR.
			%
			% NDI_EXPERIMENT objects can access 0 or more NDI_DAQSYSTEM objects.
			%
			% See also: NDI_EXPERIMENT/DAQSYSTEM_ADD, NDI_EXPERIMENT/DAQSYSTEM_RM, 
			%   NDI_EXPERIMENT/GETPATH, NDI_EXPERIMENT/GETREFERENCE

				ndi_experiment_obj.reference = reference;
				ndi_experiment_obj.unique_reference = ndi_unique_id;
				ndi_experiment_obj.daqsystem = ndi_dbleaf_branch('','device',{'ndi_daqsystem'},1);
				ndi_experiment_obj.database = [];
				ndi_experiment_obj.syncgraph = ndi_syncgraph(ndi_experiment_obj);
				ndi_experiment_obj.cache = ndi_cache();
		end

		%%%%%% REFERENCE METHODS
	
		function refstr = unique_reference_string(ndi_experiment_obj)
			% UNIQUE_REFERENCE_STRING - return the unique reference string for this experiment
			%
			% REFSTR = UNIQUE_REFERENCE_STRING(NDI_EXPERIMENT_OBJ)
			%
			% Returns the unique reference string for the NDI_EXPERIMENT.
			% REFSTR is a combination of the REFERENCE property of NDI_EXPERIMENT_OBJ
			% and the UNIQUE_REFERENCE property of NDI_EXPERIMENT_OBJ, joined with a '_'.
				warning('unique_reference_string depricated, use id() instead.');
				dbstack
				refstr = [ndi_experiment_obj.reference '_' ndi_experiment_obj.unique_reference];
		end % unique_reference_string()

		%%%%%% DEVICE METHODS

		function ndi_experiment_obj = daqsystem_add(ndi_experiment_obj, dev)
			%DAQSYSTEM_ADD - Add a sampling device to a NDI_EXPERIMENT object
			%
			%   NDI_EXPERIMENT_OBJ = DAQSYSTEM_ADD(NDI_EXPERIMENT_OBJ, DEV)
			%
			% Adds the device DEV to the NDI_EXPERIMENT NDI_EXPERIMENT_OBJ
			%
			% The devices can be accessed by referencing NDI_EXPERIMENT_OBJ.device
			%  
			% See also: DAQSYSTEM_RM, NDI_EXPERIMENT

				if ~isa(dev,'ndi_daqsystem'),
					error(['dev is not a ndi_daqsystem']);
				end;
				ndi_experiment_obj.daqsystem.add(dev);
		end;

		function ndi_experiment_obj = daqsystem_rm(ndi_experiment_obj, dev)
			% DAQSYSTEM_RM - Remove a sampling device from an NDI_EXPERIMENT object
			%
			%   NDI_EXPERIMENT_OBJ = DAQSYSTEM_RM(NDI_EXPERIMENT_OBJ, DEV)
			%
			% Removes the device DEV from the device list.
			%
			% See also: DAQSYSTEM_ADD, NDI_EXPERIMENT
			
				leaf = ndi_experiment_obj.daqsystem.load('name',dev.name);
				if ~isempty(leaf),
					ndi_experiment_obj.daqsystem.remove(leaf.objectfilename);
				else,
					error(['No daqsystem named ' dev.name ' found.']);
				end;
		end;

		function dev = daqsystem_load(ndi_experiment_obj, varargin)
			% DAQSYSTEM_LOAD - Load daqsystem objects from an NDI_EXPERIMENT
			%
			% DEV = DAQSYSTEM_LOAD(NDI_EXPERIMENT_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% DEV = DAQSYSTEM_LOAD(NDI_EXPERIMENT_OBJ, INDEXES)
			%
			% Returns the device object(s) in the NDI_EXPERIMENT at index(es) INDEXES or
			% searches for an object whose metadata parameters PARAMS1, PARAMS2, and so on, match
			% VALUE1, VALUE2, and so on (see NDI_DBLEAF_BRANCH/SEARCH).
			%
			% If more than one object is requested, then DEV will be a cell list of matching objects.
			% Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
			%
				dev = ndi_experiment_obj.daqsystem.load(varargin{:});
				if numel(dev)==1,
					dev=dev.setexperiment(ndi_experiment_obj);
				else,
					for i=1:numel(dev),
						dev{i}=dev{i}.setexperiment(ndi_experiment_obj);
					end;
				end;
		end; % daqsystem_load()	

		function ndi_experiment_obj = daqsystem_clear(ndi_experiment_obj)
			% DAQSYSTEM_CLEAR - remove all DAQSYSTEM objects from an NDI_EXPERIMENT
			%
			% NDI_EXPERIMENT_OBJ = DAQSYSTEM_CLEAR(NDI_EXPERIMENT_OBJ)
			%
			% Permanently removes all NDI_DAQSYSTEM objects from an NDI_EXPERIMENT.
			%
			% Be sure you mean it!
			%
				dev = ndi_experiment_obj.daqsystem_load('name','(.*)');
				if ~isempty(dev) & ~iscell(dev),
					dev = {dev};
				end;
				for i=1:numel(dev),
					ndi_experiment_obj = ndi_experiment_obj.daqsystem_rm(dev{i});
				end;

		end; % daqsystem_clear();

		% NDI_DOCUMENTSERVICE methods

		function ndi_document_obj = newdocument(ndi_experiment_obj, document_type, varargin)
		% NEWDOCUMENT - create a new NDI_DATABASE document of type NDI_DOCUMENT
		%
		% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_EXPERIMENT_OBJ, [DOCUMENT_TYPE], 'PROPERTY1', VALUE1, ...)
		%
		% Creates an empty database document NDI_DOCUMENT_OBJ. DOCUMENT_TYPE is
		% an optional argument and can be any type that confirms to the .json
		% files in $NDI_COMMON/database_documents/*, a URL to such a file, or
		% a full path filename. If DOCUMENT_TYPE is not specified, it is taken
		% to be 'ndi_document.json'.
		%
		% If additional PROPERTY values are specified, they are set to the VALUES indicated.
		%
		% Example: mydoc = ndi_experiment_obj.newdocument('ndi_document','ndi_document.name','myname');
		%
			if nargin<2,
				document_type = 'ndi_document.json';
			end
			inputs = cat(2,varargin,{'ndi_document.experiment_id', ndi_experiment_obj.id()});
			ndi_document_obj = ndi_document(document_type, inputs);
		end; %newdocument()

		function sq = searchquery(ndi_experiment_obj)
		% SEARCHQUERY - return a search query for database objects in this experiment
		%
		% SQ = SEARCHQUERY(NDI_EXPERIMENT_OBJ)
		%
		% Returns a search query that will match all NDI_DOCUMENT objects that were generated
		% by this experiment.
		%
		% SQ = {'ndi_document.experiment_id', ndi_experiment_obj.id()};
		% 
		% Example: mydoc = ndi_experiment_obj.newdocument('ndi_document','ndi_document.name','myname');
		%
			sq = {'ndi_document.experiment_id', ndi_experiment_obj.id()};
		end; %searchquery()

		% NDI_DATABASE / NDI_DOCUMENT methods

		function ndi_experiment_obj = database_add(ndi_experiment_obj, document)
			%DATABASE_ADD - Add an NDI_DOCUMENT to an NDI_EXPERIMENT object
			%
			% NDI_EXPERIMENT_OBJ = DATABASE_ADD(NDI_EXPERIMENT_OBJ, NDI_DOCUMENT_OBJ)
			%
			% Adds the NDI_DOCUMENT NDI_DOCUMENT_OBJ to the NDI_EXPERIMENT NDI_EXPERIMENT_OBJ.
			% NDI_DOCUMENT_OBJ can also be a cell array of NDI_DOCUMENT objects, which will all be added
			% in turn.
			% 
			% The database can be queried by calling NDI_EXPERIMENT_OBJ/SEARCH
			%  
			% See also: DATABASE_RM, NDI_EXPERIMENT, NDI_DATABASE, NDI_EXPERIMENT/SEARCH

				if iscell(document),
					for i=1:numel(document),
						ndi_experiment_obj.database_add(document{i});
					end;
					return;
				end;
				if ~isa(document,'ndi_document'),
					error(['document is not an NDI_DOCUMENT']);
				end;
				ndi_experiment_obj.database.add(document);
		end; % database_add()

		function ndi_experiment_obj = database_rm(ndi_experiment_obj, doc_unique_id, varargin)
			% DATABASE_RM - Remove an NDI_DOCUMENT with a given document ID from an NDI_EXPERIMENT object
			%
			% NDI_EXPERIMENT_OBJ = DATABASE_RM(NDI_EXPERIMENT_OBJ, DOC_UNIQUE_ID)
			%   or
			% NDI_EXPERIMENT_OBJ = DATABASE_RM(NDI_EXPERIMENT_OBJ, DOC)
			%
			% Removes an NDI_DOCUMENT with document id DOC_UNIQUE_ID from the
			% NDI_EXPERIMENT_OBJ.database. In the second form, if an NDI_DOCUMENT or cell array of
			% NDI_DOCUMENTS is passed for DOC, then the document unique ids are retrieved and they
			% are removed in turn.  If DOC/DOC_UNIQUE_ID is empty, no action is taken.
			%
			% This function also takes parameters as name/value pairs that modify its behavior:
			% Parameter (default)        | Description
			% --------------------------------------------------------------------------------
			% ErrIfNotFound (0)          | Produce an error if an ID to be deleted is not found.
			%
			% See also: DATABASE_ADD, NDI_EXPERIMENT
				ErrIfNotFound = 0;
				assign(varargin{:});

				if isempty(doc_unique_id),
					return;
				end; % nothing to do

				if ~iscell(doc_unique_id),
					if ischar(doc_unique_id), % it is a single doc id
						mydoc = ndi_experiment_obj.database_search(ndi_query('ndi_document.id','exact_string',doc_unique_id,''));
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
					dependent_docs = ndi_findalldependencies(ndi_experiment_obj,[],doc_unique_id{:});
					if numel(dependent_docs)>1,
						warning(['Also deleting ' int2str(numel(dependent_docs)) ' dependent docs.']);
					end;
					for i=1:numel(dependent_docs),
						ndi_experiment_obj.database.remove(dependent_docs{i});
					end;
					for i=1:numel(doc_unique_id), 
						ndi_experiment_obj.database.remove(doc_unique_id{i});
					end;
				else,
					error(['Did not think we could get here..notify steve.']);
				end;
		end; % database_rm

		function ndi_document_obj = database_search(ndi_experiment_obj, searchparameters)
			% DATABASE_SEARCH - Search for an NDI_DOCUMENT in a database of an NDI_EXPERIMENT object
			%
			% NDI_DOCUMENT_OBJ = DATABASE_SEARCH(NDI_EXPERIMENT_OBJ, SEARCHPARAMETERS)
			%
			% Given search parameters, which are a cell list {'PARAM1', VALUE1, 'PARAM2, VALUE2, ...},
			% the database associated with the NDI_EXPERIMENT object is searched.
			%
			% Matches are returned in a cell list NDI_DOCUMENT_OBJ.
			%
				ndi_document_obj = ndi_experiment_obj.database.search(searchparameters);
		end % database_search();

		function database_clear(ndi_experiment_obj, areyousure)
			% DATABASE_CLEAR - deletes/removes all entries from the database associated with an experiment
			%
			% DATABASE_CLEAR(NDI_EXPERIMENT_OBJ, AREYOUSURE)
			%
			%   Removes all documents from the NDI_EXPERIMENT_OBJ object.
			% 
			% Use with care. If AREYOUSURE is 'yes' then the
			% function will proceed. Otherwise, it will not.
			%
				ndi_experiment_obj.database.clear(areyousure);
		end; % database_clear()
        
		function ndi_binarydoc_obj = database_openbinarydoc(ndi_experiment_obj, ndi_document_or_id)
			% DATABASE_OPENBINARYDOC - open the NDI_BINARYDOC channel of an NDI_DOCUMENT
			%
			% NDI_BINARYDOC_OBJ = DATABASE_OPENBINARYDOC(NDI_EXPERIMENT_OBJ, NDI_DOCUMENT_OR_ID)
			%
			%   Return the open NDI_BINARYDOC object that corresponds to an NDI_DOCUMENT and
			%   NDI_DOCUMENT_OR_ID can be either the document id of an NDI_DOCUMENT or an NDI_DOCUMENT object itsef.
			% 
			%  Note that this NDI_BINARYDOC_OBJ must be closed and unlocked with NDI_EXPERIMENT/CLOSEBINARYDOC.
			%  The locked nature of the binary doc is a property of the database, not the document, which is why
			%  the database is needed in the method.
			% 
				ndi_binarydoc_obj = ndi_experiment_obj.database.openbinarydoc(ndi_document_or_id);
		end; % database_openbinarydoc

		function [ndi_binarydoc_obj] = database_closebinarydoc(ndi_experiment_obj, ndi_binarydoc_obj)
			% DATABASE_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC 
			%
			% [NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_DATABASE_OBJ, NDI_BINARYDOC_OBJ)
			%
			% Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be unlocked in the
			% database, which is why it is necessary to call this function through the experiment object.
			%
				ndi_binarydoc_obj = ndi_experiment_obj.database.closebinarydoc(ndi_binarydoc_obj);
		end; % closebinarydoc

		function ndi_experiment_obj = syncgraph_addrule(ndi_experiment_obj, rule)
			% SYNCGRAPH_ADDRULE - add an NDI_SYNCRULE to the syncgraph
			%
			% NDI_EXPERIMENT_OBJ = SYNCGRAPH_ADDRULE(NDI_EXPERIMENT_OBJ, RULE)
			%
			% Adds the NDI_SYNCRULE RULE to the NDI_SYNCGRAPH of the NDI_EXPERIMENT
			% object NDI_EXPERIMENT_OBJ. 
			%
				ndi_experiment_obj.syncgraph = ndi_experiment_obj.syncgraph.addrule(rule);
		end; % syncgraph_addrule

		function ndi_experiment_obj = syncgraph_rmrule(ndi_experiment_obj, index)
			% SYNCGRAPH_RMRULE - remove an NDI_SYNCRULE from the syncgraph
			%
			% NDI_EXPERIMENT_OBJ = SYNCGRAPH_RMRULE(NDI_EXPERIMENT_OBJ, INDEX)
			%
			% Removes the INDEXth NDI_SYNCRULE from the NDI_SYNCGRAPH of the NDI_EXPERIMENT
			% object NDI_EXPERIMENT_OBJ. 
			%
				ndi_experiment_obj.syncgraph = ndi_experiment_obj.syncgraph.removerule(index);

		end; % syncgraph_rmrule

		%%%%%% PATH methods

		function p = getpath(ndi_experiment_obj)
			% GETPATH - Return the path of the experiment
			%
			%   P = GETPATH(NDI_EXPERIMENT_OBJ)
			%
			% Returns the path of an NDI_EXPERIMENT object.
			%
			% The path is some sort of reference to the storage location of 
			% the experiment. This might be a URL, or a file directory, depending upon
			% the subclass.
			%
			% In the NDI_EXPERIMENT class, this returns empty.
			%
			% See also: NDI_EXPERIMENT
			p = [];
		end;

		%%%%%% REFERENCE methods

		function obj = findexpobj(ndi_experiment_obj, obj_name, obj_classname)
			% FINEXPDOBJ - search an NDI_EXPERIMENT for a specific object given name and classname
			%
			% OBJ = FINDEXPOBJ(NDI_EXPERIMNENT_OBJ, OBJ_NAME, OBJ_CLASSNAME)
			%
			% Examines the DAQSYSTEM list, DATABASE, and PROBELIST for an object with name OBJ_NAME 
			% and classname OBJ_CLASSNAME. If no object is found, OBJ will be empty ([]).
			%
				obj = [];

				z = []; 
				try
					z=feval(obj_classname);
				end;

				trydaqsystem = 0;
				trydatabase = 0;
				tryprobelist = 0;

				if isempty(z),
					trydaqsystem = 1;
					trydatabase = 0;
					tryprobelist = 1;
				else,
					if isa(z,'ndi_probe'),
						tryprobelist = 1;
					elseif isa(z,'ndi_daqsystem'),
						trydaqsystem = 1;
					else,
						trydatabase = 0;
					end;
				end;

				if trydaqsystem,
					obj_here = ndi_experiment_obj.daqsystem.load('name',obj_name);
					if ~isempty(obj_here),
						if strcmp(class(obj_here),obj_classname),
							% it is our match
							obj = obj_here;
							return;
						end;
					end;
				end

				if tryprobelist,
					probes = ndi_experiment_obj.getprobes();
					for i=1:numel(probes),
						if strcmp(class(probes{i}),obj_classname) & strcmp(probes{i}.epochsetname,obj_name),
							obj = probes{i}; 
							return;
						end;
					end;
				end

		end; % findexpobj

		function probes = getprobes(ndi_experiment_obj, varargin)
			% GETPROBES - Return all NDI_PROBES that are found in NDI_DAQSYSTEM epoch contents entries
			%
			% PROBES = GETPROBES(NDI_EXPERIMENT_OBJ, ...)
			%
			% Examines all NDI_DAQSYSTEM entries in the NDI_EXPERIMENT_OBJ's device array
			% and returns all NDI_PROBE entries that can be constructed from each device's
			% NDI_EPOCHPROBEMAP entries.
			%
			% PROBES is a cell array of NDI_PROBE objects.
			%
			% One can pass additional arguments that specify the classnames of the probes
			% that are returned:
			%
			% PROBES = GETPROBES(NDI_EXPERIMENT_OBJ, CLASSMATCH )
			%
			% only probes that are members of the classes CLASSMATCH etc., are
			% returned.
			%
			% PROBES = GETPROBES(NDI_EXPERIMENT_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
			%
			% returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
			% has a value of VALUE2, etc. Properties of probes are 'name', 'reference', and 'type'.
			%
			%
				probestruct = [];
				devs = ndi_experiment_obj.daqsystem_load('name','(.*)');
				if ~isempty(devs),
					probestruct = getprobes(celloritem(devs,1));
				end
				for d=2:numel(devs),
					probestruct = cat(1,probestruct,getprobes(devs{d}));
				end
				probestruct = equnique(probestruct);
				probes = ndi_probestruct2probe(probestruct, ndi_experiment_obj);

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

		function things = getthings(ndi_experiment_obj, varargin);
			% GETTHINGS - Return all NDI_THING objects that are found in experiment database
			%
			% THINGS = GETTHINGS(NDI_EXPERIMENT_OBJ, ...)
			%
			% Examines all the database of NDI_EXPERIMENT_OBJ and returns all NDI_THING
			% entries.
			%
			% THINGS is a cell array of NDI_PROBE objects.
			%
			% THINGS = GETTHINGS(NDI_EXPERIMENT_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
			%
			% returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
			% has a value of VALUE2, etc. Properties of things are 'thing.name', 'thing.type',
			% 'thing.direct', and 'probe.name', 'probe.type', and 'probe.reference'.
			% 

				sq = cat(2,{'ndi_document.type', 'ndi_thing', ...
						'ndi_document.experiment_id', ndi_experiment_obj.id()}, ...
						varargin{:}); 
				doc = ndi_experiment_obj.database_search(sq);
				things = {};
				for i=1:numel(doc),
					things{i} = ndi_document2thing(doc{i}, ndi_experiment_obj);
				end;
		end; % getthings()

		function b = eq(e1,e2)
			% EQ - are 2 NDI_EXPERIMENTS equal?
			% 
			% B = EQ(E1, E2)
			%
			% Returns 1 if and only if the experiments have the same unique reference number.
				if ~isa(e2,'ndi_experiment'),
					b = 0;
				else,
					b = strcmp(e1.id(), e2.id());
				end;
		end; % eq()

		function identifier = id(ndi_experiment_obj)
			% ID - return the unique identifier for this experiment
			%
			% IDENTIFIER = ID(NDI_EXPERIMENT_OBJ)
			%
			% Return the unique identifier for this experiment.
			%
				identifier = [ndi_experiment_obj.reference '_' ndi_experiment_obj.unique_reference];
		end; % id
	end; % methods
end % classdef

