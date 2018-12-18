classdef nsd_database
	% A (primarily abstract) database class for NSD that stores and manages virtual documents (NoSQL database)
	%
	% 
	%
	% 

	properties (SetAccess=protected,GetAccess=public)
		path % The file system or remote path to the database
		experiment_unique_reference % The reference string for the database
	end % properties

	methods
		function nsd_database_obj = nsd_database(varargin)
			% NSD_DATABASE - create a new NSD_DATABASE
			%
			% NSD_DATABASE_OBJ = NSD_DATABASE(PATH, REFERENCE)
			%
			% Creates a new NSD_DATABASE object with data path PATH
			% and reference REFERENCE.
			%
			
			path = '';
			experiment_unique_reference = '';

			if nargin>0,
				path = varargin{1};
			end
			if nargin>1,
				experiment_unique_reference = varargin{2};
			end

			nsd_database_obj.path = path;
			nsd_database_obj.experiment_unique_reference = experiment_unique_reference;
		end % nsd_database

		function nsd_document_obj = newdocument(nsd_database_obj, document_type)
			% NEWDOCUMENT - obtain a new/blank NSD_DOCUMENT object that can be used with a NSD_DATABASE
			% 
			% NSD_DOCUMENT_OBJ = NEWDOCUMENT(NSD_DATABASE_OBJ [, DOCUMENT_TYPE])
			%
			% Creates a new/blank NSD_DOCUMENT document object that can be used with this
			% NSD_DATABASE.
			%
				if nargin<2,
					document_type = 'nsd_document';
				end;
				nsd_document_obj = nsd_document(document_type, ...
						'experiment_unique_refrence', nsd_database_obj.experiment_unique_reference);
		end % newdocument

		function nsd_database_obj = add(nsd_database_obj, nsd_document_obj, varargin)
			% ADD - add an NSD_DOCUMENT to the database at a given path
			%
			% NSD_DATABASE_OBJ = ADD(NSD_DATABASE_OBJ, NSD_DOCUMENT_OBJ, DBPATH, ...)
			%
			% Adds the document NSD_DOCUMENT_OBJ to the database NSD_DATABASE_OBJ.
			%
			% This function also accepts name/value pairs that modify its behavior:
			% Parameter (default)      | Description
			% -------------------------------------------------------------------------
			% 'Update'  (1)            | If document exists, update it. If 0, an error is 
			%                          |   generated if a document at DBPATH exists.
			% 
			% See also: NAMEVALUEPAIR 
				Update = 1;
				assign(varargin{:});
				add_parameters = var2struct('Update');
				nsd_database_obj = do_add(nsd_database_obj, nsd_document_obj, add_parameters);
		end % add()

		function [nsd_document_obj, version] = read(nsd_database_obj, nsd_document_id, version )
			% READ - read an NSD_DOCUMENT from an NSD_DATABASE at a given db path
			%
			% NSD_DOCUMENT_OBJ = READ(NSD_DATABASE_OBJ, NSD_DOCUMENT_ID, [VERSION]) 
			%
			% Read the NSD_DOCUMENT object with the document ID specified by NSD_DOCUMENT_ID. If VERSION
			% is provided (an integer) then only the version that is equal to VERSION is returned.
			% Otherwise, the latest version is returned.
			%
			% If there is no NSD_DOCUMENT object with that ID, then empty is returned ([]).
			%
				if nargin<3,
					[nsd_document_obj, version] = do_read(nsd_database_obj, nsd_document);
				else,
					[nsd_document_obj, version] = do_read(nsd_database_obj, nsd_document, version);
				end
		end % read()

		function nsd_database_obj = remove(nsd_database_obj, nsd_document_id, versions)
			% REMOVE - remove a document from an NSD_DATABASE
			%
			% NSD_DATABASE_OBJ = REMOVE(NSD_DATABASE_OBJ, NSD_DOCUMENT_ID) 
			%     or
			% NSD_DATABASE_OBJ = REMOVE(NSD_DATABASE_OBJ, NSD_DOCUMENT_ID, VERSIONS)
			%
			% Removes the NSD_DOCUMENT object with the 'document unique reference' equal
			% to NSD_DOCUMENT_OBJ_ID.  If VERSIONS is specified, then only the versions that match
			% the entries in VERSIONS are removed.
			%
				if nargin<3,
					nsd_database_obj = do_remove(nsd_database_obj, nsd_document_id);
				else,
					nsd_database_obj = do_remove(nsd_database_obj, nsd_document_id, versions);
				end
		end % remove()

		function [nsd_document_objs,versions] = search(nsd_database_obj, searchparams)
			% SEARCH - search for an NSD_DOCUMENT from an NSD_DATABASE
			%
			% [DOCUMENT_OBJS,VERSIONS] = SEARCH(NSD_DATABASE_OBJ, {'PARAM1', VALUE1, 'PARAM2', VALUE2, ... })
			%
			% Searches metadata parameters PARAM1, PARAM2, etc of NDS_DOCUMENT entries within an NSD_DATABASE_OBJ.
			% If VALUEN is a string, then a regular expression is evaluated to determine the match. If VALUEN is not
			% a string, then the items must match exactly.
			% If PARAMN1 begins with a dash, then VALUEN indicates the value of one of these special parameters:
			%
			% This function returns a cell array of NSD_DOCUMENT objects. If no documents match the
			% query, then an empty cell array ({}) is returned. An array VERSIONS contains the document version of
			% of each NSD_DOCUMENT.
			% 
				searchOptions = {};
				[nsd_document_objs, versions] = nsd_database_obj.do_search(searchOptions,searchparams);
		end % search()

	end % methods nsd_database

	methods (Access=protected)
		function nsd_database_obj = do_add(nsd_database_obj, nsd_document_obj, add_parameters)
		end % do_add
		function [nsd_document_obj, version] = do_read(nsd_database_obj, nsd_document_id, version);
		end % do_read
		function nsd_document_obj = do_remove(nsd_database_obj, nsd_document_id, versions)
		end % do_remove
		function [nsd_document_objs,versions] = do_search(nsd_database_obj, searchoptions, searchparams) 
		end % do_search()

	end % Methods (Access=Protected) protected methods
end % classdef


