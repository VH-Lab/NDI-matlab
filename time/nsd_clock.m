classdef nsd_clock < nsd_base
% NSD_CLOCK - a class for specifying time in the NSD framework
%
%
	properties (SetAccess=protected, GetAccess=public)
		type % the nsd_clock type; in this class, acceptable values are 'UTC', 'exp_global_time', and 'no_time'
	end

	methods
		function obj = nsd_clock(varargin)
			% NSD_CLOCK - Creates a new NSD_CLOCK device
			%
			% OBJ = NSD_CLOCK(TYPE)
			%
			% Creates a new NSD_CLOCK object for the device DEVICE. TYPE can be
			% any of the following strings (with description):
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The device keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
			% 'no_time'          | The device has no timing information
			%
				fullfilename = '';
				type = '';

				if nargin==1,
					type = varargin{1};
				end

				if nargin==2,
					if strcmp(lower(varargin{2}),lower('OpenFile'))
						fullfilename = varargin{1};
					else,
						error(['Too many inputs']);
					end
				end

				if nargin>0 & nargin<2,
				end

				obj=obj@nsd_base;
				if ~isempty(fullfilename),
					obj = obj.readobjectfile(fullfilename);
				elseif ~isempty(type),
					obj = obj.setclocktype(type);
				end

		end % nsd_clock()
		
		function nsd_clock_obj = setclocktype(nsd_clock_obj, type)
			% SETCLOCKTYPE - Set the type of an NSD_CLOCK
			%
			% NSD_CLOCK_OBJ = SETCLOCKTYPE(NSD_CLOCK_OBJ, TYPE)
			%
			% Sets the TYPE property of an NSD_CLOCK object NSD_CLOCK_OBJ.
			% Valid values for the TYPE string are as follows:
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The device keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
			% 'no_time'          | The device has no timing information
			%
			%
				if ~ischar(type),
					error(['TYPE must be a character string.']);
				end

				type = lower(type);

				switch type,
					case {'utc','exp_global_time','no_time'},
						% no error
					otherwise,
						error(['Unknown clock type ' type '.']);
				end

				nsd_clock_obj.type = type;
		end % setclocktype() %

		function [data, fieldnames] = stringdatatosave(nsd_clock_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NSD_CLOCK_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% For NSD_FILETREE, this returns file parameters, epochcontents, and epochcontents_fileparameters.
			%
			% Note: NSD_FILETREE objects do not save their NSD_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NSD_FILETREE from disk to install the NSD_EXPERIMENT.
			%
			% Developer note: If you create a subclass of NSD_FILETREE with properties, it is recommended
			% that you implement your own version of this method. If you have only properties that can be stored
			% efficiently as strings, then you will not need to include a WRITEOBJECTFILE method.
			%
				[data,fieldnames] = stringdatatosave@nsd_base(nsd_clock_obj);
				data{end+1} = nsd_clock_obj.data;
				fieldnames{end+1} = 'type';
		end % stringdatatosave

		function [obj,properties_set] = setproperties(nsd_clock_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_BASE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_BASE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_BASE_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_BASE_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NSD_BASE that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NSD_BASE).
			%
				fn = fieldnames(nsd_clock_obj);
				obj = nsd_clock_obj;
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
	end % methods
end % nsd_clock class


