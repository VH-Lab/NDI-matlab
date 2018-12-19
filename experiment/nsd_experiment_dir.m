% NSD_EXPERIMENT_DIR - NSD_EXPERIMENT_DIR object class - an experiment with an associated file directory
%

classdef nsd_experiment_dir < nsd_experiment
	properties (GetAccess=public,SetAccess=protected)
		path    % the file path of the experiment
	end

	methods
		function nsd_experiment_dir_obj = nsd_experiment_dir(reference, path)
			% NSD_EXPERIMENT_DIR - Create a new NSD_EXPERIMENT_DIR nsd_experiment_dir_object
			%
			%   E = NSD_EXPERIMENT_DIR(REFERENCE, PATHNAME)
			%
			% Creates an NSD_EXPERIMENT_DIR nsd_experiment_dir_object, or an experiment with an
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

				nsd_experiment_dir_obj = nsd_experiment_dir_obj@nsd_experiment(reference);
				nsd_experiment_dir_obj.path = path;
				d = dir([nsd_experiment_dir_obj.nsdpathname() filesep 'reference.txt']);
				if ~isempty(d),
					nsd_experiment_dir_obj.reference = strtrim(textfile2char([nsd_experiment_dir_obj.nsdpathname() filesep 'reference.txt']));
				elseif nargin==1,
					error(['Could not load the REFERENCE field from the path ' nsd_experiment_dir_obj.nsdpathname() '.']);
				end
				d = dir([nsd_experiment_dir_obj.nsdpathname() filesep 'unique_reference.txt']);
				if ~isempty(d),
					nsd_experiment_dir_obj.unique_reference = strtrim(textfile2char([nsd_experiment_dir_obj.nsdpathname() filesep 'unique_reference.txt']));
				elseif nargin==1,
					error(['Could not load the UNIQUE REFERENCE field from the path ' nsd_experiment_dir_obj.nsdpathname() '.']);
				end

				d = dir([nsd_experiment_dir_obj.nsdpathname() filesep 'iodevice_object_*']);
				if isempty(d),
					nsd_experiment_dir_obj.iodevice = nsd_dbleaf_branch(nsd_experiment_dir_obj.nsdpathname(),'iodevice',{'nsd_iodevice'},1);
				else,
					nsd_experiment_dir_obj.iodevice = nsd_pickdbleaf([nsd_experiment_dir_obj.nsdpathname() filesep d(1).name]);
				end;

				nsd_experiment_dir_obj.database = nsd_opendatabase(nsd_experiment_dir_obj.nsdpathname(), nsd_experiment_dir_obj.unique_reference_string());

				d = dir([nsd_experiment_dir_obj.nsdpathname() filesep '*syncgraph.nsd']);
				if isempty(d),
					nsd_experiment_dir_obj.syncgraph = nsd_syncgraph(nsd_experiment_dir_obj);
				else,
					nsd_experiment_dir_obj.syncgraph = nsd_experiment_dir_obj.syncgraph.readobjectfile(...
						[nsd_experiment_dir_obj.nsdpathname filesep d(1).name]);
				end;

				str2text([nsd_experiment_dir_obj.nsdpathname() filesep 'reference.txt'], nsd_experiment_dir_obj.reference);
				str2text([nsd_experiment_dir_obj.nsdpathname() filesep 'unique_reference.txt'], nsd_experiment_dir_obj.unique_reference);
		end;
		
		function p = getpath(nsd_experiment_dir_obj)
			% GETPATH - Return the path of the experiment
			%
			%   P = GETPATH(NSD_EXPERIMENT_DIR_OBJ)
			%
			% Returns the path of an NSD_EXPERIMENT_DIR object.
			%
			% The path is some sort of reference to the storage location of
			% the experiment. This might be a URL, or a file directory.
			%
				p = nsd_experiment_dir_obj.path;
                end;

		function p = nsdpathname(nsd_experiment_dir_obj)
			% NDSPATHNAME - Return the path of the NSD files within the experiment
			%
			% P = NSDPATHNAME(NSD_EXPERIMENT_DIR_OBJ)
			%
			% Returns the pathname to the NSD files in the NSD_EXPERIMENT_DIR object.
			%
			% It is the NSD_EXPERIMENT_DIR object's path plus [filesep '.nsd' ]

				nsd_dir = '.nsd';
				p = [nsd_experiment_dir_obj.path filesep nsd_dir ];
				if ~exist(p,'dir'),
					mkdir(p);
				end;
		end;

		function b = eq(nsd_experiment_dir_obj_a, nsd_experiment_dir_obj_b)
			% EQ - Are two NSD_EXPERIMENT_DIR objects equivalent?
			%
			% B = EQ(NSD_EXPERIMENT_DIR_OBJ_A, NSD_EXPERIMENT_DIR_OBJ_B)
			%
			% Returns 1 if the two NSD_EXPERIMENT_DIR objects have the same
			% path and reference fields. They do not have to be the same handles
			% (that is, have the same location in memory).
			%
				b = strcmp(nsd_experiment_dir_obj_a.reference,nsd_experiment_dir_obj_b.reference);
				if b,
					b = strcmp(nsd_experiment_dir_obj_a.path,nsd_experiment_dir_obj_b.path);
				end;
		end; % eq
	end; % methods

end % classdef


