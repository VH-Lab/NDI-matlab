classdef ndi_app < ndi_documentservice

	properties (SetAccess=protected,GetAccess=public)
		experiment % the NDI_EXPERIMENT object that the app will operate on
		name % the name of the app
	end % properties

	methods
		function ndi_app_obj = ndi_app(varargin)
			% NDI_APP - create a new NDI_APP object
			%
			% NDI_APP_OBJ = NDI_APP(EXPERIMENT)
			%
			% Creates a new NDI_APP object that operates on the NDI_EXPERIMENT
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

				ndi_app_obj.experiment = experiment;
				ndi_app_obj.name = name;
		end % ndi_app()

		% functions related to generic variables

		function an = varappname(ndi_app_obj)
			% VARAPPNAME - return the name of the application for use in variable creation
			%
			% AN = VARAPPNAME(NDI_APP_OBJ)
			%
			% Returns the name of the app modified for use as a variable name, either as
			% a Matlab variable or a name in a document.
			%
				an = ndi_app_obj.name;
				if ~isvarname(an),
					an = matlab.lang.makeValidName(an);
				end;
		end; % varappname ()

		function c = searchquery(ndi_app_obj)
			% SEARCHQUERY - return a search query for an NDI_DOCUMENT related to this app
			%
			% C = SEARCHQUERY(NDI_APP_OBJ)
			%
			% Returns a cell array of strings that allow the creation or searching of an
			% NDI_DATABASE document for this app with field 'app' that has subfield 'name' equal
			% to the app's VARAPPNAME.
			%
				c = {'ndi_document.experiment_id', ...
					ndi_app_obj.experiment.id(), ...
					'app.name',ndi_app_obj.varappname() };
		end;

		function ndi_document_obj = newdocument(ndi_app_obj)
			% NEWDOCUMENT - return a new database document of type NDI_DOCUMENT based on an app
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
			%
			% Creates a blank NDI_DOCUMENT object of type 'ndi_document_app'. The 'app.name' field
			% is filled out with the name of NDI_APP_OBJ.VARAPPNAME().
			%
				c = { 'app.name',ndi_app_obj.varappname() };
				ndi_document_obj = ndi_app_obj.experiment.newdocument('ndi_document_app', c{:});
		end;
	end; % methods
end
