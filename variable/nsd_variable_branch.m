classdef nsd_variable_branch < nsd_dbleaf_branch
	% NSD_VARIABLE_BRANCH - A variable directory class for NSD
	%
	% NSD_VARIABLE_BRANCH
	%
	%

	properties (GetAccess=public,SetAccess=protected)
	end

	methods
		function obj = nsd_variable_branch(parent, name, isflat, isinmemory)

			% NSD_VARIABLE_BRANCH - Create an NSD_VARIABLE_BRANCH object
			%
			%  OBJ = NSD_VARIABLE_BRANCH(PARENT, NAME, [ISFLAT], [ISINMEMORY])
			%
			% Creates a variable directory to be linked to an NSD_EXPERIMENT
			% VARIABLE tree.
			%
			% PARENT must be an NSD_DBLEAF_BRANCH object, usually the variable list
			% associated with an NSD_EXPERIMENT. NAME may be any string and is the name
			% of the directory name.  ISFLAT is an optional argument that
			% indicates that the NSD_VARIABLE_BRANCH should be 'flat' and not allow additional
			% subdirectories. If ISINMEMORY is 1, then the object will never be written to disk, it will
			% only exist in memory.
			%

			loadfilename = '';
			classnames={'nsd_variable','nsd_variable_branch'};

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
				if ~isempty(parent)&~isa(parent,'nsd_dbleaf_branch'),
					error(['NSD_VARIABLE_BRANCH objects must be attached to NSD_DBLEAF_BRANCH objects.']);
				end;
			end

			obj = obj@nsd_dbleaf_branch(parent,name,classnames,isflat,isinmemory);
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename);
			end;

		end % nsd_variable_branch

		function obj = load_createbranch(nsd_variable_branch_obj, name)
			% LOAD_CREATE_BRANCH - load a variable from NSD_VARIABLE_BRANCH object, or create a new NSD_VARIABLE_BRANCH if it doesn't exist
			%
			% OBJ = LOAD_CREATEBRANCH(NSD_VARIABLE_BRANCH_OBJ, NAME)
			%
			% Checks to see if an object named 'NAME' exists in NSD_VARIABLE_BRANCH_OBJ. If so,
			% it is returned in OBJ. If not, a new NSD_VARIABLE_BRANCH with that name is created underneath
			% NSD_VARIABLE_BRANCH_OBJ, with default properties. 
			%
			% See also: NSD_VARIABLE_BRANCH/LOAD
			%
				obj = nsd_variable_branch_obj.load('name',name);
				if isempty(obj),
					obj = nsd_variable_branch(nsd_variable_branch_obj, name);
				end
		end % load_createbranch

		function [obj,parent_obj] = path2nsd_variable(nsd_variable_branch_obj, path, createit, lastis_nsdvariable)
			% PATH2NSD_VARIABLE- return an NSD_VARIABLE object or branch that is specified according to a path
			%
			% [OBJ,PARENT_OBJ] = PATH2NSD_VARIABLE(NSD_VARIABLE_BRANCH_OBJ, PATH, [CREATEIT], [LASTIS_NSDVARIABLE])
			%
			% Given a PATH of NSD_BRANCH_OBJECT names such as ['mydir1/mydir2/mydir3'],
			% this function returns in OBJ the NSD_VARIABLE_BRANCH object or NSD_VARIABLE object
			% at the end of the path. The NSD_VARIABLE_BRANCH that is the parent of OBJ is returned
			% in PARENT_OBJ.
			%
			% For example, if PATH is ['mydir1/mydir2/mydir3'], then the function
			% returns the NSD_VARIABLE_BRANCH object or NSD_VARIABLE object named
			% 'mydir3' that is a branch of 'mydir2', which is a branch of 'mydir1'.
			%
			% If CREATEIT is 1, then the paths will be created.  If CREATEIT is not
			% specified, it is taken to be 0.
			%
			% If LASTIS_NSDVARIABLE is 1, then the last object is not created as an NSD_VARIABLE_BRANCH
			% object if it does not exist. This allows a user to specify an NSD_VARIABLE object as the
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
					lastis_nsdvariable = 0;
				end;

				obj = [];

				names = split(path,nsd_branchsep);

				obj_here = nsd_variable_branch_obj;

				for i=1:numel(names),
					parent_obj = obj_here;
					obj_here = obj_here.load('name',names{i});
					if isempty(obj_here)
						if i==numel(names), % we are at the last step, perhaps special behavior
							if lastis_nsdvariable,
								return;
							end
						end
						if createit==1,
							obj_here = nsd_variable_branch(parent_obj, names{i});
						else,
							parent_obj = [];
							return; % we failed to follow the path, return obj, parent_obj = empty
						end
					end; % we just continue to the next layer
				end

				obj = obj_here;

		end % path2nsd_variable
	end % methods
end % classdef


