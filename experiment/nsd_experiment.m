classdef nsd_experiment < handle
	% NSD_EXPERIMENT - NSD_EXPERIMENT object class

	properties (SetAccess = protected)
		reference         % A string reference for the experiment
		device            % An array of NSD_DEVICE objects associated with this experiment
		variable          % An array of NSD_VARIABLE objects associated with this experiment
	end
	methods
		function obj = nsd_experiment(reference)
			% nsd_experiment - Create a new NSD_EXPERIMENT object
			%
			%   E=NSD_EXPERIMENT(REFERENCE)
			%
			% Creates a new NSD_EXPERIMENT object E. The experiment has a unique
			% reference REFERENCE. This class is an abstract class and typically
			% an end user will open a specific subclass.
			%
			% NSD_EXPERIMENT objects can access 0 or more NSD_DEVICE objects.
			%
			% See also: NSD_EXPERIMENT/DEVICE_ADD, NSD_EXPERIMENT/DEVICE_RM, 
			%   NSD_EXPERIMENT/GETPATH, NSD_EXPERIMENT/GETREFERENCE

			obj.reference = reference;
			obj.device = [];
			obj.variable = [];
		end

		%%%%%% DEVICE METHODS

		function self = device_add(self, dev)
			%DEVICE_ADD - Add a sampling device to a NSD_EXPERIMENT object
			%
			%   SELF = DEVICE_ADD(SELF, DEV)
			%
			% Adds the device DEV to the NSD_EXPERIMENT SELF
			%
			% The devices can be accessed by referencing SELF.device
			%  
			% See also: DEVICE_RM, NSD_EXPERIMENT

			if ~isa(dev,'nsd_device'), error(['dev is not a nsd_device']); end;

			if isempty(self.device),
				self.device = dev;
			else,
				if ~any(self.device==dev),
					self.devicelist(end+1) = dev;
				end;
			end;
		end 
		function self = device_rm(self, dev)
			% DEVICE_RM - Remove a sampling device from an NSD_EXPERIMENT object
			%
			%   SELF = DEVICE_RM(SELF, DEV)
			%
			% Removes the device DEV from the device list.
			%
			% See also: DEVICE_ADD, NSD_EXPERIMENT
			
			indexes = find(self.device~=dev);
			self.device = self.device(indexes);
		end

		% NSD_VARIABLE METHODS

		function self = variable_add(self, var)
			%VARIABLE_ADD - Add an NSD_VARIABLE to an NSD_EXPERIMENT object
			%
			%   SELF = VARIABLE_ADD(SELF, VAR)
			%
			% Adds the NSD_VARIABLE VAR to the NSD_EXPERIMENT SELF
			%
			% The variable can be accessed by referencing SELF.variable
			%  
			% See also: VARIABLE_RM, NSD_EXPERIMENT

			if ~isa(var,'nsd_variable'), error(['var is not an NSD_VARIABLE']); end;

			if isempty(self.variable),
				self.variable= dev;
			else,
				if ~any(self.variable==dev),
					self.variable(end+1) = dev;
				end;
			end;
		end

		function self = variable_rm(self, var)
			% VARIABLE_RM - Remove an NSD_VARIABLE from an NSD_EXPERIMENT object
			%
			%   SELF = VARIABLE_RM(SELF, VAR)
			%
			% 
			% Removes the variable VAR from the experiment variable list.
			%
			% See also: VARIABLE_ADD, NSD_EXPERIMENT
			
			indexes = find(self.variable~=var);
			self.variable= self.variable(indexes);
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

	end % methods
end % classdef
