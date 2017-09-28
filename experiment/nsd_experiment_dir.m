% NSD_EXPERIMENT_DIR - NSD_EXPERIMENT_DIR object class - an experiment with an associated file directory
%

classdef nsd_experiment_dir < nsd_experiment
	properties (GetAccess=public,SetAccess=protected)
		path    % the file path of the experiment
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
			% One can also open an existing experiment by using
			%
			%  E = NSD_EXPERIMENT_DIR(PATHNAME)
			%
			% See also: NSD_EXPERIMENT, NSD_EXPERIMENT_DIR/GETPATH

				if nargin==1,
					path = reference;
					ref = 'temp';
				end

				obj = obj@nsd_experiment(reference);
				obj.path = path;
				d = dir([obj.nsdpathname() filesep 'reference.txt']);
				if ~isempty(d),
					obj.reference = textfile2char([obj.nsdpathname() filesep 'reference.txt']);
				elseif nargin==1,
					error(['Could not load the REFERENCE field from the path ' obj.nsdpathname() '.']);
				end
				d = dir([obj.nsdpathname() filesep 'device_object_*']);
				if isempty(d),
					obj.device = nsd_dbleaf_branch(obj.nsdpathname(),'device',{'nsd_device'},1);
				else,
					obj.device = nsd_pickdbleaf([obj.nsdpathname() filesep d(1).name]);
				end;
				d = dir([obj.nsdpathname() filesep 'variable_object_*']);
				if isempty(d),
					obj.variable = nsd_dbleaf_branch(obj.nsdpathname(),'variable',...
						{'nsd_variable','nsd_variable_branch','nsd_variable_file'}, ...
						0);
				else,
					obj.variable = nsd_pickdbleaf([obj.nsdpathname() filesep d(1).name]);
				end;
				str2text([obj.nsdpathname() filesep 'reference.txt'],obj.reference);
		end
		
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
                end

		function p = nsdpathname(self)
			% NDSPATHNAME - Return the path of the NSD files within the experiment
			%
			% P = NSDPATHNAME(NSD_EXPERIMENT_DIR_OBJ)
			%
			% Returns the pathname to the NSD files in the NSD_EXPERIMENT_DIR object.
			%
			% It is the NSD_EXPERIMENT_DIR object's path plus [filesep '.nsd' ]

				nsd_dir = '.nsd';
				p = [self.path filesep nsd_dir ];
				if ~exist(p,'dir'),
					mkdir(p);
				end
		end

	end % methods

end % classdef


