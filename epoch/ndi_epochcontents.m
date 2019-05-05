classdef ndi_epochcontents
	properties
	end % properties
	methods
		function obj = ndi_epochcontents()
			% NDI_EPOCHCONTENTS - Create a new ndi_epochcontents object
			%
			% MYNDI_EPOCHCONTENTS = NDI_EPOCHCONTENTS()
			%
			% Creates a new NDI_EPOCHCONTENTS object. This is an abstract
			% base class so it has no inputs.
			%
			% The function has an alternative form:
			%
			%   MYNDI_EPOCHCONTENTS_IODEVICE = NDI_EPOCHCONTENTS(FILENAME)
			%
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab>', with
			% one line per NDI_EPOCHCONTENTS_IODEVICE entry.


		end % creator

		function savetofile(ndi_epochcontents_obj, filename)
			%  SAVETOFILE - Write ndi_epochcontents object array to disk
			%
			%  SAVETOFILE(NDI_EPOCHCONENTS_OBJ, FILENAME)
			%
			%  Writes the NDI_EPOCHCONTENTS object to disk in filename FILENAME (full path).
			%
			%  In this abstract class, no action is taken.
		end;


	end  % methods
end
