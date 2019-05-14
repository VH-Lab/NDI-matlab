classdef ndi_membranepotential < ndi_thing_timeseries
% NDI_MEMBRANEPOTENTIAL - measurements of a membrane potential
%
% 

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_membranepotential_obj = ndi_membranepotential(varargin)
		% NDI_MEMBRANEPOTENIAL - creates a membrane potential record from a probe
		%
		% NDI_MEMBRANEPOTENTIAL_OBJ = NDI_MEMBRANEPOTENTIAL(NAME, NDI_PROBE_OBJ)
		% or 
		% NDI_MEMBRANEPOTENTIAL_OBJ = NDI_MEMBRANEPOTENTIAL(NDI_DOCUMENT_OBJ)
		% 
		% Creates a membrane potential object that is recorded by a probe NDI_PROBE_OBJ.
		% 
			if nargin>=2,
				thing_name = varargin{1};
				ndi_probe_obj = varargin{2};
			end;

			if nargin==1,
				doc = varargin{1};
			end;

			ndi_membranepotential_obj.name = thing_name;
			ndi_membranepotential_obj.probe = ndi_probe_obj;

		end; % ndi_membranepotential()

		

	end; 

end
