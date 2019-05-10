classdef ndi_probe < ndi_epochset & ndi_documentservice
% NDI_PROBE - the base class for PROBES -- measurement or stimulation devices
%
% In NDI, a PROBE is an instance of an instrument that can be used to MEASURE
% or to STIMULATE.
%
% Typically, a probe is associated with an NDI_IODEVICE that performs data acquisition or
% even control of a stimulator. 
%
% A probe is uniquely identified by 3 fields:
%    experiment- the experiment where the probe is used
%    name      - the name of the probe
%    reference - the reference number of the probe
%    type      - the type of probe (see type NDI_PROBETYPE2OBJECTINIT)
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
		experiment   % The handle of an NDI_EXPERIMENT object with which the NDI_PROBE is associated
		name         % The name of the probe; this must start with a letter and contain no whitespace
		reference    % The reference number of the probe; must be a non-negative integer
		type         % The probe type; must start with a letter and contain no whitespace, and there is a standard list
	end

	methods
		function obj = ndi_probe(experiment, name, reference, type)
			% NDI_PROBE - create a new NDI_PROBE object
			%
			%  OBJ = NDI_PROBE(EXPERIMENT, NAME, REFERENCE, TYPE)
			%
			%  Creates an NDI_PROBE associated with an NDI_EXPERIMENT object EXPERIMENT and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  NDI_PROBE is an abstract class, and a specific implementation must be called.
			%
				if nargin==0,
					experiment = [];
					name = [];
					reference = 1;
					type = 'empty';
				end

				if ~isempty(experiment) & ~isa(experiment, 'ndi_experiment'),
					error(['experiment must be a member of the NDI_EXPERIMENT class.']);
				end
				if ~isempty(name) & ~islikevarname(name),
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
		end % ndi_probe

		function et = buildepochtable(ndi_probe_obj)
			% BUILDEPOCHTABLE - build the epoch table for an NDI_PROBE
			%
			% ET = BUILDEPOCHTABLE(NDI_PROBE_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch (may change)
			% 'epoch_id'                | The epoch ID code (will never change once established)
			%                           |   This uniquely specifies the epoch.
			% 'epochcontents'           | The epochcontents object from each epoch
                        % 'epoch_clock'             | A cell array of NDI_CLOCKTYPE objects that describe the type of clocks available
                        % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each NDI_CLOCKTYPE, the start and stop
                        %                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
			% 'underlying_epochs'       | A structure array of the ndi_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

				ue = emptystruct('underlying','epoch_id','epochcontents','epoch_clock','t0_t1');
				et = emptystruct('epoch_number','epoch_id','epochcontents','epoch_clock','t0_t1','underlying_epochs');

				% pull all the devices from the experiment and look for device strings that match this probe

				D = ndi_probe_obj.experiment.iodevice_load('name','(.*)');
				if ~iscell(D), D = {D}; end; % make sure it has cell form

				d_et = {};

				for d=1:numel(D),
					d_et{d} = epochtable(D{d});

					for n=1:numel(d_et{d}),
						underlying_epochs = emptystruct('underlying','epoch_id','epochcontents','epoch_clock');
						underlying_epochs(1).underlying = D{d};
						if any(ndi_probe_obj.epochcontentsmatch(d_et{d}(n).epochcontents)),
							%underlying_epochs.epoch_number = n;
							underlying_epochs.epoch_id = d_et{d}(n).epoch_id;
							underlying_epochs.epochcontents = d_et{d}(n).epochcontents;
							underlying_epochs.epoch_clock = d_et{d}(n).epoch_clock;
							underlying_epochs.t0_t1 = d_et{d}(n).t0_t1;
							et_ = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
							et_(1).epoch_number = 1+numel(et);
							et_(1).epoch_id = d_et{d}(n).epoch_id; % this is an unambiguous reference
							et_(1).epochcontents = []; % not applicable for ndi_probe objects
							et_(1).epoch_clock = d_et{d}(n).epoch_clock; % inherit the clock
							et_(1).t0_t1 = d_et{d}(n).t0_t1; % inherit the time
							et_(1).underlying_epochs = underlying_epochs;
							et(end+1) = et_;
						end
					end
				end
		end % buildepochtable

		function ec = epochclock(ndi_probe_obj, epoch_number)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_PROBE_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch.
			%
			% The NDI_PROBE class always returns the clock type(s) of the device it is based on
			%
				et = ndi_probe_obj.epochtableentry(epoch_number);
				ec = et.epoch_clock;
		end % epochclock

		function b = issyncgraphroot(ndi_epochset_obj)
			% ISSYNCGRAPHROOT - should this object be a root in an NDI_SYNCGRAPH epoch graph?
			%
			% B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
			%
			% This function tells an NDI_SYNCGRAPH object whether it should continue 
			% adding the 'underlying' epochs to the graph, or whether it should stop at this level.
			%
			% For NDI_EPOCHSET and NDI_PROBE this returns 0 so that the underlying NDI_IODEVICE epochs are added.
				b = 0;
		end % issyncgraphroot

                function [cache,key] = getcache(ndi_probe_obj)
			% GETCACHE - return the NDI_CACHE and key for NDI_PROBE
			%
			% [CACHE,KEY] = GETCACHE(NDI_PROBE_OBJ)
			%
			% Returns the CACHE and KEY for the NDI_PROBE object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the probe's PROBESTRING.
			%
			% See also: NDI_FILETREE, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_probe_obj.experiment,'handle'),,
					exp = ndi_probe_obj.experiment();
					cache = exp.cache;
					key = ndi_probe_obj.probestring;
				end
		end

		function name = epochsetname(ndi_probe_obj)
			% EPOCHSETNAME - the name of the NDI_PROBE object, for EPOCHNODES
			%
			% NAME = EPOCHSETNAME(NDI_PROBE_OBJ)
			%
			% Returns the object name that is used when creating epoch nodes.
			%
			% For NDI_PROBE objects, this is the string 'probe: ' followed by
			% PROBESTRING(NDI_PROBE_OBJ).
				name = ['probe: ' probestring(ndi_probe_obj)];
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
				probestr = [ndi_probe_obj.name ' _ ' int2str(ndi_probe_obj.reference) ];
		end

		function [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(ndi_probe_obj, epoch_number_or_id)
			% GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for NDI_PROBE
			%
			% [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NDI_PROBE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Given an NDI_PROBE object and an EPOCH number, this function returns the corresponding channel and device info.
			% Suppose there are C channels corresponding to a probe. Then the outputs are
			%   DEV is a 1xC cell array of NDI_IODEVICE objects for each channel
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
						for k=1:numel(et(i).underlying_epochs(j).epochcontents),
							if ndi_probe_obj.epochcontentsmatch(et(i).underlying_epochs(j).epochcontents(k)),
								devstr = ndi_iodevicestring(et(i).underlying_epochs(j).epochcontents(k).devicestring);
								[devname_here, channeltype_here, channellist_here] = devstr.ndi_iodevicestring2channel();
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

		function b = epochcontentsmatch(ndi_probe_obj, epochcontents)
			% EPOCHCONTENTSMATCH - does an epochcontents record match our probe?
			%
			% B = EPOCHCONTENTSMATCH(NDI_PROBE_OBJ, EPOCHCONTENTS)
			%
			% Returns 1 if the NDI_EPOCHCONTENTS object EPOCHCONTENTS is a match for
			% the NDI_PROBE_OBJ probe and 0 otherwise.
			%
				b = strcmp(ndi_probe_obj.name,{epochcontents.name}) & ...
					([epochcontents.reference]==ndi_probe_obj.reference) &  ...
					strcmp(lower(ndi_probe_obj.type),lower({epochcontents.type}));  % we have a match
		end % epochcontentsmatch()

		function ndi_document_obj = newdocument(ndi_probe_obj, epochid)
			% NEWDOCUMENT - return a new database document of type NDI_DOCUMENT based on a probe
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_PROBE_OBJ, [EPOCHID])
			%
			% Fill out the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_probe'
			% with the corresponding 'name' and 'reference' fields of the probe NDI_PROBE_OBJ.
			% If EPOCHID is provided, then an EPOCHID field is filled out as well
			% in accordance to 'ndi_document_epochid'.
			%
				ndi_document_obj = ndi_probe_obj.experiment.newdocument('ndi_document_probe',...
					'probe.name',ndi_probe_obj.name,'probe.type',ndi_probe_obj.type,...
					'probe.reference',ndi_probe_obj.reference);

				if nargin>1,
					newdoc = ndi_probe_obj.experiment.newdocument('ndi_document_epochid',...
						'epochid', epochid);
					ndi_document_obj = ndi_document_obj + newdoc;
				end
		end; % newdocument

		function sq = searchquery(ndi_probe_obj, epochid)
			% SEARCHQUERY - return a search query for an NDI_DOCUMENT based on this probe
			%
			% SQ = SEARCHQUERY(NDI_PROBE_OBJ, [EPOCHID])
			%
			% Returns a search query for the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_probe'
			% with the corresponding 'name' and 'reference' fields of the probe NDI_PROBE_OBJ.
			% If EPOCHID is provided, then an EPOCHID field is filled out as well.
			%
				sq = {'ndi_document.experiment_unique_reference',...
					ndi_probe_obj.experiment.unique_reference_string(),...
					'probe.name',ndi_probe_obj.name,...
					'probe.type',ndi_probe_obj.type,...
					'probe.reference',ndi_probe_obj.reference};

				if nargin>1,
					sq = cat(2,sq,{'epochid',epochid});
				end
		end;
	end % methods
end
