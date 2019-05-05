classdef ndi_dbleaf < ndi_base
	% NDI_DBLEAF - A node that fits into an NDI_DBLEAF_BRANCH
	%
	%

	properties (GetAccess=public,SetAccess=protected)
		name           % String name; may be any string
		metadatanames  % Cell list of metadata fields
	end % properties

	methods
		function obj = ndi_dbleaf(name, command)
			% NDI_DBLEAF - Creates a named NDI_DBLEAF object
			%
			% OBJ = NDI_DBLEAF(LEAFNAME)
			%
			% Creates an NDI_DBLEAF object with name LEAFNAME. LEAFNAME must be like
			% a valid Matlab variable, although Matlab keywords are allowed.
			% In addition, file separators such as ':', '/', and '\' are not 
			% allowed.
			%
			% In an alternate construction, one may call
			%   OBJ = NDI_DBLEAF(FILENAME, COMMAND)
			% with COMMAND set to 'OpenFile', and the object will be created by
			% reading in data from the file FILENAME (full path). To developers:
			% All NDI_DBLEAF descendents must offer this 2 element constructor.
			%  
			% See also: NDI_DBLEAF_BRANCH

			obj=obj@ndi_base;

			if nargin==0, % undocumented dummy version
				obj = ndi_dbleaf('dummy');
				return;
			end

			if nargin==1,
				command = '';
			end

			if strcmp(lower(command),lower('OpenFile')),
				obj = ndi_dbleaf('dummy');
				obj = obj.readobjectfile(name);
			else,
				if ischar(name)
					obj.name=name;
					% use time and randomness to ensure uniqueness of objectfilename
					obj.objectfilename = [string2filestring(obj.name) '_' obj.objectfilename];
					obj.metadatanames = {'name','objectfilename'};
				else,
					error(['name ' name ' must be a string.']); 
				end
			end

		end % ndi_dbleaf

		function mds = metadatastruct(ndi_dbleaf_obj)
			% METADATASTRUCT - return a structure with metadata for NDI_DBLLEAF_OBJ
			%
			% MDS = METADATASTRUCT(NDI_DBLEAF_OBJ)
			%
			% Returns a structure with field names NDI_DBLEAF_OBJ.metadatanames and
			% values equal to the respective property values of NDI_DBLEAF_OBJ.

			mds = struct;

			for i=1:numel(ndi_dbleaf_obj.metadatanames),
				mds = setfield(mds, ndi_dbleaf_obj.metadatanames{i}, getfield(ndi_dbleaf_obj, ndi_dbleaf_obj.metadatanames{i}) );
			end

		end % metadatastruct

		function [obj,properties_set] = setproperties(ndi_dbleaf_obj, properties, values)
			% SETPROPERTIES - set the properties of an NDI_DBLEAF object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NDI_DBLEAF_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NDI_DBLEAF_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NDI_DBLEAF_OBJ, then 
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NDI_DBLEAF that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NDI_DBLEAF).
			%
				fn = fieldnames(ndi_dbleaf_obj);
				obj = ndi_dbleaf_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						else,
							eval(['obj.' properties{i}(2:end) '=' values{i} ';']);
							properties_set{end+1} = properties{i}(2:end);
						end
					end
				end
			end
			
		function [data, fieldnames] = stringdatatosave(ndi_dbleaf_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NDI_DBLEAF_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% For NDI_DBLEAF, this returns the classname, name, and the objectfilename.
			%
			% Developer note: If you create a subclass of NDI_DBLEAF with properties, it is recommended
			% that you implement your own version of this method. If you have only properties that can be stored
			% efficiently as strings, then you will not need to include a WRITEOBJECTFILE method.
			%

				[data,fieldnames] = stringdatatosave@ndi_base(ndi_dbleaf_obj);
				data{end+1} = ndi_dbleaf_obj.name;
				fieldnames{end+1} = 'name';

		end % stringdatatosave

	end % methods 

end
