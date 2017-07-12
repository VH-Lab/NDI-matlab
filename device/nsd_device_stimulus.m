classdef nsd_device_stimulus < nsd_device
% NSD_DEVICE_STIMULUS - Create a new NSD_DEVICE_STIMULUS class handle object
%
%  D = NSD_DEVICE(NAME, THEFILETREE)
%
%  Creates a new NSD_DEVICE object with name and specific file tree object.
%  This is an abstract class that is overridden by specific devices.


	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_device_stimulus(varargin)
		% NSD_DEVICE_STIMULUS - create a new NSD_DEVICE_STIMULUS object
		%
		%  OBJ = NSD_DEVICE_STIMULUS(NAME, THEFILETREE)
		%
		%  Creates an NSD_DEVICE_STIMULUS with name NAME and NSD_FILETREE
		%  THEFILETREE. THEFILETREE is an interface object to the raw data files
		%  on disk that are read by the NSD_DEVICE_STIMULUS.
		%
		%  NSD_DEVICE_STIMULUS is an abstract class, and a specific implementation must be called.
		%
			obj = obj@nsd_device(varargin{:});
		end % nsd_device_stimulus

		function epochfiles = getepochfiles(self, number)
		% GETEPOCH - retreive the data files associated with a recording epoch
		%
		%   EPOCHFILES = GETEPOCHFILES(NSD_DEVICE_OBJ, NUMBER)
		%
		% Returns the data file(s) associated the the data epoch NUMBER for the
		% NSD_DEVICE.
		%
		% In the abstract base class NSD_DEVICE, this returns empty always.
		% In specific device classes, this can return a full path filename, a cell
                % list of file names, or some other suitable list of links to the epoch data.
		%
		% See also: NSD_DEVICE
			epochfiles = '';
		end  %epochfiles

		function deleteepoch(self, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(NSD_DEVICE_OBJ, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and NSD_EPOCHCONTENTS and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: NSD_DEVICE, NSD_EPOCHCONTENTS
		end % deleteepoch

                function epochcontents = getepochcontents(self, number)
			% GETEPOCHCONTENTS - retreive the epoch record associated with a recording epoch
			%
			%   EPOCHCONTENTS = GETEPOCHCONTENTS(NSD_DEVICE_OBJ, NUMBER)
			%
			% Returns the EPOCHCONTENTS associated the the data epoch NUMBER for the
			% NSD_DEVICE.
			%
			% See also: NSD_DEVICE, NSD_EPOCHCONTENTS
			%
				   % Developer note: Why is this function present in nsd_device, when it pretty much 
				   % just calls the nsd_filetree version? Because, some devices may include some sort of epoch
				   % record in their own files natively, and the nsd_device_DRIVER that reads it may simply read from that
				   % information. So nsd_device_DRIVER needs the ability to override this function.

				epochcontents = self.filetree.getepochcontents(number, self.name);
				if ~(verifyepochcontents(self,epochcontents))
					error(['the numbered epoch is not a valid epoch for the given device']);
				end
                end %getepochcontents()

		function b = verifyepochcontents(self, epochcontents, number)
			% VERIFYEPOCHCONTENTS - Verifies that an EPOCHCONTENTS is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHCONTENTS(NSD_DEVICE_OBJ, EPOCHCONTENTS, NUMBER)
			%
			% Examines the NSD_EPOCHCONTENTS EPOCHCONTENTS and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class NSD_DEVICE, EPOCHCONTENTS is always valid as long as
			% EPOCHCONTENTS is an NSD_EPOCHCONTENTS object.
			%
			% See also: NSD_DEVICE, NSD_EPOCHCONTENTS
				b = isa(epochcontents, 'nsd_epochcontents');
		end % verifyepochcontents

		function probes_struct=getprobes(self)
			% GETPROBES = Return all of the probes associated with an NSD_DEVICE object
			%
			% PROBES_STRUCT = GETPROBES(NSD_DEVICE_OBJ)
			%
			% Returns all probes associated with the NSD_DEVICE object NSD_DEVICE_OBJ
			%
			% This function returns a structure with fields of all unique probes across
			% all EPOCHCONTENTS objects returned in NSD_DEVICE/GETEPOCHCONTENTS.
			% The fields are 'name', 'reference', and 'type'.
				probes_struct = emptystruct('name','reference','type');
				N = self.filetree.numepochs();
				for n=1:N,
					epc = self.getepochcontents(n);
					newentry.name = epc.name;
					newentry.reference= epc.reference;
					newentry.type= epc.type;
					probes_struct(end+1) = newentry;
				end
				probes_struct = structunique(probes_struct);

		end % getprobes()

		function self=setexperiment(self, experiment)
			% SETEXPERIMENT - set the EXPERIMENT for an NSD_DEVICE object's filetree (type NSD_FILETREE)
			%
			% NSD_DEVICE_OBJ = SETEXPERIMENT(NSD_DEVICE_OBJ, PATH)
			%
			% Set the EXPERIMENT property of an NSD_DEVICE object's NSD_FILETREE object
			%	
				self.filetree = setproperties(self.filetree,{'experiment'},{experiment});
		end % setpath()
			
			
	end % methods
end
