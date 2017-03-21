% SAMPLEAPI_DEVICE - Create a new SAMPLEAPI_DEVICE class handle object
%
%  D = SAMPLEAPI_DEVICE(NAME, THEDATATREE)
%
%  Creates a new SAMPLEAPI_DEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.
%

classdef sampleAPI_device < handle
	properties
		name;
		datatree;
	end
	methods
		function obj = sampleAPI_device(name,thedatatree)
			if nargin==0 || nargin==1,
				error(['Not enough input arguments.']);
		elseif nargin==2,
			obj.name = name;
			obj.datatree = thedatatree;
		else,
			error(['Too many input arguments.']);
			end;
		end

		function epochfiles = getepochfiles(self, number)
		% GETEPOCH - retreive the data files associated with a recording epoch
		%
		%   EPOCHFILES = GETEPOCHFILES(MYSAMPLEAPI_DEVICE, NUMBER)
		% 
		% Returns the file(s) associated the the data epoch NUMBER for the
		% SAMPLEAPI_DEVICE.
		%  
		% In the abstract base class SAMPLEAPI_DEVICE, this returns empty always.
		% In specific device classes, this can return a full path filename, a cell
                % list of file names, or some other suitable list of links to the epoch data.
		%
		% See also: SAMPLEAPI_DEVICE
			epochfiles = '';
		end;

		function epochrecord = getepochrecord(self, number)
		% GETEPOCHRECORD - retreive the epoch record associated with a recording epoch
		%
		%   EPOCHRECORD = GETEPOCHRECORD(MYSAMPLEAPI_DEVICE, NUMBER)
		% 
		% Returns the EPOCHRECORD associated the the data epoch NUMBER for the
		% SAMPLEAPI_DEVICE.
		%  
		% In the abstract base class SAMPLEAPI_DEVICE, this returns empty always.
		% In specific device classes, this will return an EPOCHRECORD object.
		%
		% See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD
			epochrecord= [];
		end;

		function deleteepoch(self, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		% 
		%   DELETEEPOCH(MYSAMPLEAPI_DEVICE, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and SAPI_EPOCHRECORD and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		% 
		% In the abstract class, this command takes no action.
		%
		% See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD
		end;

		function setepochrecord(self, epochrecord, number, overwrite)
		% SETEPOCHRECORD - Sets the epoch record of a particular epoch 
		%
		%   SETEPOCHRECORD(MYSAMPLEAPI_DEVICE, EPOCHRECORD, NUMBER, [OVERWRITE])
		%
		% Sets or replaces the SAPI_EPOCHRECORD for MYSAMPLEAPI_DEVICE with EPOCHRECORD for the epoch
		% numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
		% Otherwise, an error is given if there is an existing epoch record.
		%
		% See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD

			% actually need to do something here
			%    getepochfilelocation(self.datatree, self, N)  % need this function in data tree class
			%    save it in experiment / devices / devname / epoch_NNNN.erf
			%  verify it is good, then put it in the tree
		end;

		function b = verifyepochrecord(self, epochrecord, number)
		% VERIFYEPOCHRECORD - Verifies that an EPOCHRECORD is compatible with a given device and the data on disk
		%
		%   B = VERIFYEPOCHRECORD(MYSAMPLEAPI_DEVICE, EPOCHRECORD, NUMBER)
		%
		% Examines the SAPI_EPOCHRECORD EPOCHRECORD and determines if it is valid for the given device
		% epoch NUMBER.
		%
		% For the abstract class SAMPLEAPI_DEVICE, EPOCHRECORD is always valid as long as
		% EPOCHRECORD is an SAPI_EPOCHRECORD object.
		%
		% See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD
            b = isa(epochrecord, 'sAPI_epochrecord');
        end
    end
end