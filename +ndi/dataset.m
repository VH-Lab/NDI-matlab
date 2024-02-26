classdef dataset < handle % & ndi.ido but this cannot be a superclass because it is not a handle; we do it by construction

	properties (GetAccess=public, SetAccess = protected)
		reference		% A string reference for the dataset
		identifier		% A unique identifier
		session			% A session to hold documents for this dataset
	end
	properties (GetAccess=protected, SetAccess = protected)
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

				ndi_dataset_obj.reference = reference;
				ndi_dataset_obj.database = [];
				ndiido = ndi.ido();
				ndi_dataset_obj.identifier = ndiido.id();
                end

		function identifier = id(ndi_dataset_obj)
			% ID - return the identifier of an ndi.dataset object
			%
			% IDENTIFIER = ID(NDI_DATASET_OBJ)
			%
			% Returns the unique identifier of an ndi.dataset object.
			%
				identifier = ndi_dataset_obj.identifier;
		end; % id()

		function ref = unique_reference_string(ndi_dataset_obj)
			% UNIQUE_REFERENCE_STRING - return the reference string for an ndi.dataset object
			%
			% REF_STRING = UNIQUE_REFERENCE_STRING(NDI_DATASET_OBJ)
			%
			% Returns the reference string for an ndi.dataset object. This can be any
			% string, it is not necessarily unique among datasets. The dataset identifier
			% returned by ID is unique.
			%
			% See also: ndi.dataset/ID

		end; % unique_reference_string()

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
				ref_list = {};
				id_list = {};
				q_session = ndi.query('','isa','session');
				d = ndi_dataset_obj.database_search(q_session);
				for i=1:numel(d),
					ref_list{i} = d{i}.document_properties.session.reference;
					id_list{i} = d{i}.document_properties.base.session_id;
				end;
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
				p = [];
                end;

		% database methods

			%01234567890123456789012345678901234567890123456789012345678901234567890123456789
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
				ndi_dataset_obj.session.database_add(document);

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
                                did.datastrucrures.assign(varargin{:});
				if isempty(doc_unique_id),
					% nothing to do
					return;
				end;
				if ~iscell(doc_unique_id),
					doc_unique_id = {doc_unique_id};
				end;
				q = [];
				for i=1:numel(doc_unique_id),
					if ~isa(doc_unique_id{i},'ndi.document'),
						if isempty(q),
							q = ndi.query('base.id','exact_string',doc_unique_id{i});
						else,
							q = q | ndi.query('base.id','exact_string',doc_unique_id{i});
						end;
					end;
				end;
				docs_to_fetch = {};
				if ~isempty(q),
					docs_to_fetch = ndi_dataset_obj.database_search(q);
				end;
				include = [];
				for i=1:numel(doc_unique_id),
					if ~isa(doc_unique_id{i},'ndi.document'),
						for k=1:numel(docs_to_fetch),
							if strcmp(docs_to_fetch{k}.document_properties.base.id,...
								doc_unique_id{i}),
								doc_unique_id{i} = docs_to_fetch{k};
								break;
							end;
						end;
					end;
					is ~isa(doc_unique_id{i},'ndi.document'),
						if ErrIfNotFound,
							error(['Unable to locate document ' doc_unique_id{i} '.']);
						else,
							doc_unique_id{i} = [];
						end;
					else,
						include(end+1) = i;
					end;
				end;
				doc_unique_id = doc_unique_id(include);
				
				[b,errmsg] = ndi_dataset_obj.validate_documents(doc_unique_id);

				if ~b,
					error(errmsg);
				else,
					ndi_dataset_obj.session.database_rm(doc_unique_id);
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
				ndi_document_obj = ndi_dataset_obj.session.database.search(searchparameters);
		end % database_search();

		function [b,errmsg] = validate_documents(ndi_dataset_obj, document)
			% VALIDATE_DOCUMENTS - validate whether documents belong to a dataset
			%
			% [B, ERRMSG] = VALIDATE_DOCUMENTS(NDI_DATASET_OBJ, DOCUMENT)
			%
			% Given an ndi.document DOCUMENT or a cell array of ndi.documents DOCUMENT,
			% determines whether all document session_ids match the dataset's id.
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
					b = b & strcmp(document{i}.document_properties.base.session_id,ndi_dataset_obj.id());
					if ~b,
						errmsg = ['All documents associated with the dataset (and not a session in the dataset) must have a session_id equal to the dataset id (document ' int2str(i) ' does not match).'];
						break;
					end;
				end;
		end; % validate_documents()

	end; % methods

end % class
