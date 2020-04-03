classdef ndi_id

	properties (SetAccess=protected,GetAccess=public)
		identifier; % a unique identifier id for this object
	end % properties

	methods
		function obj = ndi_id(id_value)
			% NDI_ID - create a new NDI_ID object
			%
			% NDI_ID_OBJ = NDI_ID()
			%
			% Creates a new NDI_ID object and generates a unique id
			% that is stored in the property 'identifier'.
			%
			if nargin > 0
				% TODO: CHECK check it is a proper id
				obj.identifier = id_value;
			else
				obj.identifier = ndi_unique_id();
			end
		end

		function identifier = id(ndi_id_obj)
			% ID - return the identifier of an NDI_ID object
			% 
			% IDENTIFIER = ID(NDI_ID_OBJ)
			%
			% Returns the unique identifier of an NDI_ID object.
			%
				identifier = ndi_id_obj.identifier;
		end; % id()
	end
end

