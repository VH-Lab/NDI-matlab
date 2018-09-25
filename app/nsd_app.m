classdef nsd_app 

	properties (SetAccess=protected,GetAccess=public)
		experiment % the NSD_EXPERIMENT object that the app will operate on
		name % the name of the app
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
				name = 'generic';
				if nargin>0,
					experiment = varargin{1};
				end
				if nargin>1,
					name = varargin{2};
				end

				nsd_app_obj.experiment = experiment;
				nsd_app_obj.name = name;
		end % nsd_app()


		% functions related to generic variables

		function vp = varpath(nsd_app_obj, obj)
			% VARPATH - return the standard variable path for a given object
			%
			% VP = VARPATH(NSD_APP_OBJ, OBJ)
			%
			% Given an object OBJ, this function returns the standard variable
			% path for the experiment associated with OBJ and NSD_APP_OBJ.
			%
			% For example, if OBJ is an NSD_PROBE object, then this function
			% calls NSD_APP/PPROBEVARPATH.
			%
			% If there is no standard location for saving variables for objects of
			% the same type as OBJ, then empty is returned.
			%
			% If not empty, VP ends in an NSD_BRANCHSEP.
			%
				vp = [];
				if isa(obj,'nsd_probe'),
					vp = nsd_app_obj.probevarpath(obj);
				elseif isa(obj,'mytype'),
					% do something else
				end
		end % varpath

		function an = varappname(nsd_app_obj)
			% VARAPPNAME - return the name of the application for use in variable creation
			%
			% AN = VARAPPNAME(NSD_APP_OBJ)
			%
			% Returns the name of the app modified for use as a variable name, either as 
			% a Matlab variable or a name in a path.
			%
				an = nsd_app_obj.name;
				if ~isvarname(an),
					an = matlab.lang.makeValidName(an);
				end
		end % 

		function mp = myvarpath(nsd_app_obj, obj)
			% MYVARPATH - return the standard variable path for my application underneath a given object
			%
			% MP = MYVARPATH(NSD_APP_OBJ, OBJ)
			%
			% Returns the standard variable path for the application
			% NSD_APP_OBJ to be placed near the NSD object OBJ.
			%
			% For example, if OBJ is an NSD_PROBE object, then this function
			% calls NSD_APP/PROVEVARPATH.
			%
			% If there is no standard location for saving variables for objects of the
			% same type as OBJ, then empty is returned for MP.
			%
			% If not empty, MP ends in an NSD_BRANCHSEP.
			%
				mp = nsd_app_obj.varpath(obj);
				if ~isempty(mp),
					mp = [mp nsd_app_obj.varappname nsd_branchsep];
				end
		end % myvarpath

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
