classdef epochprobemap
	properties
	end % properties
	methods
		function obj = epochprobemap()
			% ndi.epoch.epochprobemap - Create a new ndi.epoch.epochprobemap object
			%
			% MYNDI_EPOCHPROBEMAP = ndi.epoch.epochprobemap()
			%
			% Creates a new ndi.epoch.epochprobemap object. This is an abstract
			% base class so it has no inputs.
			%
			% The function has an alternative form:
			%
			%   MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(FILENAME)
			%
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab>', with
			% one line per ndi.daq.metadata.epochprobemap_daqsystem entry.


		end % creator

		function savetofile(ndi_epochprobemap_obj, filename)
			%  SAVETOFILE - Write ndi.epoch.epochprobemap object array to disk
			%
			%  SAVETOFILE(NDI_EPOCHCONENTS_OBJ, FILENAME)
			%
			%  Writes the ndi.epoch.epochprobemap object to disk in filename FILENAME (full path).
			%
			%  In this abstract class, no action is taken.
		end;


	end  % methods
end
