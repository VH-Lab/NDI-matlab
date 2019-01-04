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
			% a Matlab variable or a name in a document.
			%
				an = nsd_app_obj.name;
				if ~isvarname(an),
					an = matlab.lang.makeValidName(an);
				end;
		end; % varappname ()

		function c = searchquery(nsd_app_obj)
			% SEARCHQUERY - return a search query for an NSD_DOCUMENT related to this app
			%
			% C = SEARCHQUERY(NSD_APP_OBJ)
			%
			% Returns a cell array of strings that allow the creation or searching of an
			% NSD_DATABASE document for this app with field 'app' that has subfield 'name' equal
			% to the app's VARAPPNAME.
			%
				c = {'nsd_document.experiment_unique_reference', ...
					nsd_app_obj.experiment.unique_reference_string(), ...
					'app.name',nsd_app_obj.varappname() };
		end;

		function nsd_document_obj = newdocument(nsd_app_obj)
			% NEWDOCUMENT - return a new database document of type NSD_DOCUMENT based on an app
			%
			% NSD_DOCUMENT_OBJ = NEWDOCUMENT(NSD_APP_OBJ)
			%
			% Creates a blank NSD_DOCUMENT object of type 'nsd_document_app'. The 'app.name' field
			% is filled out with the name of NSD_APP_OBJ.VARAPPNAME().
			%
				c = { 'app.name',nsd_app_obj.varappname() };
				nsd_document_obj = nsd_app_obj.experiment.newdocument('nsd_document_app', c{:});
		end;
	end; % methods
end
