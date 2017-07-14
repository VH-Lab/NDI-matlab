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
			% DEVEPOCH is a 1xN array with the device's epoch number that contains each probe epoch.
			
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

		function probestr = probestring(nsd_probe_obj)
			% PROBESTRING - Produce a human-readable probe string
			%
			% PROBESTR = PROBESTRING(NSD_PROBE_OBJ)
			%
			% Returns the name and reference of a probe as a human-readable string.
			%
			% This is simply PROBESTR = [NSD_PROBE_OBJ.name ' | ' in2str(NSD_PROBE_OBJ.reference)]
			%
				probestr = [nsd_probe_obj.name ' | ' int2str(nsd_probe_obj.reference) ];

		end

		function [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(nsd_probe_obj, epoch)
			% GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for NSD_PROBE
			%
			% [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NSD_PROBE_OBJ, EPOCH)
			%
			% Given an NSD_PROBE object and an EPOCH number, this functon returns the corresponding
			% NSD_DEVICE object DEV, the name of the device in DEVNAME, the epoch number, DEVEPOCH of the device that
			% corresponds to the probe's epoch, a cell array of CHANNELTYPEs, and an array of channels that
			% comprise the probe in CHANNELLIST. 
			%
				[n, probe_epoch_contents, devepochs] = numepochs(nsd_probe_obj);
				if ~(epoch >=1 & epoch <= n),
					error(['Requested epoch out of range of 1 .. ' int2str(n) '.']);
				end
				devstr = nsd_devicestring(probe_epoch_contents(epoch).devicestring);
				[devname, channeltype, channellist] = devstr.nsd_devicestring2channel();
				devepoch = devepochs(epoch);
				dev = load(nsd_probe_obj.experiment.device,'name', devname); % now we have the device handle
		end % getchanneldevinfo(nsd_probe_obj, epoch)

		function tag = getepochtag(nsd_probe_obj, number)
			% GETEPOCHTAG - Get tag(s) from an epoch
			%
			% TAG = GETEPOCHTAG(NSD_PROBE_OBJ, EPOCHNUMBER)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				[dev,devname,devepoch] = nsd_probe_obj.getchanneldevinfo(number);
				tag = dev.getepochtag(devepoch);
		end % getepochtag()

		function setepochtag(nsd_probe_obj, number, tag)
			% SETEPOCHTAG - Set tag(s) for an epoch
			%
			% SETEPOCHTAG(NSD_PROBE_OBJ, EPOCHNUMBER, TAG)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. These tags will replace any
			% tags in the epoch directory. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				[dev,devname,devepoch] = nsd_probe_obj.getchanneldevinfo(number);
				dev.setepochtag(devepoch, tag);
		end % setepochtag()

		function addepochtag(nsd_probe_obj, number, tag)
			% ADDEPOCHTAG - Add tag(s) for an epoch
			%
			% ADDEPOCHTAG(NSD_PROBE_OBJ, EPOCHNUMBER, TAG)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. These tags will be added to any
			% tags in the epoch EPOCHNUMBER. If tags with the same names as those in TAG
			% already exist, they will be overwritten. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				[dev,devname,devepoch] = nsd_probe_obj.getchanneldevinfo(number);
				dev.addepochtag(devepoch, tag);
		end % addepochtag()

		function removeepochtag(nsd_probe_obj, number, name)
			% REMOVEEPOCHTAG - Remove tag(s) for an epoch
			%
			% REMOVEEPOCHTAG(NSD_PROBE_OBJ, EPOCHNUMBER, NAME)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. Any tags with name 'NAME' will
			% be removed from the tags in the epoch EPOCHNUMBER.
			% tags in the epoch directory. If tags with the same names as those in TAG
			% already exist, they will be overwritten. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
			% NAME can be a single string, or it can be a cell array of strings
			% (which will result in the removal of multiple tags).
			%
				[dev,devname,devepoch] = nsd_probe_obj.getchanneldevinfo(number);
				dev.removeepochtag(devepoch,name);
		end % removeepochtag()

	end % methods
end
