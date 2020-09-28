classdef timemapping
% NDI.TIME.TIMEMAPPING - class for managing mapping of time across epochs and devices
%
% Describes mapping from one time base to another. The base class, ndi.time.timemapping, provides
% polynomial mapping, although usually only linear mapping is used.
% The property MAPPING is a vector of length N+1 that describes the coefficients of a
% polynomial such that:
%
% t_out = mapping(1)*t_in^N + mapping(2)*t_in^(N-1) + ... mapping(N)*t_in + mapping(N+1)
%
% Usually, one specifies a linear relationship only, with MAPPING = [scale shift] so that
%
% t_out = scale * t_in + shift
% 

        properties (SetAccess=protected,GetAccess=public)
		mapping  % mapping parameters; in the ndi.time.timemapping base class, this is a polynomial (see help POLYVAL)
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
		
        end % properties

        methods

		function ndi_timemapping_obj = timemapping(varargin)
			% ndi.time.timemapping
			%
			% NDI_TIMEMAPPING_OBJ = ndi.time.timemapping()
			%    or
			% NDI_TIMEMAPPING_OBJ = ndi.time.timemapping(MAPPING)
			%
			% Creates a new ndi.time.timemapping object. In this base class,
			% the ndi.time.timemapping object specifies a polynomial mapping
			% from one time base to another.
			% 
			% If the function is called with no input arguments, then
			% the trivial mapping MAPPING = [ 1 0 ] is used; this corresponds
			% to the polynomial t_out = 1*t_in + 0.
			%
			% Typically, the mapping is linear, so that MAPPING = [scale shift].
			%
			% See also: POLYVAL
			%
				if nargin==0,
					mapping = [1 0];
				elseif nargin==1,
					mapping = varargin{1};
				else,
					error(['Too many inputs to ndi.time.timemapping creator.']);
				end;

				ndi_timemapping_obj.mapping = mapping;
				
				try, 
					t_out = ndi_timemapping_obj.map(0);
				catch,
					error(['A test of the mapping with t_in = 0 failed: ' lasterr]);
				end
				
		end % ndi.time.timemapping

		function t_out = map(ndi_timemapping_obj, t_in)
			% MAP - perform a mapping from one time base to another
			%
			% T_OUT = MAP(NDI_TIMEMAPPING_OBJ, T_IN)
			%
			% Perform the mapping described by NDI_TIMEMAPPING_OBJ from one time base to another.
			%
			% In the base class ndi.time.timemapping, the mapping is a polynomial.
				t_out = polyval(ndi_timemapping_obj.mapping, t_in);
		end % map

	end % methods
end % class ndi.time.timemapping

