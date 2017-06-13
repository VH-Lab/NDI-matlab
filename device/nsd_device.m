classdef nsd_device < nsd_dbleaf
% NSD_DEVICE - Create a new NSD_DEVICE class handle object
%
%  D = NSD_DEVICE(NAME, THEDATATREE)
%
%  Creates a new NSD_DEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.
%

	properties (GetAccess=public, SetAccess=protected)
		datatree;
	end

	methods
		function obj = nsd_device(name,thedatatree)
		% NSD_DEVICE - create a new NSD_DEVICE object
		%
		%  OBJ = NSD_DEVICE(NAME, THEDATATREE)
		%
		%  Creates an NSD_DEVICE with name NAME and NSD_DATATREE
		%  THEDATATREE. THEDATATREE is an interface object to the raw data files
		%  on disk that are read by the NSD_DEVICE.
		%
		%  NSD_DEVICE is an abstract class, and a specific implementation must be called.
		%

			loadfromfile = 0;

			if nargin==0, % undocumented 0 argument creator
				name = '';
				thedatatree = [];
			elseif nargin==2,
				if ischar(thedatatree), % it is a command
					loadfromfile = 1;
					filename = name;
					name='';
					if ~strcmp(lower(thedatatree), lower('OpenFile')),
						error(['Unknown command.']);
					else,
						thedatatree=[];
					end
				end;
			else,
				error(['Function requires 2 input arguments exactly.']);
			end

			obj = obj@nsd_dbleaf(name);
			if loadfromfile,
				obj = obj.readobjectfile(filename);
			else,
				obj.name = name;
				obj.datatree = thedatatree;
			end

		end % nsd_device
		

		function epochfiles = getepochfiles(self, number)
		% GETEPOCH - retreive the data files associated with a recording epoch
		%
		%   EPOCHFILES = GETEPOCHFILES(MYNSD_DEVICE, NUMBER)
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
		end;

		function deleteepoch(self, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(MYNSD_DEVICE, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and SAPI_EPOCHRECORD and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: NSD_DEVICE, SAPI_EPOCHRECORD
		end;

		function setepochrecord(self, epochrecord, number, overwrite)
		% SETEPOCHRECORD - Sets the epoch record of a particular epoch
		%
		%   SETEPOCHRECORD(MYNSD_DEVICE, EPOCHRECORD, NUMBER, [OVERWRITE])
		%
		% Sets or replaces the SAPI_EPOCHRECORD for MYNSD_DEVICE with EPOCHRECORD for the epoch
		% numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
		% Otherwise, an error is given if there is an existing epoch record.
		%
		% See also: NSD_DEVICE, SAPI_EPOCHRECORD

			% actually need to do something here
			%    getepochfilelocation(self.datatree, self, N)  % need this function in data tree class
			%    save it in experiment / devices / devname / epoch_NNNN.erf
			%  verify it is good, then put it in the tree
			error('not implemented yet.');
		end;

                function epochrecord = getepochrecord(self, number)
                % GETEPOCHRECORD - retreive the epoch record associated with a recording epoch
                %
                %   EPOCHRECORD = GETEPOCHRECORD(MYNSD_DEVICE, NUMBER)
                %
                % Returns the EPOCHRECORD associated the the data epoch NUMBER for the
                % SAMPLEAPI_DEVICE.
                %
                % In the abstract base class SAMPLEAPI_DEVICE, this returns empty always.
                % In specific device classes, this will return an EPOCHRECORD object.
		%
                % See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD
		%
			   % Developer note: Why is this function present in nsd_device, when it pretty much 
			   % just calls the nsd_datatree version? Because, some devices may include some sort of epoch
			   % record in their own files natively, and the nsd_device_DRIVER that reads it may simply read from that
			   % information. So nsd_device_DRIVER needs the ability to override this function.

			epochrecord = self.datatree.getepochrecord(number,self);
                        if ~(verifyepochrecord(epochrecord))
                                error(['the numbered epoch is not a valid epoch for the given device']);
                        end
                end

		function b = verifyepochrecord(self, epochrecord, number)
		% VERIFYEPOCHRECORD - Verifies that an EPOCHRECORD is compatible with a given device and the data on disk
		%
		%   B = VERIFYEPOCHRECORD(MYNSD_DEVICE, EPOCHRECORD, NUMBER)
		%
		% Examines the SAPI_EPOCHRECORD EPOCHRECORD and determines if it is valid for the given device
		% epoch NUMBER.
		%
		% For the abstract class NSD_DEVICE, EPOCHRECORD is always valid as long as
		% EPOCHRECORD is an SAPI_EPOCHRECORD object.
		%
		% See also: NSD_DEVICE, SAPI_EPOCHRECORD
			b = isa(epochrecord, 'nsd_epochrecord');
		end
	end % methods
end
