classdef nsd_probe < handle
% NSD_PROBE - the base class for PROBES -- measurement or stimulation devices
%
% In NSD, a PROBE is an instance of an instrument that can be used to MEASURE
% or to STIMULATE.
%
% Typically, a probe is associated with an NSD_DEVICE that performs data acquisition or
% even control of a stimulator. 
%
% A probe is uniquely identified by 3 fields:
%    name      - the name of the probe
%    reference - the reference number of the probe
%    type      - the type of probe (see type NSD_PROBETYPE2OBJECTINIT)
%
% Examples:
%    A multichannel extracellular electrode might be named 'extra', have a reference of 1, and
%    a type of 'n-trode'. 
%
%    If the electrode is moved, one should change the name or the reference to indicate that 
%    the data should not be attempted to be combined across the two positions. One might change
%    the reference number to 2.
%
% How to make a probe:
%    (Talk about epochcontents records of devices, probes are created from these elements.)
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
			% PROBE_EPOCH_CONTENTS is a 1xN cell array of NSD_EPOCHCONTENTS object with all of the
			% EPOCHCONTENTS entries that match NSD_PROBE_OBJ. 	
			% DEVEPOCH is a 1xN array with the device's epoch number that contains each probe epoch.
			
				probe_epoch_contents = {}; 
				devepoch = [];
				D = nsd_probe_obj.experiment.device_load('name','(.*)');
				if ~iscell(D), D = {D}; end; % make sure it has cell form
				for d=1:numel(D),
					NUM = D{d}.filetree.numepochs();
					for n=1:NUM,
						ec = D{d}.getepochcontents(n);
						for k=1:numel(ec),
							if strcmp(ec(k).name,nsd_probe_obj.name) && ...
								(ec(k).reference==nsd_probe_obj.reference) &&  ...
								strcmp(lower(ec(k).type),lower(nsd_probe_obj.type)),  % we have a match
								if numel(probe_epoch_contents)<n,
									probe_epoch_contents{n} = {};
								end
								probe_epoch_contents{n}{end+1} = ec(k);
								devepoch(n) = n;
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
			% This is simply PROBESTR = [NSD_PROBE_OBJ.name ' _ ' in2str(NSD_PROBE_OBJ.reference)]
			%
				probestr = [nsd_probe_obj.name ' _ ' int2str(nsd_probe_obj.reference) ];

		end

		function [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(nsd_probe_obj, epoch)
			% GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for NSD_PROBE
			%
			% [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NSD_PROBE_OBJ, EPOCH)
			%
			% Given an NSD_PROBE object and an EPOCH number, this functon returns the corresponding channel and device info.
			% Suppose there are C channels corresponding to a probe. Then the outputs are
			%   DEV is a 1xC cell array of NSD_DEVICE objects for each channel
			%   DEVNAME is a 1xC cell array of the names of each device in DEV
			%   DEVEPOCH is a 1xC array with the number of the probe's EPOCH on each device
			%   CHANNELTYPE is a cell array of the type of each channel
			%   CHANNELLIST is the channel number of each channel.
			%
				[n, probe_epoch_contents, devepochs] = numepochs(nsd_probe_obj);
				if ~(epoch >=1 & epoch <= n),
					error(['Requested epoch out of range of 1 .. ' int2str(n) '.']);
		                end

				dev = {};
				devname = {};
				devepoch = [];
				channeltype = {};
				channellist = [];
				
				for ec = 1:numel(probe_epoch_contents{epoch}),
					devstr = nsd_devicestring(probe_epoch_contents{epoch}{ec}.devicestring);
					[devname_here, channeltype_here, channellist_here] = devstr.nsd_devicestring2channel();
					dev{end+1} = nsd_probe_obj.experiment.device_load('name', devname_here);
					devname = cat(2,devname,devname_here);
					devepoch = cat(2,devepoch,devepochs(epoch));
					channeltype = cat(2,channeltype,channeltype_here);
					channellist = cat(2,channellist,channellist_here);
				end

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
