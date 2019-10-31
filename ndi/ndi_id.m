classdef ndi_id

	properties (SetAccess=protected,GetAccess=public)
		id
	end % properties

	methods
		function obj = ndi_id(id)
			if nargin > 0
				% CHECK check it is a proper id
				obj.id = id;
			else
				obj.id = ndi_unique_id;
			end
		end
	end
end