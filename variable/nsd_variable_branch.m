classdef nsd_variable_branch < nsd_dbleaf_branch
	% NSD_VARIABLE_BRANCH - A variable directory class for NSD
	%
	% NSD_VARIABLE_BRANCH
	%
	%

	properties (GetAccess=public,SetAccess=protected)
	end

	methods
		function obj = nsd_variable_branch(parent, name, classnames, isflat)

			% NSD_VARIABLE_BRANCH - Create an NSD_VARIABLE_BRANCH object
			%
			%  OBJ = NSD_VARIABLE_BRANCH(PARENT, NAME, CLASSNAMES, [ISFLAT])
			%
			% Creates a variable directory to be linked to an NSD_EXPERIMENT
			% VARIABLE tree.
			%
			% PARENT must be an NSD_DBLEAF_BRANCH object, usually the variable list
			% associated with an NSD_EXPERIMENT. NAME may be any string and is the name
			% of the directory name. CLASSNAMES is a list of valid classes that may be 
			% added to this directory branch. ISFLAT is an optional argument that
			% indicates that the NSD_VARIABLE_BRANCH should be 'flat' and not allow additional
			% subdirectories.
			%

			loadfilename = '';
			emptyargs = 0;

			if nargin==0 | nargin==2,
				if nargin==2, loadfilename = parent; end; % it is a loadfilename
				parent='';
				path = '';
				name='';
				classnames={};
				emptyargs = 1;
			end

			if nargin<4,
				isflat = 0;
			end

			if ~isempty(parent)&~isa(parent,'nsd_dbleaf_branch'),
				error(['NSD_VARIABLE_BRANCH objects must be attached to NSD_DBLEAF_BRANCH objects.']);
			end;

			obj = obj@nsd_dbleaf_branch(parent,name,classnames,isflat);
			if ~isempty(loadfilename),
				obj = obj.readobjectfile(loadfilename);
			end;

		end % nsd_variable_branch

	end % methods
end % classdef


