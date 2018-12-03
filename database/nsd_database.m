classdef nsd_database
	% A (primarily abstract) database class for NSD that stores and manages virtual documents (NoSQL database)
	%

	properties (SetAccess=protected,GetAccess=public)
		path % The file system or remote path to the database
		reference % The reference string for the database
		pwd % The present working directory 
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
			reference = '';
			pwd = '/';
			if nargin>0,
				path = vargin{1};
			end
			if nargin>1,
				reference = varargin{1};
			end

			nsd_database_obj.path = path;
			nsd_database_obj.reference = reference;
		end % nsd_database


		function nsd_database_obj = add(nsd_database_obj, nsd_document_obj, dbpath, varargin)
			% ADD - add an NSD_DOCUMENT to the database at a given path
			%
			% NSD_DATABASE_OBJ = ADD(NSD_DATABASE_OBJ, NSD_DOCUMENT_OBJ, DBPATH, ...)
			%
			% 
			% This function also accepts name/value pairs that modify its behavior:
			% Parameter (default)      | Description
			% -------------------------------------------------------------------------
			% 'CreatePath' (1)         | Create the antecedent path if it does not exist
			% 'Overwrite'  (1)         | If document exists, overwrite it
			% 
			% See also: NAMEVALUEPAIR 
				CreatePath = 1;
				assign(varargin{:});
		end % add()

		function nsd_document_obj = read(nsd_database_obj, dbpath)
			% READ - read an NSD_DOCUMENT from an NSD_DATABASE at a given db path
			%
			% NSD_DOCUMENT_OBJ = READ(NSD_DATABASE_OBJ, DBPATH)
			%
			% Read the NSD_DOCUMENT object at the location specified by DBPATH.
			%
			% If there is no NSD_DOCUMENT object at that location, then empty is returned ([]).
			%
			% If DBPATH is a database directory, then a cell array of strings containing the document names
			% in the directory is returned. If it is an empty directory, then an empty cell array is returned ({}).
			%
		end % read()

		function nsd_document_objs = search(nsd_database_obj, varargin)
			% SEARCH - search for an NSD_DOCUMENT from an NSD_DATABASE
			%
			% DOCUMENT_OBJS = SEARCH(NSD_DATABASE_OBJ, 'PARAM1', VALUE1, 'PARAM2', VALUE2, ...)
			%
			% Searches metadata parameters PARAM1, PARAM2, etc of NDS_DOCUMENT entries within an NSD_DATABASE_OBJ.
			% If VALUEN is a string, then a regular expression is evaluated to determine the match. If VALUEN is not
			% a string, then the items must match exactly.
			% If PARAMN1 begins with a dash, then VALUEN indicates the value of one of these special parameters:
			%
			% Parameter (default)               | Description
			% ----------------------------------------------------------------------------
			% -SearchDir (pwd)                  | Search in this directory (default is pwd)
			% -RecursiveSearch (1)              | Search recursively
			% 
			%
			% This function returns a cell array of NSD_DOCUMENT objects. 
			% 
			%

				SearchDir = nsd_database_obj.pwd;
				RecursiveSearch = 1;
				for i=1:2:numel(varargin),
					if numel(varargin{i})>1,
						if varargin{i}(1)=='-',
							assign({ varargin{i}(2:end) , varargin{i+1} } );
						end
					end
				end

				

		end % search()

		function nsd_database_obj = setpwd(nsd_database_obj, varargin)
			% SETPWD - set the present working directory of an NSD_DATABASE
			%
			% NSD_DATABASE_OBJ = SETPWD(NSD_DATABASE_OBJ, ...)
			%
			% Sets the present working directory of an NSD_DATABASE. The PWD can be
			% read directly from the object:
			% 	NSD_DATABASE_OBJ.pwd
			%
			% This function also accepts name/value pairs that modify its behavior:
			% Parameter (default)      | Description
			% -------------------------------------------------------------------------
			% 'CreatePath' (1)         | Create the path if it does not exist
			% 
			% See also: NAMEVALUEPAIR 

				CreatePath = 1;
				assign(varargin{:});

		end % setpwd()

	end % methods nsd_database
end


