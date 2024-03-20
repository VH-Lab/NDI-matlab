classdef dataset < handle % & ndi.ido but this cannot be a superclass because it is not a handle; we do it by construction

	properties (GetAccess=public, SetAccess = protected)
		session			% A session to hold documents for this dataset
	end
	properties (GetAccess=protected, SetAccess = protected)
		session_info            % A structure with the sessions here
		session_array           % An array with session objects contained in the dataset
	end

	methods

		function ndi_dataset_obj = dataset(reference)
			% ndi.dataset - Create a new ndi.dataset object
			%
			%   NDI_DATASET_OBJ=ndi.dataset(REFERENCE)
			%
			% Creates a new ndi.dataset object. The dataset has a unique
			% reference REFERENCE. This class is an abstract class and typically
			% an end user will open a specific subclass such as ndi.dataset.dir.
			%
			%   ndi.dataset/GETPATH, ndi.dataset/GETREFERENCE

                end

		function identifier = id(ndi_dataset_obj)
			% ID - return the identifier of an ndi.dataset object
			%
			% IDENTIFIER = ID(NDI_DATASET_OBJ)
			%
			% Returns the unique identifier of an ndi.dataset object.
			%
				identifier = ndi_dataset_obj.session.id();
		end; % id()

		function ref = reference(ndi_dataset_obj)
			% reference - return the reference string for an ndi.dataset object
			%
			% REF_STRING = REFERENCE(NDI_DATASET_OBJ)
			%
			% Returns the reference string for an ndi.dataset object. This can be any
			% string, it is not necessarily unique among datasets. The dataset identifier
			% returned by ID is unique.
			%
			% See also: ndi.dataset/ID
				ref = ndi_dataset_obj.session.reference;
		end; % unique_reference_string()

		function ndi_dataset_obj = add_linked_session(ndi_dataset_obj, ndi_session_obj)
			% ADD_LINKED_SESSION - link an ndi.session to an ndi.dataset
			%
			% NDI_DATASET_OBJ = ADD_LINKED_SESSION(NDI_DATASET_OBJ, NDI_SESSION_OBJ)
			%
			% Add an ndi.session object to an ndi.dataset, without ingesting the session
			% into the dataset. Instead, the ndi.session is linked to the dataset, but
			% the session remains where it is.
			% 
				if isempty(ndi_dataset_obj.session_array),
					ndi_dataset_obj.build_session_info;
				end;

				% first, make sure it is not already there

				match = any(strcmp(ndi_session_obj.id(),{ndi_dataset_obj.session_info.session_id}));
				if match,
					error(['ndi.session object with id ' ndi_session_obj.id() ' is already part of dataset ' ndi_dataset_obj.id() '.']);
				end;

				% okay, it is new, let's add it

				session_info_here.session_id = ndi_session_obj.id();
				session_info_here.session_reference = ndi_session_obj.reference();
				session_info_here.is_linked = 1;
				session_info_here.session_creator = class(ndi_session_obj);
				session_creator_args = ndi_session_obj.creator_args();
				for i=1:6, %numel(session_creator_args),
					field_here = ['session_creator_input' int2str(i)];
					session_info_here = setfield(session_info_here,field_here,'');
					if numel(session_creator_args)>=i,
						session_info_here = setfield(session_info_here,field_here,session_creator_args{i});
					end;
				end;

				% maybe later
				% assume that the second creator argument is a file path that needs to be made relative
				% session_info.session_creator_input2 = vlt.file.relativeFilename(ndi_dataset_obj.getpath(),ndi_session_obj.getpath)

				ndi_dataset_obj.session_info(end+1) = session_info_here;
				ndi_dataset_obj.session_array(end+1) = struct('session_id',ndi_session_obj.id(),'session',ndi_session_obj);

				d = ndi.document('dataset_session_info','dataset_session_info.dataset_session_info',ndi_dataset_obj.session_info);
				d_ = ndi_dataset_obj.session.database_search(ndi.query('','isa','dataset_session_info'));
					% delete the previous
				ndi_dataset_obj.session.database_rm(d_);
				d = d.set_session_id(ndi_dataset_obj.id());
				ndi_dataset_obj.session.database_add(d);

		end; % add_linked_session()

			%01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function ndi_dataset_obj = add_ingested_session(ndi_dataset_obj, ndi_session_obj)
			% ADD_INGESTED_SESSION - ingets an ndi.session into an ndi.dataset
			%
			% NDI_DATASET_OBJ = ADD_INGESTED_SESSION(NDI_DATASET_OBJ, NDI_SESSION_OBJ)
			%
			% Add an ndi.session object to an ndi.dataset, by copying the session
			% documents into the dataset. 
			% 
				if isempty(ndi_dataset_obj.session_array),
					ndi_dataset_obj.build_session_info;
				end;

				% first, make sure it is not already there

				match = any(strcmp(ndi_session_obj.id(),{ndi_dataset_obj.session_info.session_id}));
				if match,
					error(['ndi.session object with id ' ndi_session_obj.id() ' is already part of dataset ' ndi_dataset_obj.id() '.']);
				end;

				% second, make sure it is fully ingested
				is_fully_ingested = ndi_session_obj.is_fully_ingested();
				if ~is_fully_ingested,
					error(['ndi.session object with id ' ndi_session_obj.id() ' and reference ' ndi_session_obj.reference ' is not yet fully ingested. It must be fully ingested before it can be added in ingested form to an ndi.dataset object.']);
				end;

				% okay, let's add it
				session_info_here.session_id = ndi_session_obj.id();
				session_info_here.session_reference = ndi_session_obj.reference;
				session_info_here.session_creator = class(ndi_session_obj);
				session_info_here.is_linked = 0;
				session_creator_args = ndi_session_obj.creator_args();
				for i=1:6, %numel(session_creator_args),
					field_here = ['session_creator_input' int2str(i)];
					session_info_here = setfield(session_info_here,field_here,'');
					if numel(session_creator_args)>=i,
						session_info_here = setfield(session_info_here,field_here,session_creator_args{i});
					end;
				end;

				% terrible kludge
				if isa(ndi_session_obj,'ndi.session.dir'),
					session_info_here = setfield(session_info_here,'session_creator_input2',''); % same relative path % ndi_dataset_obj.getpath());
				else,
					error(['Not smart enough to add ingested sessions of type ' class(ndi_session_obj) ' yet.']);
				end;

				ndi.database.fun.copy_session_to_dataset(ndi_session_obj, ndi_dataset_obj);

				ndi_dataset_obj.session_info(end+1) = session_info_here;
				ndi_dataset_obj.session_array(end+1) = struct('session_id',ndi_session_obj.id(),'session',[]); % make it open it again

				d = ndi.document('dataset_session_info','dataset_session_info.dataset_session_info',ndi_dataset_obj.session_info);
				d_ = ndi_dataset_obj.session.database_search(ndi.query('','isa','dataset_session_info'));
					% delete the previous
				ndi_dataset_obj.session.database_rm(d_);
				d = d.set_session_id(ndi_dataset_obj.id());
				ndi_dataset_obj.session.database_add(d);

		end; % add_ingested_session()

		function ndi_session_obj = open_session(ndi_dataset_obj, session_id)
			% SESSION - open an ndi.session object from an ndi.dataset
			%
			% NDI_SESSION_OBJ = OPEN_SESSION(NDI_DATASET_OBJ, SESSION_ID)
			%
			% Open an ndi.session object with session identifier SESSION_ID that is stored
			% in the ndi.dataset NDI_DATASET_OBJ.
			%
			% See also: ndi.session, ndi.dataset/session_list()
			%
				if isempty(ndi_dataset_obj.session_array),
					ndi_dataset_obj.build_session_info();
				end;
				
				match = find(strcmp(session_id,{ndi_dataset_obj.session_array.session_id}));
				match_ = find(strcmp(session_id,{ndi_dataset_obj.session_info.session_id}));
				if isempty(match),
					error(['session_id ' session_id ' not found in dataset ' ...
						ndi_dataset_obj.id() ]);
				else,
					if ~isempty(ndi_dataset_obj.session_array(match).session),
						ndi_session_obj = ndi_dataset_obj.session_array(match).session;
					else,
						patharg = ndi_dataset_obj.session_info(match_).session_creator_input2;
						if ndi_dataset_obj.session_info(match_).is_linked==0,
							patharg = ndi_dataset_obj.getpath();
						end;
						ndi_dataset_obj.session_array(match).session = ...
							feval(ndi_dataset_obj.session_info(match_).session_creator,...
								ndi_dataset_obj.session_info(match_).session_creator_input1, ...
								patharg,...
								session_id);
								%ndi_dataset_obj.session_info(match_).session_creator_input3, ...
								%ndi_dataset_obj.session_info(match_).session_creator_input4, ...
								%ndi_dataset_obj.session_info(match_).session_creator_input5, ...
								%ndi_dataset_obj.session_info(match_).session_creator_input6);
						ndi_session_obj = ndi_dataset_obj.session_array(match).session;
					end;
				end;
		end; % open_session()

		function [ref_list,id_list] = session_list(ndi_dataset_obj)
			% SESSION_LIST - return the session reference/identifier list for a dataset
			%
			% [REF_LIST, ID_LIST] = SESSION_LIST(NDI_DATASET_OBJ)
			%
			% Returns information about ndi.session objects contained in an ndi.dataset
			% object NDI_DATASET_OBJ. REF_LIST is a cell array of reference strings, and
			% ID_LIST is a cell array of unique identifier strings. The nth entry of 
			% REF_LIST corresponds to the Nth entry of ID_LIST (that is, REF_LIST{n} is the
			% reference that corresponds to the ndi.session with unique identifier ID_LIST{n}.
			% 
				if isempty(ndi_dataset_obj.session_info),
					ndi_dataset_obj.build_session_info();
				end;

				ref_list = {ndi_dataset_obj.session_info.session_reference};
				id_list = {ndi_dataset_obj.session_info.session_id};
		end; % session_list()

		function p = getpath(ndi_dataset_obj)
			% GETPATH - Return the path of the dataset
			%
			%   P = GETPATH(NDI_DATASET_OBJ)
			%
			% Returns the path of an ndi.dataset object.
			%
			% The path is some sort of reference to the storage location of 
			% the dataset. This might be a URL, or a file directory, depending upon
			% the subclass.
			%
			% In the ndi.dataset class, this returns empty.
			% 
			% See also: ndidataset.
				p = ndi_dataset_obj.session.getpath();
                end;

		% database methods

		function ndi_dataset_obj = database_add(ndi_dataset_obj, document)
			%DATABASE_ADD - Add an ndi.document to an ndi.dataset object
			%               
			% NDI_DATASET_OBJ = DATABASE_ADD(NDI_DATASET_OBJ, NDI_DOCUMENT_OBJ)
			%
			% Adds the ndi.document NDI_DOCUMENT_OBJ to the ndi.dataset NDI_DATASET_OBJ.
			% NDI_DOCUMENT_OBJ can also be a cell array of ndi.document objects, which will
			% all be added in turn.
			%
			% The database can be queried by calling NDI_DATASET_OBJ/SEARCH
			%
			% See also: ndi.dataset/database_search(), ndi.dataset/database_rm()
				if ~iscell(document),
					document = {document};
				end;

				ndi_session_ids_here = {};
				for i=1:numel(document),
					ndi_session_ids_here{end+1} = document{i}.document_properties.base.session_id;
				end;

				usession_ids = setdiff(unique(ndi_session_ids_here),ndi.session.empty_id());
				s = {};
				% make sure all documents have a home before doing anything else
				for i=1:numel(usession_ids),
					if ~strcmp(usession_ids{i},ndi_dataset_obj.id()),
						s{i} = ndi_dataset_obj.open_session(usession_ids{i});
					else,
						s{i} = ndi_dataset_obj.session;
					end;
				end;

				% now add them in turn
				for i=1:numel(usession_ids), 
					indexes = find( strcmp(usession_ids{i},ndi_session_ids_here) | strcmp(ndi.session.empty_id(),ndi_session_ids_here));
					s{i}.database_add_document(strcmp(usession_ids{i},ndi_session_ids_here));
				end;
		end; % database_add

		function ndi_dataset_obj = database_rm(ndi_dataset_obj, doc_unique_id, varargin)
			% DATABASE_RM - Remove an ndi.document with a given document ID from a dataset
			%
			% NDI_DATASET_OBJ = DATABASE_RM(NDI_DATASET_OBJ, DOC_UNIQUE_ID)
			%   or
			% NDI_DATASET_OBJ = DATABASE_RM(NDI_DATASET_OBJ, DOC)
			%
			% Removes an ndi.document with document id DOC_UNIQUE_ID from the
			% NDI_DATASET_OBJ database. In the second form, if an ndi.document or cell array
			% of NDI_DOCUMENTS is passed for DOC, then the document unique ids are retrieved
			% and they are removed in turn.  If DOC/DOC_UNIQUE_ID is empty, no action is
			% taken.
			%
			% This function also takes parameters as name/value pairs that modify its behavior:
			% Parameter (default)        | Description
			% --------------------------------------------------------------------------------
			% ErrIfNotFound (0)          | Produce an error if an ID to be deleted is not found.
			%
			% See also: ndi.dataset/database_add(), ndi.dataset/database_search()
                                ErrIfNotFound = 0;
                                did.datastructures.assign(varargin{:});
				ndi_dataset_obj.session.database_add(document,'ErrIfNotFound',ErrIfNotFound);
				open_linked_sessions(ndi_dataset_obj);
				match = [ndi_dataset_obj.session_info.is_linked];
				for i=1:numel(match),
					ndi_dataset_obj.session_array(match(i)).session.database_rm(doc_unique_id);
				end;
		end; % database_rm

		function ndi_document_obj = database_search(ndi_dataset_obj, searchparameters)
			% DATABASE_SEARCH - Search for an ndi.document in a database of an ndi.dataset object
			%
			% NDI_DOCUMENT_OBJ = DATABASE_SEARCH(NDI_DATASET_OBJ, SEARCHPARAMETERS)T
			%
			% Given search parameters, which is an ndi.query object, the database associated
			% with the ndi.dataset object NDI_DATASET_OBJ is searched.
			%
			% Matches are returned in a cell list NDI_DOCUMENT_OBJ.
			%
			% See also: ndi.dataset/database_add(), ndi.dataset/database_rm()
				ndi_document_obj = ndi_dataset_obj.session.database_search(searchparameters);
				open_linked_sessions(ndi_dataset_obj);
				match = find([ndi_dataset_obj.session_info.is_linked]);
				for i=1:numel(match),
					ndi_document_obj = cat(1,ndi_dataset_obj.session_array(match(i)).session.database_search(searchparameters));
				end;
		end % database_search();

		function ndi_binarydoc_obj = database_openbinarydoc(ndi_dataset_obj, ndi_document_or_id, filename)
			% DATABASE_OPENBINARYDOC - open the ndi.database.binarydoc channel of an ndi.document
			%
			% NDI_BINARYDOC_OBJ = DATABASE_OPENBINARYDOC(NDI_DATASET_OBJ, NDI_DOCUMENT_OR_ID, FILENAME)
			%
			%  Return the open ndi.database.binarydoc object that corresponds to an ndi.document and
			%  NDI_DOCUMENT_OR_ID can be either the document id of an ndi.document or an ndi.document object itsef.
			%  The document is opened for reading only. Document binary streams may not be edited once the
			%  document is added to the database.
			% 
			%  Note that this NDI_BINARYDOC_OBJ must be closed with ndi.dataset/CLOSEBINARYDOC.
			% 
				ndi_binarydoc_obj = ndi_dataset_obj.session.database_openbinarydoc(ndi_document_or_id, filename);
		end; % database_openbinarydoc

		function [ndi_binarydoc_obj] = database_closebinarydoc(ndi_dataset_obj, ndi_binarydoc_obj)
			% DATABASE_CLOSEBINARYDOC - close an ndi.database.binarydoc
			%
			% [NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_DATASET_OBJ, NDI_BINARYDOC_OBJ)
			%
			% Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be unlocked in the
			% database, which is why it is necessary to call this function through the dataset object.
			% 
				ndi_binarydoc_obj = ndi_dataset_obj.session.database_closebinarydoc(ndi_binarydoc_obj);
		end; % database_closebinarydoc

		function ndi_session_obj = document_session(ndi_dataset_obj, ndi_document_obj)
			% DOCUMENT_SESSION return the ndi.session of an ndi.document object in an ndi.dataset
			%
			% NDI_SESSION_OBJ = DOCUMENT_SESSION(NDI_DATASET_OBJ, NDI_DOCUMENT_OBJ)
			%
			% Given an ndi.document, return an open ndi.session object that contains the
			% the document.
			%
				session_id = ndi_document_obj.document_properties.base.session_id;
				ndi_session_obj = ndi_dataset_obj.open_session(session_id)
		end; % document_session()

	end; % methods

	methods (Access=protected)

		function build_session_info(ndi_dataset_obj)
			% BUILD_SESSION_INFO - build the session info data structure for an ndi.dataset
			%
			% BUILD_SESSION_INFO(NDI_DATASET_OBJ)
			%
			% Builds the internal variables 'session_array' and 'session_info' for 
			% an ndi.dataset object.

				q = ndi.query('','isa','dataset_session_info') & ...
					ndi.query('base.session_id','exact_string',ndi_dataset_obj.id());
				session_info_doc = ndi_dataset_obj.session.database_search(q); % we know we are searching the dataset session
				if isempty(session_info_doc),
					% we don't have any
					ndi_dataset_obj.session_info = did.datastructures.emptystruct('session_id','session_reference','is_linked','session_creator',...
								'session_creator_input1','session_creator_input2','session_creator_input3',...
								'session_creator_input4','session_creator_input5','session_creator_input6');
				else,
					if numel(session_info_doc)>1,
						error(['Found too many dataset session info documents (' int2str(numel(session_info_doc)) ') for dataset ' ndi_dataset_obj.id() '.']);
					end;
					ndi_dataset_obj.session_info = session_info_doc{1}.document_properties.dataset_session_info.dataset_session_info;
				end;

				% now we have session_info structure, build the initial session_array

				ndi_dataset_obj.session_array = did.datastructures.emptystruct('session_id','session');
				for i=1:numel(ndi_dataset_obj.session_info),
					session_array_here.session_id = ndi_dataset_obj.session_info(i).session_id;
					session_array_here.session = []; % initially don't open it
					ndi_dataset_obj.session_array(i) = session_array_here; % entries will match
				end;
		end; % build_session_info()

		function open_linked_sessions(ndi_dataset_obj)
			% OPEN_LINKED_SESSIONS - ensure that all linked sessions are open
			%
			% OPEN_LINKED_SESSIONS(NDI_DATASET_OBJ)
			% 
			% Open all linked dataset sessions, if they are not already open.
			% 
				if isempty(ndi_dataset_obj.session_info),
					ndi_dataset_obj.build_session_info();
				end;

				for i=1:numel(ndi_dataset_obj.session_info),
					if ndi_dataset_obj.session_info(i).is_linked,
						if isempty(ndi_dataset_obj.session_array(i).session),
							ndi_dataset_obj.open_session(ndi_dataset_obj.session_info(i).session_id);
						end;
					end;
				end;
		end; % open_linked_sessions

	end; % methods protected
end % class

