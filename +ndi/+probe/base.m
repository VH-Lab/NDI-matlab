classdef probe < ndi.element.base & ndi.documentservice
% ndi.probe.base - the base class for PROBES -- measurement or stimulation devices
%
% In NDI, a PROBE is an instance of an instrument that can be used to MEASURE
% or to STIMULATE.
%
% Typically, a probe is associated with an ndi.daq.system that performs data acquisition or
% even control of a stimulator. 
%
% A probe is uniquely identified by 3 fields and an session:
%    session- the session where the probe is used
%    name      - the name of the probe
%    reference - the reference number of the probe
%    type      - the type of probe (see type ndi.fun.probetype2objectinit)
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
%    (Talk about epochprobemap records of devices, probes are created from these elements.)
%   

	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = probe(varargin)
			% ndi.probe.base - create a new ndi.probe.base object
			%
			%  OBJ = ndi.probe.base(SESSION, NAME, REFERENCE, TYPE, SUBJECT_ID)
			%         or
			%  OBJ = ndi.probe.base(SESSION, NDI_DOCUMENT_OBJ)
			%
			%  Creates an ndi.probe.base associated with an ndi.session.base object SESSION and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  ndi.probe.base is a essentially an abstract class, and a specific implementation must be called.
			%
				inputs = varargin;
				if nargin==5,
					inputs{7} = varargin{5};
					inputs{5} = [];
					inputs{6} = 1;
				end;
				obj = obj@ndi.element.base(inputs{:});
		end % ndi.probe.base

		function et = buildepochtable(ndi_probe_obj)
			% BUILDEPOCHTABLE - build the epoch table for an ndi.probe.*
			%
			% ET = BUILDEPOCHTABLE(NDI_PROBE_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch (may change)
			% 'epoch_id'                | The epoch ID code (will never change once established)
			%                           |   This uniquely specifies the epoch.
			% 'epoch_session_id'           | The ID of the session
			% 'epochprobemap'           | The epochprobemap object from each epoch
                        % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
                        % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
                        %                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
			% 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

				ue = vlt.data.emptystruct('underlying','epoch_id','epoch_session_id','epochprobemap','epoch_clock','t0_t1');
				et = vlt.data.emptystruct('epoch_number','epoch_id','epoch_session_id','epochprobemap','epoch_clock','t0_t1','underlying_epochs');

				% pull all the devices from the session and look for device strings that match this probe

				D = ndi_probe_obj.session.daqsystem_load('name','(.*)');
				if ~iscell(D), D = {D}; end; % make sure it has cell form

				d_et = {};

				for d=1:numel(D),
					d_et{d} = epochtable(D{d});

					for n=1:numel(d_et{d}),
						% for each epoch in this device
						underlying_epochs = vlt.data.emptystruct('underlying','epoch_id','epoch_session_id', 'epochprobemap','epoch_clock');
						underlying_epochs(1).underlying = D{d};
						match_probe_and_device = [];
						H = find(ndi_probe_obj.epochprobemapmatch(d_et{d}(n).epochprobemap));
						for h=1:numel(H),
							daqst = ndi.daq.daqsystemstring(d_et{d}(n).epochprobemap(H(h)).devicestring);
							if strcmpi(D{d}.name,daqst.devicename),
								match_probe_and_device(end+1) = H(h);
							end;
						end;
						if ~isempty(match_probe_and_device),
							%underlying_epochs.epoch_number = n;
							underlying_epochs.epoch_id = d_et{d}(n).epoch_id;
							underlying_epochs.epoch_session_id = d_et{d}(n).epoch_session_id;
							underlying_epochs.epochprobemap = d_et{d}(n).epochprobemap(match_probe_and_device);
							underlying_epochs.epoch_clock = d_et{d}(n).epoch_clock;
							underlying_epochs.t0_t1 = d_et{d}(n).t0_t1;
							et_ = vlt.data.emptystruct('epoch_number','epoch_id','epoch_session_id','epochprobemap','underlying_epochs');
							et_(1).epoch_number = 1+numel(et);
							et_(1).epoch_id = d_et{d}(n).epoch_id; % this is an unambiguous reference
							et_(1).epoch_session_id = d_et{d}(n).epoch_session_id; % this is an unambiguous reference
							et_(1).epochprobemap = []; % not applicable for ndi.probe.* objects
							et_(1).epoch_clock = d_et{d}(n).epoch_clock; % inherit the clock
							et_(1).t0_t1 = d_et{d}(n).t0_t1; % inherit the time
							et_(1).underlying_epochs = underlying_epochs;
							et(end+1) = et_;
						end
					end
				end
		end % buildepochtable

		function ec = epochclock(ndi_probe_obj, epoch_number)
			% EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_PROBE_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch.
			%
			% The ndi.probe.base class always returns the clock type(s) of the device it is based on
			%
				et = ndi_probe_obj.epochtableentry(epoch_number);
				ec = et.epoch_clock;
		end % epochclock

		function b = issyncgraphroot(ndi_epochset_obj)
			% ISSYNCGRAPHROOT - should this object be a root in an ndi.time.syncgraph epoch graph?
			%
			% B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
			%
			% This function tells an ndi.time.syncgraph object whether it should continue 
			% adding the 'underlying' epochs to the graph, or whether it should stop at this level.
			%
			% For ndi.epoch.epochset and ndi.probe.* this returns 0 so that the underlying ndi.daq.system epochs are added.
				b = 0;
		end % issyncgraphroot

		function name = epochsetname(ndi_probe_obj)
			% EPOCHSETNAME - the name of the ndi.probe.* object, for EPOCHNODES
			%
			% NAME = EPOCHSETNAME(NDI_PROBE_OBJ)
			%
			% Returns the object name that is used when creating epoch nodes.
			%
			% For ndi.probe.base objects, this is the string 'probe: ' followed by
			% PROBESTRING(NDI_PROBE_OBJ).
				name = ['probe: ' elementstring(ndi_probe_obj)];
		end % epochsetname

		function probestr = probestring(ndi_probe_obj)
			% PROBESTRING - Produce a human-readable probe string
			%
			% PROBESTR = PROBESTRING(NDI_PROBE_OBJ)
			%
			% Returns the name and reference of a probe as a human-readable string.
			%
			% This is simply PROBESTR = [NDI_PROBE_OBJ.name ' _ ' in2str(NDI_PROBE_OBJ.reference)]
			%
				warning('depricated, use elementstring()');
				probestr = [ndi_probe_obj.name ' _ ' int2str(ndi_probe_obj.reference) ];
		end

		function [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(ndi_probe_obj, epoch_number_or_id)
			% GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for ndi.probe.*
			%
			% [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NDI_PROBE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Given an ndi.probe.* object and an EPOCH number, this function returns the corresponding channel and device info.
			% Suppose there are C channels corresponding to a probe. Then the outputs are
			%   DEV is a 1xC cell array of ndi.daq.system objects for each channel
			%   DEVNAME is a 1xC cell array of the names of each device in DEV
			%   DEVEPOCH is a 1xC array with the epoch id of the probe's EPOCH on each device
			%   CHANNELTYPE is a cell array of the type of each channel
			%   CHANNELLIST is the channel number of each channel.
			%
				et = epochtable(ndi_probe_obj);

				if ischar(epoch_number_or_id),
					epoch_number = find(strcmpi(epoch_number_or_id, {et.epoch_id}));
					if isempty(epoch_number),
						error(['Could not identify epoch with id ' epoch_number_or_id '.']);
					end
				else,
					epoch_number = epoch_number_or_id;
				end

				if epoch_number>numel(et),
		 			error(['Epoch number ' epoch_number ' out of range 1..' int2str(numel(et)) '.']);
				end;

				et = et(epoch_number);

				dev = {};
				devname = {};
				devepoch = {};
				channeltype = {};
				channellist = [];
				
				for i = 1:numel(et),
					for j=1:numel(et(i).underlying_epochs),
						for k=1:numel(et(i).underlying_epochs(j).epochprobemap),
							if ndi_probe_obj.epochprobemapmatch(et(i).underlying_epochs(j).epochprobemap(k)),
								devstr = ndi.daq.daqsystemstring(et(i).underlying_epochs(j).epochprobemap(k).devicestring);
								[devname_here, channeltype_here, channellist_here] = devstr.ndi_daqsystemstring2channel();
								dev{end+1} = et(i).underlying_epochs.underlying; % underlying device
								devname = cat(2,devname,devname_here);
								devepoch = cat(2,devepoch,{et(i).underlying_epochs(j).epoch_id});
								channeltype = cat(2,channeltype,channeltype_here);
								channellist = cat(2,channellist,channellist_here);
							end
						end
					end
				end

		end % getchanneldevinfo(ndi_probe_obj, epoch)

		function b = epochprobemapmatch(ndi_probe_obj, epochprobemap)
			% EPOCHPROBEMAPMATCH - does an epochprobemap record match our probe?
			%
			% B = EPOCHPROBEMAPMATCH(NDI_PROBE_OBJ, EPOCHPROBEMAP)
			%
			% Returns 1 if the ndi.epoch.epochprobemap object EPOCHPROBEMAP is a match for
			% the NDI_PROBE_OBJ probe and 0 otherwise.
			%
				b = strcmp(ndi_probe_obj.name,{epochprobemap.name}) & ...
					([epochprobemap.reference]==ndi_probe_obj.reference) &  ...
					strcmp(lower(ndi_probe_obj.type),lower({epochprobemap.type}));  % we have a match
		end % epochprobemapmatch()

		function b = eq(ndi_probe_obj1, ndi_probe_obj2)
			% EQ - are 2 ndi.probe.base objects equal?
			%
			% Returns 1 if the objects share an object class, session, and probe string.
			%
				b = 0;
				if isa(ndi_probe_obj2,'ndi.probe.base'),
					b = ( ndi_probe_obj1.session==ndi_probe_obj2.session & ...
						strcmp(ndi_probe_obj1.elementstring(), ndi_probe_obj2.elementstring()) & ...
						strcmp(ndi_probe_obj1.type, ndi_probe_obj2.type) );
				end;
		end; % eq()
	end % methods
end


