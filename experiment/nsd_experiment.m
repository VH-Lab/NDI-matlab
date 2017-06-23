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
				obj.device = nsd_dbleaf_branch('','device',{'nsd_device'},1);
				obj.variable = nsd_dbleaf_branch('','variable',{'nsd_variable','nsd_variable_branch'},0);
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
				self.device = self.device.add(dev);

			end 
		function self = device_rm(self, dev)
			% DEVICE_RM - Remove a sampling device from an NSD_EXPERIMENT object
			%
			%   SELF = DEVICE_RM(SELF, DEV)
			%
			% Removes the device DEV from the device list.
			%
			% See also: DEVICE_ADD, NSD_EXPERIMENT
			
				leaf = self.device.load('name',dev.name);
				if ~isempty(leaf),
					self.device = self.device.remove(leaf.objectfilename);
				else,
					error(['No device named ' dev.name ' found.']);
				end
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

				if ~isa(var,'nsd_variable')|~isa(var,'nsd_variable_branch'), error(['var is not an NSD_VARIABLE']); end;
				self.variable= self.variable.add(var);
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
			
				leaf = self.variable.load('name',var.name);
				if ~isempty(leaf),
					self.variable = self.variable.remove(leaf.objectfilename);
				else,
					error(['No variable named ' var.name ' found.']);
				end
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

		function probes = getprobes(self)
			% GETPROBES - Return all NSD_PROBES that are found in NSD_DEVICE epoch contents entries
			%
			% PROBES = GETPROBES(NSD_EXPERIMENT_OBJ)
			%
			% Examines all NSD_DEVICE entries in the NSD_EXPERIMENT_OBJ's device array
			% and returns all NSD_PROBE entries that can be constructed from each device's
			% NSD_EPOCHCONENTS entries.
			%
			% PROBES is a cell array of NSD_PROBE objects.
			%
				probestruct = [];
				devs = load(self.device,'name','(.*)');
				if ~isempty(devs),
					probestruct = getprobes(devs(1));
				end
				for d=2:numel(devs),
					probestruct = cat(1,probestruct,getprobes(devs(d)));
				end
				probestruct = structunique(probestruct);
				probes = nsd_probestruct2probe(probestruct, self);
		end % getprobes

	end % methods
end % classdef
