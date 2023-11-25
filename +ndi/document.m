classdef document
	%NDI.DOCUMENT - NDI_database storage item, general purpose data and parameter storage
	% The ndi.document datatype for storing results in the ndi.database
	%

	properties (SetAccess=protected,GetAccess=public)
		document_properties % a struct with the fields for the document
	end

	methods
		function ndi_document_obj = document(document_type, varargin)
			% ndi.document - create a new ndi.database object
			%
			% NDI_DOCUMENT_OBJ = ndi.document(DOCUMENT_TYPE, 'PARAM1', VALUE1, ...)
			%   or
			% NDI_DOCUMENT_OBJ = ndi.document(MATLAB_STRUCT)
			%
			%
				if nargin<1,
					document_type = 'base';
				end

				if isstruct(document_type),
					document_properties = document_type;
				elseif isa(document_type,'did.document'),
					document_properties = document_type.document_properties; % directly compatible
				else,  % create blank from definitions
					document_properties = ndi.document.readblankdefinition(document_type);
					ndiido = ndi.ido();
					document_properties.base.id = ndiido.id();
					document_properties.base.datestamp = ndi.fun.timestamp();

					if numel(varargin)==1, % see if user put it all as one cell array
						if iscell(varargin{1}),
							varargin = varargin{1};
						end
					end
					if mod(numel(varargin),2)~=0,
						error(['Variable inputs must be name/value pairs'.']);
					end;

					for i=1:2:numel(varargin), % assign variable arguments
						try,
							eval(['document_properties.' varargin{i} '= varargin{i+1};']);
						catch,
							error(['Could not assign document_properties.' varargin{i} '.']);
						end
					end
				end

				ndi_document_obj.document_properties = document_properties;

		end % ndi.document() creator

		function ndi_document_obj = add_dependency_value_n(ndi_document_obj, dependency_name, value, varargin)
			% ADD_DEPENDENCY_VALUE_N - add a dependency to a named list
			%
			% NDI_DOCUMENT_OBJ = ADD_DEPENDENCY_VALUE_N(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
			%
			% Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
			% and adds a dependency name 'dependency_name_(n+1)', where n is the number of entries with
			% the form 'depenency_name_i' that exist presently. If there is no dependency field with that, then
			% an entry is added and i is 1.
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNotFound (1)      | If 1, generate an error if the entry is
			%                          |   not found. Otherwise, generate no error but take no action.
			%
			%
				ErrorIfNotFound = 1;
				vlt.data.assign(varargin{:});


				d = dependency_value_n(ndi_document_obj, dependency_name, 'ErrorIfNotFound', 0);
				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');
				if ~hasdependencies & ErrorIfNotFound,
					error(['This document does not have any dependencies.']);
				else,
					d_struct = struct('name',[dependency_name '_' int2str(numel(d)+1)],'value',value);
					ndi_document_obj = set_dependency_value(ndi_document_obj, d_struct.name, d_struct.value, 'ErrorIfNotFound', 0);
				end;
		end; % 

		function ndi_document_obj = add_file(ndi_document_obj, name, location, varargin)
			% ADD_FILE - add a file to a ndi.document
			%
			% DID_DOCUMENT_OBJ = ADD_FILE(NDI_DOCUMENT_OBJ, NAME, LOCATION, ...)
			%
			% Adds a file's information to a ndi.document, for later ingestion into
			% the database. NAME is the name of the file record for the document.
			% LOCATION is a string that identifies the file or URL location on the
			% internet.
			%
			% Note: NAME must not include any file separator characters on any
			% platform (':','\','/') and may not have leading or trailing spaces.
			% Leading or trailing spaces will be trimmed.
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ingest (1 or 0)          | 0/1 Should the file be copied into the local
			%                          |   database by ndi.database.add_doc() ?
			%                          |   If LOCATION does not begin with 'http://' or
			%                          |   'https://', then ingest is 1 by default.
			%                          |   If LOCATION begins with 'http(s)://', then
			%                          |   ingest is 0 by default. Note that the file
			%                          |   is only copied upon the later call to
			%                          |   ndi.database.add_doc(), not at the call to
			%                          |   ndi.document.add_file().
			% delete_original (1 or 0) | 0/1 Should we delete the file after ingestion?
			%                          |   If LOCATION does not begin with 'http://' or
			%                          |   'https://', then delete_original is 1 by default.
			%                          |   If LOCATION begins with 'http(s)://', then
			%                          |   delete_original is 0 by default. Note that the
			%                          |   file is only deleted upon the later call to
			%                          |   ndi.database.add_doc(), not at the call to
			%                          |   ndi.document.add_file().
			% location_type ('file' or | Can be 'file' or 'url'. By default, it is set
			%   'url')                 |   to 'file' if LOCATION does not begin with
			%                          |   'http://' or 'https://', and 'url' otherwise.
			%
				ingest = NaN;
				delete_original = NaN;
				location_type = NaN;
				uid = did.ido.unique_id();

				did.datastructures.assign(varargin{:});
				% Step 1: make sure that the did_document_obj has a 'files' portion
				% and that name is one of the listed files.

				[b,msg,fI_index] = ndi_document_obj.is_in_file_list(name);
				if ~b,
					error(msg);
				end;
	
				% Step 2: detect the default property values, if necessary, and build the structure
				detected_location_type = 'file'; % default
				location = strip(location);  % remove whitespace
				if (startsWith(location,'https://','IgnoreCase',true) | startsWith(location,'http://','IgnoreCase',true)),
					detected_location_type = 'url';
				end;

				if isnan(ingest), % assign default value
					switch detected_location_type,
						case 'url',
							ingest = 0;
						case 'file',
							ingest = 1;
						otherwise,
							error(['Unknown detected_location_type ' detected_location_type '.']);
					end;
				end;
				if isnan(delete_original), % assign default value
					switch detected_location_type,
						case 'url',
							delete_original = 0;
						case 'file',
							delete_original = 1;
						otherwise,
							error(['Unknown detected_location_type ' detected_location_type '.']);
					end;
				end;
				if isnan(location_type), % assign default value
					location_type = detected_location_type;
				end;

				% Step 2b: build the structure to add
				
				parameters = '';

				location_here = did.datastructures.var2struct('delete_original','uid','location',...
					'parameters','location_type','ingest');

				% Step 3: Add the file to the list

				if isempty(fI_index), 
					file_info_here = struct('name',name,'locations',location_here);
					if ~isfield(ndi_document_obj.document_properties.files,'file_info'),
						ndi_document_obj.document_properties.files.file_info = file_info_here;
					else,
						fI_index = numel(ndi_document_obj.document_properties.files.file_info)+1;
						ndi_document_obj.document_properties.files.file_info(fI_index) = file_info_here;
					end;
				else,
					ndi_document_obj.document_properties.files.file_info(fI_index).locations(end+1) = location_here; 
				end;
				
		end; % add_file

		function [names, depend_struct] = dependency(ndi_document_obj)
			% DEPENDENCY - return names and a structure with all dependencies for an ndi.object
			%
			% [NAMES, DEPEND_STRUCT] = DEPENDENCY(NDI_DOCUMENT_OBJ)
			%
			% Returns in the cell array NAMES the 'name' of all 'depends_on' entries in the ndi.document NDI_DOCUMENT_OBJ.
			% Further, this function returns a structure with all 'name' and 'value' entries in DEPEND_STRUCT.
			%
				names = {};
				depend_struct = vlt.data.emptystruct('name','value');
				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');
				if hasdependencies, 
					names = {ndi_document_obj.document_properties.depends_on.name};
					depend_struct = ndi_document_obj.document_properties.depends_on;
				end;
		end; % dependency()

		function d = dependency_value(ndi_document_obj, dependency_name, varargin)
			% DEPENDENCY_VALUE - return dependency value given dependency name
			%
			% D = DEPENDENCY_VALUE(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, ...)
			%
			% Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
			% and returns the 'value' associated with the given 'name'. If there is no such
			% field (either 'depends_on' or 'name'), then D is empty and an error is generated.
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNotFound (1)      | If 1, generate an error if the entry is
			%                          |   not found. Otherwise, return empty.
			%
			%
				ErrorIfNotFound = 1;
				vlt.data.assign(varargin{:});

				d = [];
				notfound = 1;

				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');

				if hasdependencies,
					matches = find(strcmpi(dependency_name,{ndi_document_obj.document_properties.depends_on.name}));
					if numel(matches)>0,
						notfound = 0;
						d = getfield(ndi_document_obj.document_properties.depends_on(matches(1)),'value');
					end;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function d = dependency_value_n(ndi_document_obj, dependency_name, varargin)
			% DEPENDENCY_VALUE_N - return dependency values from list given dependency name
			%
			% D = DEPENDENCY_VALUE_N(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, ...)
			%
			% Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
			% and returns the 'values' associated with the given 'name_i', where i varies from 1 to the
			% maximum number of entries titled 'name_i'. If there is no such field (either
			% 'depends_on' or 'name_i'), then D is empty and an error is generated.
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNotFound (1)      | If 1, generate an error if the entry is
			%                          |   not found. Otherwise, return empty.
			%
			%
				ErrorIfNotFound = 1;
				vlt.data.assign(varargin{:});

				d = {};
				notfound = 1;

				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');
				if hasdependencies, 
					hasdependencies = numel(ndi_document_obj.document_properties.depends_on)>=1;
				end;

				if hasdependencies,
					finished = 0;
					i = 1;
					while ~finished,
						matches = find(strcmpi([dependency_name '_' int2str(i)],{ndi_document_obj.document_properties.depends_on.name}));
						if numel(matches)>0,
							notfound = 0;
							d{i} = getfield(ndi_document_obj.document_properties.depends_on(matches(1)),'value');
						end;
						finished = numel(matches)==0;
						i = i + 1;
					end;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function b = doc_isa(ndi_document_obj, document_class)
			% DOC_ISA - is an ndi.document a member of a particular document_class?
			%
			% B = DOC_ISA(NDI_DOCUMENT_OBJ, DOCUMENT_CLASS)
			%
			% Returns 1 if NDI_DOCUMENT_OBJ or one of its superclasses is a match
			% for DOCUMENT_CLASS. Otherwise returns 0.
			%
				sc = ndi_document_obj.doc_superclass();
				c = ndi_document_obj.doc_class();
				b = any(strcmp(document_class, cat(1,c(:),sc(:))));
		end; % doc_isa()

		function c = doc_class(ndi_document_obj)
			% DOC_CLASS what is the document class type of an ndi.document object?
			%
			% C = DOC_CLASS(NDI_DOCUMENT_OBJ)
			%
			% Returns the document class of an ndi.document.
			% (Found at ndi_document_obj.document_properties.document_class.class_name)
			%	
				c = ndi_document_obj.document_properties.document_class.class_name;
		end; % doc_class()

		function sc = doc_superclass(ndi_document_obj)
			% DOC_SUPERCLASS - return the document superclasses of an ndi.document object
			%
			% SC = DOC_SUPERCLASS(NDI_DOCUMENT_OBJ)
			%
			% Returns the document superclasses of an ndi.document object. SC is a cell
			% array of strings.
			%
				sc = {};
				for i=1:numel(ndi_document_obj.document_properties.document_class.superclasses),
					s = ndi.document(ndi_document_obj.document_properties.document_class.superclasses(i).definition);
					sc{i} = s.doc_class();
				end;
				sc = unique(sc); % alphabetize and remove any duplicates
		end; % doc_superclass

		function uid = doc_unique_id(ndi_document_obj)
			% DOC_UNIQUE_ID - return the document unique identifier for an ndi.document
			% 
			% UID = DOC_UNIQUE_ID(NDI_DOCUMENT_OBJ)
			%
			% Returns the unique id of an ndi.document
			% (Found at NDI_DOCUMENT_OBJ.documentproperties.base.id)
			%
				warning('depricated..use ID() instead')
				uid = ndi_document_obj.document_properties.base.id;
		end % doc_unique_id()

		function b = eq(ndi_document_obj1, ndi_document_obj2)
			% EQ - are two ndi.document objects equal?
			%
			% B = EQ(NDI_DOCUMENT_OBJ1, NDI_DOCUMENT_OBJ2)
			%
			% Returns 1 if and only if the objects have identical document_properties.base.id
			% fields.
			%
				b = strcmp(ndi_document_obj1.document_properties.base.id,...
					ndi_document_obj2.document_properties.base.id);
		end; % eq()

		function uid = id(ndi_document_obj)
			% ID - return the document unique identifier for an ndi.document
			%
			% UID = ID (NDI_DOCUMENT_OBJ)
			%
			% Returns the unique id of an ndi.document
			% (Found at NDI_DOCUMENT_OBJ.documentproperties.base.id)
			%
				uid = ndi_document_obj.document_properties.base.id;
		end; % id()

		function [b, msg, fI_index] = is_in_file_list(ndi_document_obj, name)
			% IS_IN_FILE_LIST - is a file name in a ndi.document's file list?
			%
			% [B, MSG, FI_INDEX] = IS_IN_FILE_LIST(NDI_DOCUMENT_OBJ, NAME)
			%
			% Is the file NAME a valid named binary file for the ndi.document
			% NDI_DOCUMENT_OBJ? If so, B is 1; else, B is 0.
			%
			% A name is a valid name if it appears in NDI_DOCUMENT_OBJ....
			% document_properties.files.file_list or if it is a numbered
			% file with an entry in document_properties.files.file_list
			% as 'filename.ext_#'. (For example, 'filename.ext_1' would
			% be valid if 'filename.ext_# is in the file_list.)
			%
			% If the file NAME is not valid, a reason is returned in MSG.
			%
			% If it is a valid file NAME, then the index value of NAME
			% in NDI_DOCUMENT_OBJ.DOCUMENT_PROPERTIES.FILES.FILE_INFO is also
			% returned.
			% 
				b = 1;
				msg = '';
				fI_index = [];

				% Step 1: does this did.document have 'files' at all?

				if ~isfield(ndi_document_obj.document_properties,'files'),
					b = 0;
					msg = 'This type of document does not accept files; it has no ''files'' field';
					return;
				end;

				% Step 2: is it a valid filename for this document? It must appear in files.file_list
				%   or be a proper numbered file if files.file_list{i} has has the form 'filename.ext_#'.

				% Step 2a: see if name ends in '_#', where # is a non-negative integer.
				
				search_name = name;
				ends_with_number = 0; % assume not at first
				number = NaN;
				underscores = find(name=='_');
				if ~isempty(underscores),
					n = str2num(name(underscores(end)+1:end));
					if ~isempty(n), % we have a number
						number = n;
						ends_with_number = 1;
						search_name = [name(1:underscores(end)) '#'];
					end;
				end;

				% Step 2b: now we have the name to search for; make sure it is in the file list
				
				I = find(strcmpi(search_name,ndi_document_obj.document_properties.files.file_list));
				if isempty(I),
					b = 0;
					msg = ['No such file ' name ' in file_list of ndi.document; file must match an expected name.'];
					return;
				end;

				% Step 3: now, find which file_info corresponds to search_name, if any
				
				if isfield(ndi_document_obj.document_properties.files,'file_info'),
					fI_index = find(strcmpi(name,{ndi_document_obj.document_properties.files.file_info.name}));
				end;
		end; % is_in_file_list() 

		function ndi_document_obj_out = plus(ndi_document_obj_a, ndi_document_obj_b)
			% PLUS - merge two ndi.document objects
			%
			% NDI_DOCUMENT_OBJ_OUT = PLUS(NDI_DOCUMENT_OBJ_A, NDI_DOCUMENT_OBJ_B)
			%
			% Merges the ndi.document objects A and B. First, the 'document_class'
			% superclasses are merged. Then, the fields that are in B but are not in A
			% are added to A. The result is returned in NDI_DOCUMENT_OBJ_OUT.
			% Note that any fields that A has that are also in B will be preserved; no elements of
			% those fields of B will be combined with A.
			%
				ndi_document_obj_out = ndi_document_obj_a;
				% Step 1): Merge superclasses
				ndi_document_obj_out.document_properties.document_class.superclasses = ...
					(cat(1,ndi_document_obj_out.document_properties.document_class.superclasses,...
						ndi_document_obj_b.document_properties.document_class.superclasses));
				otherproperties = rmfield(ndi_document_obj_b.document_properties, 'document_class');

				% Step 2): Merge dependencies if we have to
				if isfield(ndi_document_obj_out.document_properties,'depends_on') & ...
					isfield(ndi_document_obj_b.document_properties,'depends_on'), 
					% we need to merge dependencies
					for k=1:numel(ndi_document_obj_b.document_properties.depends_on),
						tf = strcmp(ndi_document_obj_b.document_properties.depends_on(k).name,...
							{ndi_document_obj_out.document_properties.depends_on.name});
						if any(tf),
							index = find(tf);
							index = index(1);
							ndi_document_obj_out.document_properties.depends_on(index) =  ...
								ndi_document_obj_b.document_properties.depends_on(k);
						else,
							ndi_document_obj_out.document_properties.depends_on(end+1) = ...
								ndi_document_obj_b.document_properties.depends_on(k);
						end;
					end;
					otherproperties = rmfield(otherproperties,'depends_on');

				end;

				% Step 3): Merge file_list
				if isfield(ndi_document_obj_b.document_properties,'files'),
					% does doc a also have it?
					if isfield(ndi_document_obj_out.document_properties,'files'),
						file_list = cat(2,ndi_document_obj_out.document_properties.files.file_list(:)', ...
							ndi_document_obj_b.document_properties.files.file_list(:)');
						file_info = cat(1,ndi_document_obj_out.document_properties.files.file_info(:),...
							ndi_document_obj_b.document_properties.files.file_info(:));
						if numel(unique(file_list))~=numel(file_list),
							error(['Documents have files of the same name. Cannot be combined.']);
						end;
						ndi_document_obj_out.document_properties.files.file_list = file_list;
						ndi_document_obj_out.document_properties.files.file_info = file_info;
					else, 
						% doc a doesn't have it, just use doc b's info
						ndi_document_obj_out.document_properties.files = ndi_document_obj_b.document_properties.files;
					end;
				end;

				% Step 4): Merge the other fields
				ndi_document_obj_out.document_properties = vlt.data.structmerge(ndi_document_obj_out.document_properties,...
					otherproperties);
		end; % plus() 

		function ndi_document_obj = remove_dependency_value_n(ndi_document_obj, dependency_name, value, n, varargin)
			% REMOVE_DEPENDENCY_VALUE_N - remove a dependency from a named list
			%
			% NDI_DOCUMENT_OBJ = REMOVE_DEPENDENCY_VALUE_N(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, N, ...)
			%
			% Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
			% and removes the dependency name 'dependency_name_(n)'.
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNotFound (1)      | If 1, generate an error if the entry is
			%                          |   not found. Otherwise, generate no error but take no action.
			%
			%
				ErrorIfNotFound = 1;
				vlt.data.assign(varargin{:});

				d = dependency_value_n(ndi_document_obj, dependency_name, 'ErrorIfNotFound', 0);
				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');
				if ~hasdependencies & ErrorIfNotFound,
					error(['This document does not have any dependencies.']);
				end;

				if n>numel(d) & ErrorIfNotFound,
					error(['Number to be removed ' int2str(n) ' is greater than total number of entries ' int2str(numel(d)) '.']);
				end;

				match = find(strcmpi([dependency_name '_' int2str(n)],{ndi_document_obj.document_properties.depends_on.name}));
				if numel(match)~=1,
					error(['Could not locate entry ' dependency_name '_' int2str(n)]);
				end;

				ndi_document_obj.document_properties.depends_on = ndi_document_obj.document_properties.depends_on([1:match-1 match+1:end]);

				for i=n+1:numel(d),
					match = find(strcmpi([dependency_name '_' int2str(i)],{ndi_document_obj.document_properties.depends_on.name}));
					if numel(match)~=1,
						error(['Could not locate entry ' dependency_name '_' int2str(i)]);
					end;
					ndi_document_obj.document_properties.depends_on(match).name = [dependency_name '_' int2str(i-1)];
				end;
		end; % 

		function ndi_document_obj = set_dependency_value(ndi_document_obj, dependency_name, value, varargin)
			% SET_DEPENDENCY_VALUE - set the value of a dependency field
			%
			% NDI_DOCUMENT_OBJ = SET_DEPENDENCY_VALUE(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
			%
			% Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
			% and, if there is a dependency with a given 'dependency_name', then the value of the
			% dependency is set to DEPENDENCY_VALUE. 
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNotFound (1)      | If 1, generate an error if the entry is
			%                          |   not found. Otherwise, add it.
			%
			%
				ErrorIfNotFound = 1;
				vlt.data.assign(varargin{:});

				notfound = 1;

				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');
				if hasdependencies, 
					hasdependencies = numel(ndi_document_obj.document_properties.depends_on)>=1;
				end;
				d_struct = struct('name',dependency_name,'value',value);

				if hasdependencies,
					matches = find(strcmpi(dependency_name,{ndi_document_obj.document_properties.depends_on.name}));
					if numel(matches)>0,
						notfound = 0;
						ndi_document_obj.document_properties.depends_on(matches(1)).value = value;
					elseif ~ErrorIfNotFound, % add it
						ndi_document_obj.document_properties.depends_on(end+1) = d_struct;
					end;
				elseif ~ErrorIfNotFound,
					ndi_document_obj.document_properties.depends_on = d_struct;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function ndi_document_obj = remove_file(ndi_document_obj, name, location, varargin)
			% REMOVE_FILE - remove file information from a did.document
			%
			% DID_DOCUMENT_OBJ = REMOVE_FILE(NDI_DOCUMENT_OBJ, NAME, [LOCATION], ...)
			%
			% Removes the file information for a name or a name and location 
			% combination from a did.document() object.
			%
			% If LOCATION is not specified or is empty, then all locations are removed.
			%
			% If NDI_DOCUMENT_OBJ does not have a file NAME in its file_list, then an erorr is
			% generated. 
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNoFileInfo (0)    | 0/1 If a name is specified and the
			%                          |   file info is already empty, should we
			%                          |   produce an error?

				if nargin<3,
					location = [];
				end;

				ErrorIfNoFileInfo = 0;
				did.datastructures.assign(varargin{:});
				
				[b,msg,fI_index] = ndi_document_obj.is_in_file_list(name);
				if ~b,
					error(msg);
				end;

				if isempty(fI_index),
					if ErrorIfNoFileInfo,
						error(['No file_info for name ' name ' .']);
					end;
				end;

				if isempty(location),
					ndi_document_obj.document_properties.files.file_info(fI_index) = [];
					return;
				end;

				location_match_index = find(strcmpi(location,{ndi_document_obj.document_properties.files.file_info(fI_index).locations.location}));

				if isempty(location_match_index),
					if ErrorIfNoFileInfo,
						error(['No match found for file ' name ' with location ' location '.']);
					end;
				else,
					ndi_document_obj.document_properties.files.file_info(fI_index).locations = ...
						ndi_document_obj.document_properties.files.file_info(fI_index).locations([1:location_match_index-1 location_match_index+1:end]);
				end;

		end; % remove_file


		function ndi_document_obj = reset_file_info(did_document_obj)
			% RESET_FILE_INFO - reset the file information parameters for a new did.document
			%
			% NDI_DOCUMENT_OBJ = RESET_FILE_INFO(NDI_DOCUMENT_OBJ)
			%
			% Reset (make empty) all file info structures for a new did.document object.
			%
			% Sets document_properties.files.file_info to an empty structure
			%
				
				% First, check if we even have file info
				if ~isfield(did_document_obj.document_properties,'files'), 
					return;
				end;

				% Now, clear it out:
				did_document_obj.document_properties.files.file_info = ...
					did.datastructures.emptystruct('name','locations');

		end; % reset_file_info()

		function ndi_document_obj = setproperties(ndi_document_obj, varargin)
			% SETPROPERTIES - Set property values of an ndi.document object
			%
			% NDI_DOCUMENT_OBJ = SETPROPERTIES(NDI_DOCUMENT_OBJ, 'PROPERTY1', VALUE1, ...)
			%
			% Sets the property values of NDI_DOCUMENT_OBJ.	PROPERTY values should be expressed
			% relative to NDI_DOCUMENT_OBJ.document_properties (see example).
			%
			% See also: ndi.document, ndi.document/ndi.document		
			%
			% Example:
			%   mydoc = mydoc.setproperties('base.name','mydoc name');

				newproperties = ndi_document_obj.document_properties;
				for i=1:2:numel(varargin),
					try,
						eval(['newproperties.' varargin{i} '=varargin{i+1};']);
					catch,
						error(['Error in assigning ' varargin{i} '.']);
					end
				end
				
				ndi_document_obj.document_properties = newproperties;
		end; % setproperties

		function b = validate(ndi_document_obj)
			% VALIDATE - 0/1 evaluate whether ndi.document object is valid by its schema
			% 
			% B = VALIDATE(NDI_DOCUMENT_OBJ)
			%
			% Checks the fields of the ndi.document object against the schema in 
			% NDI_DOCUMENT_OBJ.ndi_core_properties.validation_schema and returns 1
			% if the object is valid and 0 otherwise.
				b = 1; % for now, skip this
		end % validate()

	end % methods


	methods (Static)
		function s = readblankdefinition(jsonfilelocationstring, s)
			% READBLANKDEFINITION - read a blank JSON class definitions from a file location string
			%
			% S = READBLANKDEFINITION(JSONFILELOCATIONSTRING)
			%
			% Given a JSONFILELOCATIONSTRING, this function creates a blank document using the JSON definitions.
			%
			% A JSONFILELOCATIONSTRING can be:
			%	a) a url
			%	b) a filename (full path)
			%       c) a filename referenced with respect to $NDIDOCUMENTPATH
			%
			% See also: READJSONFILELOCATION
			%
				s_is_empty = 0;
				if nargin<2,
					s_is_empty = 1;
					s = vlt.data.emptystruct;
				end

				% Step 1): read the information we have here

				t = ndi.document.readjsonfilelocation(jsonfilelocationstring);
				j = jsondecode(t);
				s = j; 

				% Step 2): read the information about all the superclasses

				s_super = {};

				if isfield(j,'document_class'),
					if isfield(j.document_class,'superclasses'),
						for i=1:numel(j.document_class.superclasses),
							item = vlt.data.celloritem(j.document_class.superclasses, i, 1);
							s_super{end+1} = ndi.document.readblankdefinition(item.definition);
						end
					end
				end

				% Step 2): integrate the superclasses into the document we are building

				for i=1:numel(s_super),
					% merge s and s_super{i}
					% part 1: do we need to merge superclass labels?
					if isfield(s,'document_class')&isfield(s_super{i},'document_class'),
						s.document_class.superclasses = cat(1,s.document_class.superclasses(:),...
							s_super{i}.document_class.superclasses(:));
						[dummy,unique_indexes] = unique({s.document_class.superclasses.definition});
						s.document_class.superclasses = s.document_class.superclasses(unique_indexes);
					else,
						error(['Documents lack ''document_class'' fields.']);
					end;

					s_super{i} = rmfield(s_super{i},'document_class');

					% part 2: merge dependencies
					if isfield(s,'depends_on') & isfield(s_super{i},'depends_on'), % if only s or super_s has it, merge does it right
						s.depends_on = cat(1,s.depends_on(:),s_super{i}.depends_on(:));
						s_super{i} = rmfield(s_super{i},'depends_on');
						[dummy,unique_indexes] = unique({s.depends_on.name});
						s.depends_on= s.depends_on(unique_indexes);
					else,
						% regular vlt.data.structmerge is fine, will use 'depends_on' field of whichever structure has it, or none
					end;
					s = vlt.data.structmerge(s,s_super{i});
				end;
		end % readblankdefinition() 

		function t = readjsonfilelocation_orig(jsonfilelocationstring)
			% READJSONFILELOCATION - return the text from a json file location string in NDI
			%
			% T = READJSONFILELOCATION(JSONFILELOCATIONSTRING)
			%
			% A JSONFILELOCATIONSTRING can be:
			%      a) a url
			%      b) a filename (full path)
			%      c) a relative filename with respect to $NDIDOCUMENTPATH
			%      d) a filename referenced with respect to $NDIDOCUMENTPATH
			%
				ndi.globals;

				searchString = '$NDIDOCUMENTPATH';
				s = strfind(jsonfilelocationstring, searchString);
				if ~isempty(s), % insert the location
					filename = [ndi_globals.path.documentpath filesep ...
						vlt.file.filesepconversion(jsonfilelocationstring(s+numel(searchString):end), ndi.filesep, filesep)];
				else,
					% first, guess that it is a complete path from $NDIDOCUMENTPATH
					filename = [ndi_globals.path.documentpath filesep vlt.file.filesepconversion(jsonfilelocationstring,ndi.filesep,filesep)];
					if ~vlt.file.isfile(filename),
						% try adding extension
						filename = [filename '.json'];
					end;
					if ~vlt.file.isfile(filename),
						filename = jsonfilelocationstring;
						[p,n,e] = fileparts(filename);
						if isempty(e),
							filename = [filename '.json'];
						end;
						if ~vlt.file.isfile(filename),
							filename2 = [ndi_globals.path.documentpath filesep filename];
							if ~vlt.file.isfile(filename2),
								error(['Cannot find file ' filename '.']);
							else,
								filename = filename2;
							end;
						end;
					end;
				end;

				% filename could be url or filename

				if vlt.file.isurl(filename),
					t = urlread(filename);
				else,
					t = vlt.file.textfile2char(filename);
				end
		end

		function t = readjsonfilelocation(jsonfilelocationstring)
			% READJSONFILELOCATION - return the text from a json file location string in NDI
			%
			% T = READJSONFILELOCATION(JSONFILELOCATIONSTRING)
			%
			% A JSONFILELOCATIONSTRING can be:
			%      a) a url
			%      b) a filename (full path)
			%      c) a filename (full path) but referenced with respect to $NDIDOCUMENTPATH or $NDICALCDOCUMENTPATH
			%      d) a filename without any path that sits beneath $NDIDOCUMENTPATH or $NDICALCDOCUMENTPATH
			%      e) a relative path beneath $NDIDOCUMENTPATH (e.g., daq/ndi_document_filenavigator.json)
			%
				ndi.globals;

				filename = '';

				if vlt.file.isurl(jsonfilelocationstring),
					filename = jsonfilelocationstring;
				end;

				if isempty(filename),
					if vlt.file.isfile(jsonfilelocationstring),
						filename = jsonfilelocationstring;
					end;
				end;

				if isempty(filename),
					searchString = '$NDIDOCUMENTPATH';
					s = strfind(jsonfilelocationstring, searchString);
					if ~isempty(s), % insert the location
						filename = [ndi_globals.path.documentpath filesep ...
							vlt.file.filesepconversion(jsonfilelocationstring(s+numel(searchString):end), ndi.filesep, filesep)];
					end;
				end;

				if isempty(filename), % we need to keep looking
					searchString2 = '$NDICALCDOCUMENTPATH';
					s = strfind(jsonfilelocationstring, searchString2);
					if ~isempty(s), % we need to figure out WHICH $NDICALCDOCUMENT is intended
						match = 0;
						for i=1:numel(ndi_globals.path.calcdoc),
							filename = [ndi_globals.path.calcdoc{i} filesep ...
								vlt.file.filesepconversion(jsonfilelocationstring(s+numel(searchString2):end), ndi.filesep, filesep)];
							if vlt.file.isfile(filename),
								% we have a match
								match = 1;
								break;
							end;
						end;
						if match==0, % we did not find a match
							error(['Could not find any replacement for $NDICALCDOCUMENT.']);
						end;
					end;
				end;

				if isempty(filename), % could be a path relative to $NDIDOCUMENTPATH
					putativefilename = jsonfilelocationstring;
					% now search for filename.json
					if ~endsWith(lower(putativefilename),'.json'),
						putativefilename = [putativefilename '.json'];
					end;
					if vlt.file.isfile([ndi_globals.path.documentpath filesep putativefilename]),
						filename = putativefilename;
					end;
				end;

				if isempty(filename),
					putativefilename = jsonfilelocationstring;
					% now search for filename.json
					if ~endsWith(lower(putativefilename),'.json'),
						putativefilename = [putativefilename '.json'];
					end;
					% first try $NDIDOCUMENTPATH
					filelist = vlt.file.getAllFiles(ndi_globals.path.documentpath);
					for i=1:numel(filelist),
						[parent,name,ext] = fileparts(filelist{i});
						if strcmpi([name ext],[putativefilename]),
							%  we have a match
							filename = filelist{i};
							break;
						end;
					end;
				end;

				if isempty(filename),
					putativefilename = jsonfilelocationstring;
					% now search for filename.json
					if ~endsWith(lower(putativefilename),'.json'),
						putativefilename = [putativefilename '.json'];
					end;
					% next try $NDICALCDOCUMENTPATH
					for a=1:numel(ndi_globals.path.calcdoc),
						filelist = vlt.file.getAllFiles(ndi_globals.path.calcdoc{a});
						for i=1:numel(filelist),
							[parent,name,ext] = fileparts(filelist{i});
							if strcmpi([name ext],[putativefilename]),
								%  we have a match
								filename = filelist{i};
								break;
							end;
						end;
						if isempty(filename),
							break;
						end;
					end;
				end;

				if isempty(filename),
					error(['Cannot resolve file ' jsonfilelocationstring '.']);
				end;

				% filename could be url or filename

				if vlt.file.isurl(filename),
					t = urlread(filename);
				else,
					t = vlt.file.textfile2char(filename);
				end
		end

	end % methods Static
end % classdef

