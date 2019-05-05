classdef ndi_variable_branch < ndi_dbleaf_branch
	% NDI_VARIABLE_BRANCH - A variable directory class for NDI
	%
	% NDI_VARIABLE_BRANCH
	%
	%

	properties (GetAccess=public,SetAccess=protected)
	end

	methods
		function obj = ndi_variable_branch(parent, name, isflat, isinmemory)

			% NDI_VARIABLE_BRANCH - Create an NDI_VARIABLE_BRANCH object
			%
			%  OBJ = NDI_VARIABLE_BRANCH(PARENT, NAME, [ISFLAT], [ISINMEMORY])
			%
			% Creates a variable directory to be linked to an NDI_EXPERIMENT
			% VARIABLE tree.
			%
			% PARENT must be an NDI_DBLEAF_BRANCH object, usually the variable list
			% associated with an NDI_EXPERIMENT. NAME may be any string and is the name
			% of the directory name.  ISFLAT is an optional argument that
			% indicates that the NDI_VARIABLE_BRANCH should be 'flat' and not allow additional
			% subdirectories. If ISINMEMORY is 1, then the object will never be written to disk, it will
			% only exist in memory.
			%

			loadfilename = '';
			classnames={'ndi_variable','ndi_variable_branch'};

			if nargin==0 | nargin==2,
				if nargin==2 & strcmp(lower(name),lower('OpenFile')) & ischar(parent),
					loadfilename = parent;
				end; % it is a loadfilename
				if ~isempty(loadfilename) | nargin==0,
					parent='';
					path = '';
					name='';
				end
			end

			if nargin<4,
				isinmemory = 0;
			end

			if nargin<3,
				isflat = 0;
			else,
				if ~isnumeric(isflat), error(['isflat must be numeric (0/1).']); end;
			end

			if 0,
				if ~isempty(parent)&~isa(parent,'ndi_dbleaf_branch'),
					error(['NDI_VARIABLE_BRANCH objects must be attached to NDI_DBLEAF_BRANCH objects.']);
				end;
			end

			obj = obj@ndi_dbleaf_branch(parent,name,classnames,isflat,isinmemory);
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename);
			end;

		end % ndi_variable_branch

		function obj = load_createbranch(ndi_variable_branch_obj, name)
			% LOAD_CREATE_BRANCH - load a variable from NDI_VARIABLE_BRANCH object, or create a new NDI_VARIABLE_BRANCH if it doesn't exist
			%
			% OBJ = LOAD_CREATEBRANCH(NDI_VARIABLE_BRANCH_OBJ, NAME)
			%
			% Checks to see if an object named 'NAME' exists in NDI_VARIABLE_BRANCH_OBJ. If so,
			% it is returned in OBJ. If not, a new NDI_VARIABLE_BRANCH with that name is created underneath
			% NDI_VARIABLE_BRANCH_OBJ, with default properties. 
			%
			% See also: NDI_VARIABLE_BRANCH/LOAD
			%
				obj = ndi_variable_branch_obj.load('name',name);
				if isempty(obj),
					obj = ndi_variable_branch(ndi_variable_branch_obj, name);
				end
		end % load_createbranch

		function [obj,parent_obj] = path2ndi_variable(ndi_variable_branch_obj, path, createit, lastis_ndivariable)
			% PATH2NDI_VARIABLE- return an NDI_VARIABLE object or branch that is specified according to a path
			%
			% [OBJ,PARENT_OBJ] = PATH2NDI_VARIABLE(NDI_VARIABLE_BRANCH_OBJ, PATH, [CREATEIT], [LASTIS_NDIVARIABLE])
			%
			% Given a PATH of NDI_BRANCH_OBJECT names such as ['mydir1/mydir2/mydir3'],
			% this function returns in OBJ the NDI_VARIABLE_BRANCH object or NDI_VARIABLE object
			% at the end of the path. The NDI_VARIABLE_BRANCH that is the parent of OBJ is returned
			% in PARENT_OBJ.
			%
			% For example, if PATH is ['mydir1/mydir2/mydir3'], then the function
			% returns the NDI_VARIABLE_BRANCH object or NDI_VARIABLE object named
			% 'mydir3' that is a branch of 'mydir2', which is a branch of 'mydir1'.
			%
			% If CREATEIT is 1, then the paths will be created.  If CREATEIT is not
			% specified, it is taken to be 0.
			%
			% If LASTIS_NDIVARIABLE is 1, then the last object is not created as an NDI_VARIABLE_BRANCH
			% object if it does not exist. This allows a user to specify an NDI_VARIABLE object as the
			% last entry of the path and to create the rest of the path.
			%
			% If there is no object at that path and CREATEIT is 0, then OBJ will be empty.
			%
			% See also: 
			%
				if nargin<3,
					createit = 0;
				end;
				if nargin<4,
					lastis_ndivariable = 0;
				end;

				obj = [];
				parent_obj = [];

				if isempty(path),
					return;
				end

				indexes = findstr(path,[ndi_branchsep ndi_branchsep]);
				path(indexes) = [];
				if path(end)==ndi_branchsep, % do not end in a branch for this function
					path(end) = [];
				end;

				names = split(path,ndi_branchsep);

				obj_here = ndi_variable_branch_obj;

				for i=1:numel(names),
					parent_obj = obj_here;
					obj_here = obj_here.load('name',names{i});
					if isempty(obj_here)
						if i==numel(names), % we are at the last step, perhaps special behavior
							if lastis_ndivariable,
								return;
							end
						end
						if createit==1,
							obj_here = ndi_variable_branch(parent_obj, names{i});
						else,
							parent_obj = [];
							return; % we failed to follow the path, return obj, parent_obj = empty
						end
					end; % we just continue to the next layer
				end

				obj = obj_here;

		end % path2ndi_variable
	end % methods
end % classdef


