classdef ndi_document
	%NDI_DOCUMENT - NDI_database storage item, general purpose data and parameter storage
	% The NDI_DOCUMENT datatype for storing results in the NDI_DATABASE
	%

	properties (SetAccess=protected,GetAccess=public)
		document_properties % a struct with the fields for the document
	end

	methods
		function ndi_document_obj = ndi_document(document_type, varargin)
			% NDI_DOCUMENT - create a new NDI_DATABASE object
			%
			% NDI_DOCUMENT_OBJ = NDI_DOCUMENT(DOCUMENT_TYPE, 'PARAM1', VALUE1, ...)
			%   or
			% NDI_DOCUMENT_OBJ = NDI_DOCUMENT(MATLAB_STRUCT)
			%
			%

				if nargin<1,
					document_type = 'ndi_document';
				end

				if isstruct(document_type),
					document_properties = document_type;
				else,  % create blank from definitions
					document_properties = ndi_document.readblankdefinition(document_type);
					document_properties.ndi_document.id = ndi_unique_id;
					document_properties.ndi_document.datestamp = char(datetime('now','TimeZone','UTCLeapSeconds'));

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

		end % ndi_document() creator

		function b = validate(ndi_document_obj)
			% VALIDATE - 0/1 evaluate whether NDI_DOCUMENT object is valid by its schema
			% 
			% B = VALIDATE(NDI_DOCUMENT_OBJ)
			%
			% Checks the fields of the NDI_DOCUMENT object against the schema in 
			% NDI_DOCUMENT_OBJ.ndi_core_properties.validation_schema and returns 1
			% if the object is valid and 0 otherwise.
				b = 1; % for now, skip this
		end % validate()

		function uid = doc_unique_id(ndi_document_obj)
			% DOC_UNIQUE_ID - return the document unique identifier for an NDI_DOCUMENT
			% 
			% UID = DOC_UNIQUE_ID(NDI_DOCUMENT_OBJ)
			%
			% Returns the unique id of an NDI_DOCUMENT
			% (Found at NDI_DOCUMENT_OBJ.documentproperties.ndi_document.id)
			%
				warning('depricated..use ID() instead')
				uid = ndi_document_obj.document_properties.ndi_document.id;
		end % doc_unique_id()

		function uid = id(ndi_document_obj)
			% ID - return the document unique identifier for an NDI_DOCUMENT
			%
			% UID = ID (NDI_DOCUMENT_OBJ)
			%
			% Returns the unique id of an NDI_DOCUMENT
			% (Found at NDI_DOCUMENT_OBJ.documentproperties.ndi_document.id)
			%
				uid = ndi_document_obj.document_properties.ndi_document.id;
		end; % id()

		function ndi_document_obj = setproperties(ndi_document_obj, varargin)
			% SETPROPERTIES - Set property values of an NDI_DOCUMENT object
			%
			% NDI_DOCUMENT_OBJ = SETPROPERTIES(NDI_DOCUMENT_OBJ, 'PROPERTY1', VALUE1, ...)
			%
			% Sets the property values of NDI_DOCUMENT_OBJ.	PROPERTY values should be expressed
			% relative to NDI_DOCUMENT_OBJ.document_properties (see example).
			%
			% See also: NDI_DOCUMENT, NDI_DOCUMENT/NDI_DOCUMENT		
			%
			% Example:
			%   mydoc = mydoc.setproperties('ndi_document.name','mydoc name');

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

		function ndi_document_obj_out = plus(ndi_document_obj_a, ndi_document_obj_b)
			% PLUS - merge two NDI_DOCUMENT objects
			%
			% NDI_DOCUMENT_OBJ_OUT = PLUS(NDI_DOCUMENT_OBJ_A, NDI_DOCUMENT_OBJ_B)
			%
			% Merges the NDI_DOCUMENT objects A and B. First, the 'document_class'
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
					ndi_document_obj_out.document_properties.depends_on = cat(1,...
						ndi_document_obj_out.document_properties.depends_on(:),...
						ndi_document_obj_b.document_properties.depends_on(:));
						otherproperties = rmfield(otherproperties,'depends_on');
				end;

				% Step 3): Merge the other fields
				ndi_document_obj_out.document_properties = structmerge(ndi_document_obj_out.document_properties,...
					otherproperties);
		end; % plus() 

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
				assign(varargin{:});

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

		function ndi_document_obj = set_dependency_value(ndi_document_obj, dependency_name, value, varargin)
			% SET_DEPENDENCY_VALUE - return dependency value given dependency name
			%
			% NDI_DOCUMENT_OBJ = SET_DEPENDENCY_VALUE(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
			%
			% Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
			% and, if there is a dependency with a given 'dependency_name', then the value of the
			% dependency is set to DEPENDENCY_VALUE. 
			% field (either 'depends_on' or 'name'), then D is empty and an error is generated.
			%
			% This function accepts name/value pairs that alter its default behavior:
			% Parameter (default)      | Description
			% -----------------------------------------------------------------
			% ErrorIfNotFound (1)      | If 1, generate an error if the entry is
			%                          |   not found. Otherwise, generate no error but take no action.
			%
			%
				ErrorIfNotFound = 1;
				assign(varargin{:});

				notfound = 1;

				hasdependencies = isfield(ndi_document_obj.document_properties,'depends_on');

				if hasdependencies,
					matches = find(strcmpi(dependency_name,{ndi_document_obj.document_properties.depends_on.name}));
					if numel(matches)>0,
						notfound = 0;
						ndi_document_obj.document_properties.depends_on(matches(1)).value = value;
					end;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function b = eq(ndi_document_obj1, ndi_document_obj2)
			% EQ - are two NDI_DOCUMENT objects equal?
			%
			% B = EQ(NDI_DOCUMENT_OBJ1, NDI_DOCUMENT_OBJ2)
			%
			% Returns 1 if and only if the objects have identical document_properties.ndi_document.id
			% fields.
			%
				b = strcmp(ndi_document_obj1.document_properties.ndi_document.id,...
					ndi_document_obj2.document_properties.ndi_document.id);
		end; % eq()

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
					s = emptystruct;
				end

				% Step 1): read the information we have here

				t = ndi_document.readjsonfilelocation(jsonfilelocationstring);
				j = jsondecode(t);

				% Step 2): integrate the new information into the document we are building onto 

				% Step 2a): Do we need to integrate this or do we already have same class and at least as good of a version?
				need_to_integrate = 1;
				if isfield(s,'document_superclass_data') & isfield(j,'document_class'),
					% dev note: assuming document_superclass_data reads correctly by matlab jsondecode as STRUCT 
					for k=1:numel(s.document_superclass_data)
						item = celloritem(s.document_superclass_data,k);
						if strcmp(j.document_class.class_name,item.class_name) & j.document_class.class_version<=item.class_version,
							need_to_integrate = 0;
							break;
						end 
					end
				end

				% Step 2b): Now integate if we need to

				if isfield(j,'document_superclass_data'),
					error(['Newly built object should not have field ''document_superclass_data''.']);
				end

				if need_to_integrate,
					if isempty(s),
						s(1).document_class = j.document_class;
						s(1).document_superclass_data = {};
					else,
						s(1).document_superclass_data{end+1} = j.document_class;
					end
					j_ = rmfield(j, 'document_class');
					if isfield(s,'depends_on') & isfield(j_,'depends_on'),
						s.depends_on = cat(1,s.depends_on(:),j_.depends_on(:));
						j_ = rmfield(j,'depends_on');
					end;
					s = structmerge(s, j_);
				else,
					return;
				end

				if isfield(j,'document_class'),
					if isfield(j.document_class,'superclasses'),
						for i=1:numel(j.document_class.superclasses),
							item = celloritem(j.document_class.superclasses, i, 1);
							s = ndi_document.readblankdefinition(item.definition, s);
						end
					end
				end

				if s_is_empty, % discard document_superclass_data
					s = rmfield(s,'document_superclass_data');
				end
		
		end % readblankdefinition() 

		function t = readjsonfilelocation(jsonfilelocationstring)
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
				ndi_globals;

				searchString = '$NDIDOCUMENTPATH';
				s = strfind(jsonfilelocationstring, searchString);
				if ~isempty(s), % insert the location
					filename = [ndidocumentpath filesep ...
						filesepconversion(jsonfilelocationstring(s+numel(searchString):end), ndi_filesep, filesep)];
				else,
					% first, guess that it is a complete path from $NDIDOCUMENTPATH
					filename = [ndidocumentpath filesep filesepconversion(jsonfilelocationstring,ndi_filesep,filesep)];
					if ~exist(filename,'file'),
						% try adding extension
						filename = [filename '.json'];
					end;
					if ~exist(filename,'file'), 
						filename = jsonfilelocationstring;
						[p,n,e] = fileparts(filename);
						if isempty(e),
							filename = [filename '.json'];
						end;
						if ~exist(filename,'file'),
							filename2 = [ndidocumentpath filesep filename];
							if ~exist(filename2,'file'),
								error(['Cannot find file ' filename '.']);
							else,
								filename = filename2;
							end;
						end;
					end;
				end;

				% filename could be url or filename

				if isurl(filename),
					t = urlread(filename);
				else,
					t = textfile2char(filename);
				end
		end

	end % methods Static
end % classdef

