classdef nsd_probe 
% NSD_PROBE - Create a new NSD_PROBE class handle object
%
	properties (GetAccess=public, SetAccess=protected)
		experiment   % The handle of an NSD_EXPERIMENT object with which the NSD_PROBE is associated
		name         % The name of the probe; this must start with a letter and contain no whitespace
		reference    % The reference number of the probe; must be a non-negative integer
		type         % The probe type; must start with a letter and contain no whitespace, and there is a standard list
	end

	methods
		function obj = nsd_probe(experiment, name, reference, type)
			% NSD_PROBE - create a new NSD_PROBE object
			%
			%  OBJ = NSD_PROBE(EXPERIMENT, NAME, REFERENCE, TYPE)
			%
			%  Creates an NSD_PROBE associated with an NSD_EXPERIMENT object EXPERIMENT and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  NSD_PROBE is an abstract class, and a specific implementation must be called.
			%

				if ~isa(experiment, 'nsd_experiment'),
					error(['experiment must be a member of the NSD_EXPERIMENT class.']);
				end
				if ~islikevarname(name),
					error(['name must start with a letter and contain no whitespace']);
				end
				if ~islikevarname(type),
					error(['type must start with a letter and contain no whitespace']);
				end
				if ~(isint(reference) & reference >= 0)
					error(['reference must be a non-negative integer.']);
				end

				obj.experiment = experiment;
				obj.name = name;
				obj.reference = reference;
				obj.type = type;

		end % nsd_probe

	end % methods
end
