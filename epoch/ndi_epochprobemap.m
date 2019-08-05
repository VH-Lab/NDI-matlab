classdef ndi_epochprobemap
	properties
	end % properties
	methods
		function obj = ndi_epochprobemap()
			% NDI_EPOCHPROBEMAP - Create a new ndi_epochprobemap object
			%
			% MYNDI_EPOCHPROBEMAP = NDI_EPOCHPROBEMAP()
			%
			% Creates a new NDI_EPOCHPROBEMAP object. This is an abstract
			% base class so it has no inputs.
			%
			% The function has an alternative form:
			%
			%   MYNDI_EPOCHPROBEMAP_IODEVICE = NDI_EPOCHPROBEMAP(FILENAME)
			%
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab>', with
			% one line per NDI_EPOCHPROBEMAP_IODEVICE entry.


		end % creator

		function savetofile(ndi_epochprobemap_obj, filename)
			%  SAVETOFILE - Write ndi_epochprobemap object array to disk
			%
			%  SAVETOFILE(NDI_EPOCHCONENTS_OBJ, FILENAME)
			%
			%  Writes the NDI_EPOCHPROBEMAP object to disk in filename FILENAME (full path).
			%
			%  In this abstract class, no action is taken.
		end;


	end  % methods
end
