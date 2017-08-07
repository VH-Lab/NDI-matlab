classdef nsd_clock_device_epoch < nsd_clock_device
% NSD_CLOCK_DEVICE_EPOCH - a class for specifying time with respect to an epoch on an NSD_DEVICE
%
%
	properties (SetAccess=protected, GetAccess=public)
		epoch % the epoch number or identifier to be referred to
	end

	methods
		function obj = nsd_clock_device_epoch(varargin)
			% NSD_CLOCK_DEVICE_EPOCH - Creates a new NSD_CLOCK_DEVICE_EPOCH object, which refers to a specific epoch
			%
			% Creates a new NSD_CLOCK_DEVICE_EPOCH object. There are two forms of the constructor:
			%
			% OBJ = NSD_CLOCK_DEVICE_EPOCH(TYPE, DEVICE, EPOCH)
			%    or
			% OBJ = NSD_CLOCK_DEVICE_EPOCH(NSD_CLOCK_DEVICE_OBJ, EPOCH)
			%
			% One can specify the TYPE, DEVICE, and EPOCH, or can specify the TYPE and
			% DEVICE from an existing NSD_CLOCK_DEVICE object NSD_CLOCK_DEVICE_OBJ.
			% TYPE can be any of the following strings (with description):
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The device keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
			% 'no_time'          | The device has no timing information
			% 'dev_global_time'  | The device has a global clock for itself
			% 'dev_local_time'   | The device only has local time, within a recording epoch
			%
				type='';
				device=[];
				epoch=[];
				fullfilename = '';
				if nargin==2,
					if strcmp(lower(varargin{2}),loewr('OpenFile')),
						fullfilename = varargin{1};
					else,
						myclock = varargin{1};
						epoch = varargin{2};
						if isa(myclock,'nsd_clock_device'),
							type = myclock.type;
							device = myclock.device;
						else,
							error(['When called with 2 inputs, first input must be an NSD_CLOCK_DEVICE object.']);
						end
					end
				elseif nargin==3,
					type = varargin{1};
					device = varargin{2};
					epoch = varargin{3};
				elseif nargin==0,
				else,
					error(['Function must have 0, 2, or 3 input arguments.']);
				end
				obj=obj@nsd_clock_device;
				if ~isempty(fullfilename),
					obj = obj.readobjectfile(fullfilename);
				else,
					obj = obj.setclocktype(type);
					obj = obj.setdevice(device);
					obj.epoch = epoch;
				end
		end % nsd_clock_device_epoch()

		function nsd_clock_device_epoch_obj = setepoch(nsd_clock_device_epoch_obj, epoch)
			% SETEPOCH - Set the epoch of an NSD_CLOCK_DEVICE_EPOCH object
			%
			% NSD_CLOCK_DEVICE_EPOCH_OBJ = SETEPOCH(NSD_CLOCK_DEVIE_EPOCH_OBJ, EPOCH)
			%
			% Set the epoch property of an NSD_CLOCK_DEVICE_EPOCH object to EPOCH.
			%
			% This value can be read from NSD_CLOCK_DEVICE_EPOCH_OBJ.epoch
			%
				nsd_clock_device_epoch.epoch = epoch;
		end % setepoch

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
				[data,fieldnames] = stringdatatosave@nsd_clock_device(nsd_clock_obj);
				data{end+1} = nsd_clock_obj.epoch;
				fieldnames{end+1} = 'epoch';
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
end % nsd_clock_device_epoch class


