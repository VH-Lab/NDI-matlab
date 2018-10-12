classdef nsd_app_markgarbage < nsd_app

	properties (SetAccess=protected,GetAccess=public)
		

	end % properties

	methods

		function nsd_app_markgarbage_obj = nsd_app_markgarbage(varargin)
			% NSD_APP_MARKGARBAGE - an app to help exclude garbage data from experiments
			%
			% NSD_APP_MARKGARBAGE_OBJ = NSD_APP_MARKGARBAGE(EXPERIMENT)
			%
			% Creates a new NSD_APP_MARKGARBAGE object that can operate on
			% NSD_EXPERIMENTS. The app is named 'nsd_app_markgarbage'.
			%
				experiment = [];
				name = 'nsd_app_markgarbage';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				nsd_app_markgarbage_obj = nsd_app@nsd_app(nsd_app_markgarbage_obj, experiment, name);

		end % nsd_app_markgarbage() creator

		function markvalidinterval(nsd_app_markgarbage_obj, nsd_epochset_obj, interval, timeref)
			% MARKVALIDINTERVAL - mark a valid intervalin an epoch (all else is garbage)
			%
			% MARKVALIDINTERVAL(NSD_APP_MARKGARBAGE_APP, NSD_EPOCHSET_OBJ, INTERVAL, TIMEREF)
			%
			% Saves a variable marking a valid interval (INTERVAL = [t0 t1]) with respect
			% to an NSD_TIMEREFERENCE object TIMEREF for a NSD_EPOCHSET object NSD_EPOCHSET_OBJ 
			% Examples of NSD_EPOCHSET objects include NSD_IODEVICE and NSD_PROBE and
			% their subclasses.
			%
			% The TIMEREF is saved as a name and type for looking up later.
				
				% what info is needed
				%  t0, timeref
				%  t1, timeref

		end % markvalidinterval()

		% developer note: it would be great to have a 'markinvalidinterval' companion

		function getvalidinterval(nsd_app_markgarbage_obj, nsd_epochset_obj, 


	end % methods

end % nsd_app_markgarbage
