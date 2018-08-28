classdef nsd_epochset
% NSD_EPOCHSET - routines for managing a set of epochs and their dependencies
%
%

	properties (SetAccess=protected,GetAccess=public)
		
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

		function et = epochtable(nsd_epochset_obj)
			% EPOCHTABLE - Return an epoch table that relates the current object's epochs to underlying epochs
			%
			% ET = EPOCHTABLE(NSD_EPOCHSET_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
			% 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
			%                           |   This epoch ID uniquely specifies the epoch.
			% 'epochcontents'           | Any contents information for each epoch, usually of type NSD_EPOCHCONTENTS or empty.
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

				ue = emptystruct('underlying','epoch_number','epoch_id');
				et = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');

		end % epochtable

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

