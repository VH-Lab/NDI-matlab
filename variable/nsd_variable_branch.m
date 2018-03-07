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
			end

			if ~isempty(parent)&~isa(parent,'nsd_dbleaf_branch'),
				error(['NSD_VARIABLE_BRANCH objects must be attached to NSD_DBLEAF_BRANCH objects.']);
			end;

			obj = obj@nsd_dbleaf_branch(parent,name,classnames,isflat,isinmemory);
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename);
			end;

		end % nsd_variable_branch

	end % methods
end % classdef


