classdef app < ndi.documentservice

	properties (SetAccess=protected,GetAccess=public)
		session % the ndi.session object that the app will operate on
		name % the name of the app
	end % properties

	methods
		function ndi_app_obj = app(varargin)
			% ndi.app - create a new ndi.app object
			%
			% NDI_APP_OBJ = ndi.app (SESSION)
			%
			% Creates a new ndi.app object that operates on the ndi.session
			% object called SESSION.
			%
				session = [];
				name = 'generic';
				if nargin>0,
					session = varargin{1};
				end
				if nargin>1,
					name = varargin{2};
				end

				ndi_app_obj.session = session;
				ndi_app_obj.name = name;
		end % ndi.app()

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

		function [v,url] = version_url(ndi_app_obj)
			% VERSION_URL - return the app version and url 
			%
			% [V, URL] = VERSION_URL(NDI_APP_OBJ)
			%
			% Return the version and url for the current app. In the base class,
			% it is assumed that GIT is used and is available from the command line
			% and the version and url are read from the git directory.
			%
			% Developers should override this method in their own class if they use a 
			% different version control system.
			%
				classfilename = which(class(ndi_app_obj));
				if iscell(classfilename),
					classfilename = classfilename{1}; % take the first one if there are multiple
				end;
				[parentdir,filename] = fileparts(classfilename);
				[v,url] = vlt.git.git_repo_version(parentdir);

		end; % version_url()

		function c = searchquery(ndi_app_obj)
			% SEARCHQUERY - return a search query for an ndi.document related to this app
			%
			% C = SEARCHQUERY(NDI_APP_OBJ)
			%
			% Returns a cell array of strings that allow the creation or searching of an
			% ndi.database document for this app with field 'app' that has subfield 'name' equal
			% to the app's VARAPPNAME.
			%
				c = {'ndi_document.session_id', ...
					ndi_app_obj.session.id(), ...
					'app.name',ndi_app_obj.varappname() };
		end;

		function ndi_document_obj = newdocument(ndi_app_obj)
			% NEWDOCUMENT - return a new database document of type ndi.document based on an app
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
			%
			% Creates a blank ndi.document object of type 'app'. The 'app.name' field
			% is filled out with the name of NDI_APP_OBJ.VARAPPNAME().
			%
				[~,osversion] = detectOS;
				osversion_strings = {};
				for i=1:numel(osversion),
					osversion_strings{i} = int2str(osversion(i));
				end;
				osversion = strjoin(osversion_strings,'.');
				matlab_ver = ver('MATLAB');
				matlab_version = matlab_ver.Version;

				[version,url] = ndi_app_obj.version_url();			

				c = { ...
					'app.name',ndi_app_obj.varappname(),  ...
					'app.version', version, ...
					'app.url', url, ...
					'app.os', computer, ...
					'app.os_version', osversion,...
					'app.interpreter','MATLAB',...
					'app.interpreter_version',matlab_version ...
				};
				ndi_document_obj = ndi_app_obj.session.newdocument('app', c{:});
		end;
	end; % methods
end

