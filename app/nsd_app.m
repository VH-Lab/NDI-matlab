classdef nsd_app 

	properties (SetAccess=protected,GetAccess=public)
		experiment % the NSD_EXPERIMENT object that the app will operate on
	end % properties

	methods
		function nsd_app_obj = nsd_app(varargin)
			% NSD_APP - create a new NSD_APP object 
			%
			% NSD_APP_OBJ = NSD_APP(EXPERIMENT)
			%
			% Creates a new NSD_APP object that operates on the NSD_EXPERIMENT
			% object called EXPERIMENT.
			%
				experiment = [];
				if nargin>1,
					experiment = varargin{1};
				end

				nsd_app_obj.experiment = experiment;
		end % nsd_app()




		% functions related to probe variables

		function pvp = probevarpath(nsd_app_obj, probe)
			% PROBEVARPATH - return the NSD_VARIABLE_BRANCH path for probe variables
			% 
			% PVP = PROBEVARPATH(NSD_APP_OBJ, PROBE)
			%
			% Return the experiment variable path for variables related to the
			% NSD_PROBE object PROBE.
			%
			% See also: PROBEVARBRANCH
				pvp = ['probe' nsd_branchsep probe.probestring nsd_branchsep];
		end % probevarpath

		function pvb = probevarbranch(nsd_app_obj, probe)
			% PROBEVARBRANCH - return/create the NSD_VARIABLE_BRANCH path
			%
			% PVB = PROBEVARBRANCH(NSD_APP_OBJ, PROBE)
			%
			% Returns an NSD_VARIABLE_BRANCH object that contains variables related to
			% a specific NSD_PROBE object PROBE.
			%
				pvb = probe.experiment.variable.path2nsd_variable(probevarpath(nsd_app_obj,probe),1);
		end % probevarbranch

	end % methods
end
