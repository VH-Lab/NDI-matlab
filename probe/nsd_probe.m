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

 		function [N, probe_epoch_contents, devepoch] = numepochs(nsd_probe_obj)
			% NUMEPOCHS - return number of epochs and epoch information for NSD_PROBE
			%
			% [N, PROBE_EPOCH_CONTENTS, DEVEPOCH] = NUMEPOCHS(NSD_PROBE_OBJ)
			%
			% Returns N, the number of all epochs of any NSD_DEVICE in the experiment
			% NSD_PROBE_OBJ.exp that contain the NSD_PROBE_OBJ name, reference, and type.
			%
			% PROBE_EPOCH_CONTENTS is a 1xN NSD_EPOCHCONTENTS object with all of the
			% EPOCHCONTENTS entries that match NSD_PROBE_OBJ. 	
			% DEVEPOCH is a 1xN array with the device epoch that contains each probe epoch.
			
				probe_epoch_contents = nsd_epochcontents;
				probe_epoch_contents = probe_epoch_contents([]);
				devepoch = [];
				D = load(nsd_probe_obj.experiment.device,'name','(.*)');
				if ~iscell(D), D = {D}; end; % make sure it has cell form
				for d=1:numel(D),
					NUM = D{d}.filetree.numepochs();
					for n=1:NUM,
						ec = D{d}.getepochcontents(n);
						for k=1:numel(ec),
							if strcmp(ec(k).name,nsd_probe_obj.name) && ...
								(ec(k).reference==nsd_probe_obj.reference) &&  ...
								strcmp(lower(ec(k).type),lower(nsd_probe_obj.type)),  % we have a match
								probe_epoch_contents(end+1) = ec;
								devepoch(end+1) = n;
							end
						end
					end
				end
				N = numel(probe_epoch_contents);
		end % numepochs()

	end % methods
end
