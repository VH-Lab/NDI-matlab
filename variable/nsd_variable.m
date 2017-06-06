classdef nsd_variable < handle
	% NSD_VARIABLE - A variable class for NSD
	%
	% NSD_VARIABLE
	%
	% NSD_VARIABLEs allow the systematic storage of named variables
	% with paticular values. They can be accessed from an NSD_EXPERIMENT
	% object.
	%

	properties (Access=protected)
		parent,      % The parent experiment or NSD_VARIABLE
		name,        % Name; needs to be a valid Matlab variable and valid filename (i.e., no : / \)
		class,       % A string describing the class of the data ('double', 'char', or 'bin')
		data,        % Data to be stored
		description, % A human-readable description of the variable's purpose
		history,     % A character string description of the variable's history (what created it, etc)
		children,    % Any children of this variable (must be NSD_VARIABLE objects); see NSD_VARIABLE/ADDCHILD
	end

	methods
		function obj = nsd_variable(parent, name, class, data, description, history)
			% NSD_VARIABLE - Create an NSD_VARIABLE object
			%
			%  OBJ = NSD_VARIABLE(PARENT, NAME, CLASS, DATA, DESCRIPTION, HISTORY)
			%
			%  Creates a variable to be linked to an experiment:
			%  PARENT      - the NSD_EXPERIMENT or NSD_VARIABLE that is the parent for the variable
			%  NAME        - the name for the variable; this must like be a valid Matlab variable name
			%                 (though Matlab keywords are allowed) and a valid filename (no ':', '/', and '\')
			%  CLASS       - a string describing the data; it may be 'double', 'char', or 'bin'
			%  DATA        - the data to be stored
			%  DESCRIPTION - a human-readable string description of the variable's contents and purpose
			%  HISTORY     - a character string description of the variable's history (what function created it,
			%                 parameters, etc)

			   % test for valid inputs
			if ~ (isa(parent,'nsd_experiment') | isa(parent,'nsd_variable')),
				error(['parent must be an NSD_EXPERIMENT or an NSD_VARIABLE object']);
			end;

			if ~islikevarname(name)
				error(['name must be like a valid Matlab variable name (begin with a letter, not have whitespace)']);
			elseif any(name==':') | any(name=='/') | any(name=='\')
				error(['name must not include characters : / \ ']);
			end;

			switch lower(class),
				case {'double','char','bin'},
					% do nothing
				otherwise,
					error(['class must be ''double'', ''char'', or ''bin''']);
			end;

			if ~ischar(description),
				error(['description must be a character string (it can be the empty string '''') .']);
			end;

			if ~ischar(history)
				error(['history must be a character string (it can be the empty string '''') .']);
			end;

			obj.parent=parent;
			obj.name=name;
			obj.class=class;
			obj.data=data;
			obj.description=description;
			obj.history=history;
			obj.children = [];

		end % nsd_variable

		function obj = addchild(obj, child)
			% ADDCHILD - Add a child to an NSD_VARIABLE object
			% 
			%  OBJ = ADDCHILD(OBJ, CHILD)
			%
			%  Adds the CHILD to the NSD_VARIABLE object OBJ. CHILD must be
			%  an NSD_VARIABLE object.
			%

			if ~isa(child,'nsd_variable'),
				error(['child must be an NSD_VARIABLE object']);
			end;
			obj.children(end+1) = child;
		end % addchild

		function obj = removechild(obj, indexes)
			% REMOVECHILD - remove a child or children from an NSD_VARIABLE object
			%
			% OBJ = REMOVECHILD(OBJ, INDEXES)
			%
			% Remove the children with indexes INDEXES.
			%

			N = numel(obj.children);
			if N==0,
				error(['No children to remove.']);
			end;
			if any(indexes)>N,
				error(['INDEXES cannot be greater than the number of children, in this case ' int2str(N) '.']);
			end;
			obj.children = obj.children(setdiff(1:N,indexes));
		end % removechild

	end % methods
end % classdef

