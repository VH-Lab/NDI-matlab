classdef nsd_dbleaf 
	% NSD_DBLEAF - A node that fits into an NSD_DBTREE
	%
	%

	properties (GetAccess=public,SetAccess=protected)
                name           % String name; this must be like a valid Matlab variable name and not include file separators (:,/,\)
		objectfilename % Unique name that can be used to store the item in a file on disk
		metadatanames  % Cell list of metadata fields
	end % properties

	methods
		function obj = nsd_dbleaf(name, isfile)
			% NSD_DBLEAF - Creates a named NSD_DBLEAF object
			%
			% OBJ = NSD_DBLEAF(NAME)
			%
			% Creates an NSD_DBLEAF object with name NAME. NAME must be like
			% a valid Matlab variable, although Matlab keywords are allowed.
			% In addition, file separators such as ':', '/', and '\' are not 
			% allowed.
			%
			% In an alternate construction, one may call
			%   OBJ = NSD_DBLEAF(FILENAME, ISFILE)
			% with ISFILE set to 1, and the object will be created by
			% reading in data from the file FILENAME (full path).
			%  
			% See also: NSD_DBTREE

			if nargin==0, % undocumented dummy version
				obj = nsd_dbleaf('dummy');
			end

			if nargin==1,
				isfile = 0;
			end

			if isfile,
				obj = nsd_dbleaf('dummy');
				obj = obj.readobjectfile(name);  % this will change the object's identity, might be an error, depends on Matlab error checking
			else,
				if islikevarname(name) & isempty(intersect(name,':/\')),
					obj.name = name;
					obj.objectfilename = ['object_' num2hex(now) '_' num2hex(rand) ]; % use time and randomness to ensure uniqueness
					obj.metadatanames = {'objectfilename'};
				else,
					error(['name ' name ' is not like a valid Matlab variable name, or contains :, /, or \.']); 
				end
			end

		end % nsd_dbleaf

		function mds = metadatastruct(nsd_dbleaf_obj)
			% METADATASTRUCT - return a structure with metadata for NSD_DBLLEAF_OBJ
			%
			% MDS = METADATASTRUCT(NSD_DBLEAF_OBJ)
			%
			% Returns a structure with field names NSD_DBLEAF_OBJ.metadatanames and
			% values equal to the respective property values of NSD_DBLEAF_OBJ.

			mds = struct;

			for i=1:numel(nsd_dbleaf_obj.metadatanames),
				mds = setfield(mds, nsd_dbleaf_obj.metadatanames{i}, getfield(nsd_dbleaf_obj, nsd_dbleaf_obj.metadatanames{i}) );
			end

		end % metadatastruct

		function obj = readobjectfile(nsd_dbleaf_obj, filename)
			% READOBJECTFILE - read the object from a file
			%
			% OBJ = READOBJECTFILE(NSD_DBLEAF_OBJ, FILENAME)
			%
			% Reads the NSD_DBLEAF_OBJ from the file FILENAME.
			%

				fid = fopen(filename, 'rb'); % files will consistently use big-endian
				if fid<0,
					error(['Could not open the file ' filename ' for reading.']);
				end;
				
				classname = fgetl(fid);

				if strcmp(classname,'nsd_dbleaf'),
					% we have a plain nsd_dbleaf object, let's read it
					obj = nsd_dbleaf_obj;
					obj.name = fgetl(fid);
					obj.objectfilename = fgetl(fid);
					fclose(fid);
				else,
					fclose(fid);
					eval(['obj = ' classname '();']);  % in many languages this would be bogus
					obj = obj.readobjectfile(filename);
				end;

		end % readobjectfile

		function nsd_dbleaf_obj=writeobjectfile(nsd_dbleaf_obj, dirname)
			% WRITEOBJECTFILE - write the object file to a file
			% 
			% WRITEOBJECTFILE(NSD_DBLEAF_OBJ, DIRNAME)
			%
			% Writes the NSD_DBLEAF_OBJ to a file in a manner that can be
			% read by the creator function NSD_DBLEAF.
			%
			% Writes to the path DIRNAME/NSD_DBLEAF_OBJ.OBJECTFILENAME
			%
			% See also: NSD_DBLEAF/NSD_DBLEAF
			%
				filename = [dirname filesep nsd_dbleaf_obj.objectfilename];
				fid = fopen(filename,'wb');	% files will consistently use big-endian
				if fid < 0,
					error(['Could not open the file ' filename ' for writing.']);
				end;

				data = { class(nsd_dbleaf_obj) nsd_dbleaf_obj.name  nsd_dbleaf_obj.objectfilename };

				for i=1:length(data),
					count = fprintf(fid,'%s\n',data{i});
					if count~=numel(data{i})+1,
						error(['Error writing to the file ' filename '.']);
					end
				end

				fclose(fid)

		end % writeobjectfile

	end % methods 

end
