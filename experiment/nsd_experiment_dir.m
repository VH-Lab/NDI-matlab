% NSD_EXPERIMENT_DIR - NSD_EXPERIMENT_DIR object class - an experiment with an associated file directory
%

classdef nsd_experiment_dir < nsd_experiment & handle 
	properties (GetAccess=public,SetAccess=protected)
		path;
	end

	methods

		function obj = nsd_experiment_dir(reference, path)
		% NSD_EXPERIMENT_DIR - Create a new NSD_EXPERIMENT_DIR object
		%
		%   E = NSD_EXPERIMENT_DIR(REFERENCE, PATHNAME)
		%
		% Creates an NSD_EXPERIMENT_DIR object, or an experiment with an
		% associated directory. REFERENCE should be a unique reference for the
		% experiment and directory PATHNAME.
		%
		% See also: NSD_EXPERIMENT, NSD_EXPERIMENT_DIR/GETPATH

			obj = obj@nsd_experiment(reference);
			obj.path = path;
			obj.device = nsd_dbleaf_branch(obj.path,'device',{'nsd_device'},1);
			obj.variable = nsd_dbleaf_branch(obj.path,'variable',{'nsd_variable'},0);
		end;
		
		function p = getpath(self)
		% GETPATH - Return the path of the experiment
		%
		%   P = GETPATH(SELF)
		%
		% Returns the path of an NSD_EXPERIMENT_DIR object.
                %
		% The path is some sort of reference to the storage location of
		% the experiment. This might be a URL, or a file directory.
                %
                p = self.path;
                end;

	end % methods

end % classdef
