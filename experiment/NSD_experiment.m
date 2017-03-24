% NSD_EXPERIMENT - NSD_EXPERIMENT object class

classdef NSD_experiment < handle
	properties (SetAccess = protected)
		reference;
		device_list;
	end
	methods
		function obj = NSD_experiment(reference)
		% NSD_experiment - Create a new NSD_EXPERIMENT object
		%
		%   E=NSD_EXPERIMENT(REFERENCE)
		%
		% Creates a new NSD_EXPERIMENT object E. The experiment has a unique
		% reference REFERENCE. This class is an abstract class and typically
		% an end user will open a specific subclass.
		%
		% NSD_EXPERIMENT objects can access 0 or more NSD_devices.
		%
		% See also: NSD_EXPERIMENT/DEVICE_ADD, NSD_EXPERIMENT/DEVICE_RM, 
		%   NSD_EXPERIMENT/GETPATH, NSD_EXPERIMENT/GETREFERENCE

		obj.reference = reference;
		obj.device_list = [];
		end

		%%%%%% DEVICE METHODS

		function self = device_add(self, dev)
		%DEVICE_ADD - Add a sampling device to a NSD_EXPERIMENT object
		%
		%   SELF = DEVICE_ADD(SELF, DEV)
		%
		% Adds the device DEV to the NSD_EXPERIMENT SELF
		%
		% The devices can be accessed by referencing SELF.DEV
		%  
		% See also: DEVICE_RM, NSD_EXPERIMENT

		if ~isa(dev,'NSD_device'), error(['dev is not a NSD_device']); end;

		if isempty(self.device_list),
			self.device_list = dev;
		else,
			self.devicelist(end+1) = dev;
		end;

		end

		function self = device_rm(self, dev)
		% DEVICE_RM - Remove a sampling device from an NSD_EXPERIMENT object
		%
		%   SELF = DEVICE_RM(SELF, DEV)
		%
		% 
		% Removes the device DEV from the device list.
		%
		% See also: DEVICE_ADD, NSD_EXPERIMENT
		
		indexes = find(self.device_list~=dev);
		self.device = self.device(indexes);
		end

		%%%%%% PATH methods

		function p = getpath(self)
		% GETPATH - Return the path of the experiment
		%
		%   P = GETPATH(SELF)
		%
		% Returns the path of an NSD_EXPERIMENT object.
		%
		% The path is some sort of reference to the storage location of 
		% the experiment. This might be a URL, or a file directory, depending upon
		% the subclass.
		%
		% In the NSD_EXPERIMENT class, this returns empty.
		%
		% See also: NSD_EXPERIMENT
		p = [];
		end


		%%%%%% REFERENCE methods

		function r=getreference(self)
		% GETREFERENCE - Return the unique reference of this experiment
		%
		%   R = GETREFERENCE(SELF)
		%
		% Returns the unique reference string of the NSD_EXPERIMENT object SELF.
		%
		% See also: NSD_EXPERIMENT
		r=self.reference;
		end;

	end % methods
end % classdef
