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

		function mp = myvarpath(nsd_app_obj, obj) % suggest to rename to appvarpath, myvarpath is hard to remember with all methods
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

		function mpe = myvarpathepoch(nsd_app_obj, obj, epoch)
			% MYVARPATHEPOCH - return the standard variable path for my application underneath the EPOCH of a given NSD_EPOCHSET object
			%
			% MPE = MYVARPATHEPOCH(NSD_APP_OBJ, OBJ, EPOCH)
			%
			% Returns the standard variable path for variables related to NSD_EPOCHSET objects at a given EPOCH,
			% which can be a number or an EPOCHID string.
			%
			% If there is no standard location for saving variables for objects of the same type as OBJ, then empty is returned for MP.
			%
			% If not empty, MPE ends in an NSD_BRANCHSEP.
			%
				mpe = '';
				if ~isa(obj,'nsd_epochset'),
					return; % needs to be an NSD_EPOCHSET
				end

				epochstring = obj.epochid(epoch);

				mpe = nsd_app_obj.myvarpath(obj);
				if ~isempty(mpe),
					mpe = [mpe 'Epoch ' epochstring nsd_branchsep];
				end

		end % myvarpathepoch()

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
			% PROBEVARBRANCH - return/create the NSD_VARIABLE_BRANCH for an NSD_PROBE object
			%
			% PVB = PROBEVARBRANCH(NSD_APP_OBJ, PROBE)
			%
			% Returns an NSD_VARIABLE_BRANCH object that contains variables related to
			% a specific NSD_PROBE object PROBE.
			%
				pvb = probe.experiment.database.path2nsd_variable(probevarpath(nsd_app_obj,probe),1);
		end % probevarbranch

	end % methods
end
