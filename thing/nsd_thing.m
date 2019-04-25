classef nsd_thing < nsd_epochset % or should it be nsd_epochset? or should it be nsd_probe?
% NSD_THING - define or examine a thing in the experiment
%
	properties (SetAccess=protected, GetAccess=public)
		name
		type
		probe    % we need the probe so we can resolve timerefs

	end % properties

	methods
		function nsd_thing_obj = nsd_thing(thing_name, nsd_probe_obj)
			if ~isa(nsd_probe_obj, 'nsd_probe'),
				error(['NSD_PROBE_OBJ must be of type NSD_PROBE']);
			end;
			nsd_thing_obj.name = nsd_probe_obj.thing_name;
			nsd_thing_obj.probe = nsd_probe_obj;
		end; % nsd_thing()

	% NSD_EPOCHSET methods

		function ec = epochclock(nsd_thing_obj, epoch_number)
			% EPOCHCLOCK - return the NSD_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NSD_THING_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch.
			%
			% The NSD_THING class always returns the clock type(s) of the probe it is based on
			%
				% make sure to call it by epochid because epoch_number of probe might not
				% match the nsd_thing, if the thing is sometimes not recorded by the probe (when it's hiding)
				ec = nsd_thing_obj.probe.epochclock(nsd_thing_obj.epochid(epoch_number));
		end; % epochclock

		function b = issyncgraphroot(nsd_thing_obj)
			% ISSYNCGRAPHROOT - should this object be a root in an NSD_SYNCGRAPH epoch graph?
			%
			% B = ISSYNCGRAPHROOT(NSD_THING_OBJ)
			%
			% This function tells an NSD_SYNCGRAPH object whether it should continue
			% adding the 'underlying' epochs to the graph, or whether it should stop at this level.
			%
			% For NSD_THING objects, this returns 0 so that underlying NSD_PROBE epochs are added.
				b = 0;
		end; % issyncgraphroot

		function name = epochsetname(nsd_thing_obj)
			% EPOCHSETNAME - the name of the NSD_THING object, for EPOCHNODES
			%
			% NAME = EPOCHSETNAME(NSD_THING_OBJ)
			%
			% Returns the object name that is used when creating epoch nodes.
			%
			% For NSD_THING objects, this is NSD_THING/THINGSTRING. 
				name = nsd_thing_obj.thingstring;
		end; % epochsetname

		function ec = epochclock(nsd_thing_obj, epoch_number)
			% EPOCHCLOCK - return the NSD_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NSD_THING_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch.
			%
			% The NSD_THING class always returns the clock type(s) of the probe it is based on
			%
				et = epochtableentry(nsd_thing_obj.probe, epoch_number);
				ec = et.epoch_clock;
		end; % epochclock()

		function t0t1 = t0_t1(nsd_thing_obj, epoch_number)
			% 
			% T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NSD_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the NSD_CLOCKTYPE objects returned by EPOCHCLOCK.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: NSD_CLOCKTYPE, EPOCHCLOCK
			%
				t0t1 = nsd_thing_obj.t0_t1(epoch_number);
		end; % t0t1()

		function [cache,key] = getcache(nsd_thing_obj)
			% GETCACHE - return the NSD_CACHE and key for NSD_THING
			%
			% [CACHE,KEY] = GETCACHE(NSD_THING_OBJ)
			%
			% Returns the CACHE and KEY for the NSD_THING object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the probe's PROBESTRING plus the name of the THING.
			%
			% See also: NSD_FILETREE, NSD_BASE

				cache = [];
				key = [];
				if isa(nsd_thing_obj.probe.experiment,'handle'),,
					exp = nsd_thing_obj.probe.experiment();
					cache = exp.cache;
					key = [nsd_thing_obj.thingstring ' | ' nsd_thing_obj.probe.probestring()];
				end
		end; % getcache()

		function et = buildepochtable(nsd_thing_obj)
			% BUILDEPOCHTABLE - build the epoch table for an NSD_THING
			%
			% ET = BUILDEPOCHTABLE(NSD_THING_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch (may change)
			% 'epoch_id'                | The epoch ID code (will never change once established)
			%                           |   This uniquely specifies the epoch.
			% 'epochcontents'           | The epochcontents object from each epoch
			% 'epoch_clock'             | A cell array of NSD_CLOCKTYPE objects that describe the type of clocks available
			% 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each NSD_CLOCKTYPE, the start and stop
			%                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

				ue = emptystruct('underlying','epoch_id','epochcontents','epoch_clock','t0_t1');
				et = emptystruct('epoch_number','epoch_id','epochcontents','epoch_clock','t0_t1','underlying_epochs');

				% pull all the devices from the experiment and look for device strings that match this probe

				probe_et = nsd_thing_obj.probe.epochtable();

				% 
				% here figure out the epochs that are present
				% for now, punt
				epochs_here = 1:numel(probe_et); 
				probe_et = probe_et(epochs_here);

				for n=1:numel(probe_et),
					et_ = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
					et_(1).epoch_number = n;
					et_(1).epoch_id = probe_et(n).epoch_id;
					et_(1).epochcontents = []; % not applicable for nsd_thing objects
					et_(1).epoch_clock = probe_et(n).epoch_clock;
					et_(1).t0_t1 = probe_et(n).t0_t1;  % this should really be something else, the thing might not entirely overlap the probe
					underlying_epochs = emptystruct('underlying','epoch_id','epochcontents','epoch_clock');
					underlying_epochs(1).underlying = epochs_here(n);
					underlying_epochs.epoch_id = probe_et(n).epoch_id;
					underlying_epochs.epochcontents = probe_et(n).epochcontents;
					underlying_epochs.epoch_clock = probe_et(n).epoch_clock;
					underlying_epochs.t0_t1 = probe_et(n).t0_t1;
				
					et_(1).underlying_epochs = underlying_epochs;
					et(end+1) = et_;
				end

		end; % buildepochtable

		%% unique NSD_THING methods

		function thingstr = thingstring(nsd_thing_obj)
			% THINGSTRING - Produce a human-readable thing string
			%
			% THINGSTR = THINGSTRING(NSD_THING_OBJ)
			%
			% Returns the name as a human-readable string.
			%
			% For NSD_THING objects, this is the string 'thing: ' followed by its name
			% 
				name = ['thing: ' name];
		end; %thingstring() 

		function nsd_thing_obj = addepoch(nsd_thing_obj, epochid, epochclock, t0_t1, timepoints, datapoints)
			% ADDEPOCH - add an epoch to the NSD_THING
			%
			% NSD_THING_OBJ = ADDEPOCH(NSD_THING_OBJ, EPOCHID, EPOCHCLOCK, T0_T1, TIMEPOINTS, DATAPOINTS)
			%
			% Registers the data for an epoch with the NSD_THING_OBJ.
			%
			% Inputs:
			%   NSD_THING_OBJ: The NSD_THING object to modify
			%   EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
			%   EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
			%                     of the probe
			%   T0_T1:         The starting time and ending time of the existence of information about the THING on
			%                     the probe, in units of the epock clock
			%   TIMEPOINTS:    the time points to be added to this epoch; can also be the string 'probe' which means the
			%                     points are read directly from the probe (must be Tx1). Timepoints must be in the units
			%                     of the EPOCHCLOCK.
			%   DATAPOINTS:    the data points that accompany each timepoint (must be TxXxY...), or can be 'probe' to 
			%                     read from the probe
			%   

		end; % addepoch()


		function et_added = loadaddedepochs(nsd_thing_obj)
			% LOADADDEDEPOCHS - load the added epochs from an NSD_THING
			%
			% ET_ADDED = LOADADDEDEOPCHS(NSD_THING_OBJ)
			%
			% Load the EPOCHTABLE that consists of added/registered epochs that provide information
			% about the NSD_THING.
			%
			% 

				% loads from database
				

		end; % LOADEDEPOCHS(NSD_THING_OBJ)

	% newdocument
	% searchquery

	end; % methods

end % classdef


