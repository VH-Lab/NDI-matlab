% NDI_EXPERIMENT_DIR - NDI_EXPERIMENT_DIR object class - an experiment with an associated file directory
%

classdef ndi_experiment_dir < ndi_experiment
	properties (GetAccess=public,SetAccess=protected)
		path    % the file path of the experiment
	end

	methods
		function ndi_experiment_dir_obj = ndi_experiment_dir(reference, path)
			% NDI_EXPERIMENT_DIR - Create a new NDI_EXPERIMENT_DIR ndi_experiment_dir_object
			%
			%   E = NDI_EXPERIMENT_DIR(REFERENCE, PATHNAME)
			%
			% Creates an NDI_EXPERIMENT_DIR ndi_experiment_dir_object, or an experiment with an
			% associated directory. REFERENCE should be a unique reference for the
			% experiment and directory PATHNAME.
			%
			% One can also open an existing experiment by using
			%
			%  E = NDI_EXPERIMENT_DIR(PATHNAME)
			%
			% See also: NDI_EXPERIMENT, NDI_EXPERIMENT_DIR/GETPATH

				if nargin==1,
					path = reference;
					ref = 'temp';
				end

				ndi_experiment_dir_obj = ndi_experiment_dir_obj@ndi_experiment(reference);
				ndi_experiment_dir_obj.path = path;
				d = dir([ndi_experiment_dir_obj.ndipathname() filesep 'reference.txt']);
				if ~isempty(d),
					ndi_experiment_dir_obj.reference = strtrim(textfile2char([ndi_experiment_dir_obj.ndipathname() filesep 'reference.txt']));
				elseif nargin==1,
					error(['Could not load the REFERENCE field from the path ' ndi_experiment_dir_obj.ndipathname() '.']);
				end
				d = dir([ndi_experiment_dir_obj.ndipathname() filesep 'unique_reference.txt']);
				if ~isempty(d),
					ndi_experiment_dir_obj.unique_reference = strtrim(textfile2char([ndi_experiment_dir_obj.ndipathname() filesep 'unique_reference.txt']));
				else,
					warning(['Could not load the UNIQUE REFERENCE field from the path ' ndi_experiment_dir_obj.ndipathname() '. Making one']);
					ndi_experiment_dir_obj.unique_reference = ndi_unique_id();
				end

				d = dir([ndi_experiment_dir_obj.ndipathname() filesep 'iodevice_object_*']);
				if isempty(d),
					ndi_experiment_dir_obj.iodevice = ndi_dbleaf_branch(ndi_experiment_dir_obj.ndipathname(),'iodevice',{'ndi_iodevice'},1);
				else,
					ndi_experiment_dir_obj.iodevice = ndi_pickdbleaf([ndi_experiment_dir_obj.ndipathname() filesep d(1).name]);
				end;

				ndi_experiment_dir_obj.database = ndi_opendatabase(ndi_experiment_dir_obj.ndipathname(), ndi_experiment_dir_obj.unique_reference_string());

				d = dir([ndi_experiment_dir_obj.ndipathname() filesep '*syncgraph.ndi']);
				if isempty(d),
					ndi_experiment_dir_obj.syncgraph = ndi_syncgraph(ndi_experiment_dir_obj);
				else,
					ndi_experiment_dir_obj.syncgraph = ndi_experiment_dir_obj.syncgraph.readobjectfile(...
						[ndi_experiment_dir_obj.ndipathname filesep d(1).name]);
				end;

				str2text([ndi_experiment_dir_obj.ndipathname() filesep 'reference.txt'], ndi_experiment_dir_obj.reference);
				str2text([ndi_experiment_dir_obj.ndipathname() filesep 'unique_reference.txt'], ndi_experiment_dir_obj.unique_reference);
		end;
		
		function p = getpath(ndi_experiment_dir_obj)
			% GETPATH - Return the path of the experiment
			%
			%   P = GETPATH(NDI_EXPERIMENT_DIR_OBJ)
			%
			% Returns the path of an NDI_EXPERIMENT_DIR object.
			%
			% The path is some sort of reference to the storage location of
			% the experiment. This might be a URL, or a file directory.
			%
				p = ndi_experiment_dir_obj.path;
                end;

		function p = ndipathname(ndi_experiment_dir_obj)
			% NDSPATHNAME - Return the path of the NDI files within the experiment
			%
			% P = NDIPATHNAME(NDI_EXPERIMENT_DIR_OBJ)
			%
			% Returns the pathname to the NDI files in the NDI_EXPERIMENT_DIR object.
			%
			% It is the NDI_EXPERIMENT_DIR object's path plus [filesep '.ndi' ]

				ndi_dir = '.ndi';
				p = [ndi_experiment_dir_obj.path filesep ndi_dir ];
				if ~exist(p,'dir'),
					mkdir(p);
				end;
		end;

		function b = eq(ndi_experiment_dir_obj_a, ndi_experiment_dir_obj_b)
			% EQ - Are two NDI_EXPERIMENT_DIR objects equivalent?
			%
			% B = EQ(NDI_EXPERIMENT_DIR_OBJ_A, NDI_EXPERIMENT_DIR_OBJ_B)
			%
			% Returns 1 if the two NDI_EXPERIMENT_DIR objects have the same
			% path and reference fields. They do not have to be the same handles
			% (that is, have the same location in memory).
			%
				b = strcmp(ndi_experiment_dir_obj_a.reference,ndi_experiment_dir_obj_b.reference);
				if b,
					b = strcmp(ndi_experiment_dir_obj_a.path,ndi_experiment_dir_obj_b.path);
				end;
		end; % eq
	end; % methods

end % classdef


