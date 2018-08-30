classdef nsd_epochset
% NSD_EPOCHSET - routines for managing a set of epochs and their dependencies
%
%

	properties (SetAccess=protected,GetAccess=public)
		
	end % properties
	properties (SetAccess=protected,GetAccess=protected)
		cached_epochtable    % Cached epochtable 
		hashed_epochtable    % Hashed version of epochtable
	end % properties

	methods

		function obj = nsd_epochset()
			% NSD_EPOCHSET - constructor for NSD_EPOCHSET objects
			%
			% NSD_EPOCHSET_OBJ = NSD_EPOCHSET()
			%
			% This class has no parameters so the constructor is called with no input arguments.
			%

		end % nsd_epochset

		% okay, suppose we had

		%deleteepoch

		function n = numepochs(nsd_epochset_obj)
			% NUMEPOCHS - Number of epochs of NSD_EPOCHSET
			% 
			% N = NUMEPOCHS(NSD_EPOCHSET_OBJ)
			%
			% Returns the number of epochs in the NSD_EPOCHSET object NSD_EPOCHSET_OBJ.
			%
			% See also: EPOCHTABLE

				n = numel(epochtable(nsd_epochset_obj));

		end % numepochs

		function [et,hashvalue] = epochtable(nsd_epochset_obj)
			% EPOCHTABLE - Return an epoch table that relates the current object's epochs to underlying epochs
			%
			% [ET,HASHVALUE] = EPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochcontents'           | Any contents information for each epoch, usually of type NSD_EPOCHCONTENTS or empty.
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochcontents'
			%
			% HASHVALUE is the hashed value of the epochtable. One can check to see if the epochtable
			% has changed with NSD_EPOCHSET/MATCHEDEPOCHTABLE.
			%
			% After it is read from disk once, the ET is stored in memory and is not re-read from disk
			% unless the user calls NSD_EPOCHSET/RESETEPOCHTABLE.
			%
				if isempty(nsd_epochset_obj.cached_epochtable),
					[et,hashvalue] = nsd_epochset_obj.buildepochtable;
					nsd_epochset_obj.cached_epochtable = et;
					nsd_epochset_obj.hashed_epochtable = hashvalue;
				else,
					et = nsd_epochset_obj.cached_epochtable;
					hashvalue = nsd_epochset_obj.hashed_epochtable;
				end;

		end % epochtable

		function [et,hashvalue] = buildepochtable(nsd_epochset_obj)
			% BUILDEPOCHTABLE - Build and store an epoch table that relates the current object's epochs to underlying epochs
			%
			% [ET,HASHVALUE] = BUILDEPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochcontents'           | Any contents information for each epoch, usually of type NSD_EPOCHCONTENTS or empty.
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochcontents'
			%
			% HASHVALUE is the hashed value of the epochtable. One can check to see if the epochtable
			% has changed with NSD_EPOCHSET/MATCHEDEPOCHTABLE.
			%
			% After it is read from disk once, the ET is stored in memory and is not re-read from disk
			% unless the user calls NSD_EPOCHSET/RESETEPOCHTABLE.
			%
				ue = emptystruct('underlying','epoch_number','epoch_id','epochcontents');
				et = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
				hashvalue = hashmatlabvariable(et);
		end % buildepochtable

		function nsd_epochset_obj = resetepochtable(nsd_epochset_obj)
			% RESETEPOCHTABLE - clear an NSD_EPOCHSET epochtable in memory and force it to be re-read from disk
			%
			% NSD_EPOCHSET_OBJ = RESETEPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% This function clears the internal cached memory of the epochtable, forcing it to be re-read from
			% disk at the next request.
			%
			% See also: NSD_EPOCHSET/EPOCHTABLE

				nsd_epochset_obj.hashed_epochtable = -1;
				nsd_epochset_obj.cashed_epochtable = [];

		end % resetepochtable

		function b = matchedepochtable(nsd_epochset_obj, hashvalue)
			% MATCHEDEPOCHTABLE - compare a hash number from an epochtable to the current version
			%
			% B = MATCHEDEPOCHTABLE(NSD_EPOCHSET_OBJ, HASHVALUE)
			%
			% Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
			% Otherwise, it returns 0.

				b = 0;
				if ~isempty(nsd_epochset_obj.cached_epochtable),
					b = (hashvalue == nsd_epochset_obj.hashed_epochtable);
				end

		end % matchedepochtable

		function eid = epochid(nsd_epochset_obj, epoch_number)
			% EPOCHID - Get the epoch identifier for a particular epoch
			%
			% ID = EPOCHID (SELF, EPOCH_NUMBER)
			%
			% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
			% If it doesn't exist, it is created.
			%
			%
				eid = ''; % abstract class;
		end % epochid

                function s = epoch2str(self, number)
			% EPOCH2STR - convert an epoch number or id to a string
			%
			% S = EPOCH2STR(NSD_FILETREE_OBJ, NUMBER)
			%
			% Returns the epoch NUMBER in the form of a string. If it is a simple
			% integer, then INT2STR is used to produce a string. If it is an epoch
			% identifier string, then it is returned.
				if isnumeric(number)
					s = int2str(number);
				elseif iscell(number), % a cell array of strings
					s = [];
					for i=1:numel(number),
						if (i>2)
							s=cat(2,s,[', ']);
						end;
						s=cat(2,s,number{i});
					end
				elseif ischar(number),
					s = number;
				else,
					error(['Unknown epoch number or identifier.']);
				end;
                end % epoch2str()


	end % methods

end % classdef

 
%discussion: If we do this
%
%how will we pick and store epoch labels for non-devices? 
%	use some absurd concatenation
%	where to store it? or construct it from the myriad of underlying records?
%

