classdef nsd_epochcontents
	properties
	end % properties
	methods
		function obj = nsd_epochcontents()
			% NSD_EPOCHCONTENTS - Create a new nsd_epochcontents object
			%
			% MYNSD_EPOCHCONTENTS = NSD_EPOCHCONTENTS()
			%
			% Creates a new NSD_EPOCHCONTENTS object. This is an abstract
			% base class so it has no inputs.
			%
			% The function has an alternative form:
			%
			%   MYNSD_EPOCHCONTENTS_IODEVICE = NSD_EPOCHCONTENTS(FILENAME)
			%
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab>', with
			% one line per NSD_EPOCHCONTENTS_IODEVICE entry.


		end % creator

		function savetofile(nsd_epochcontents_obj, filename)
			%  SAVETOFILE - Write nsd_epochcontents object array to disk
			%
			%  SAVETOFILE(NSD_EPOCHCONENTS_OBJ, FILENAME)
			%
			%  Writes the NSD_EPOCHCONTENTS object to disk in filename FILENAME (full path).
			%
			%  In this abstract class, no action is taken.
		end;


	end  % methods
end
