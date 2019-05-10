classef ndi_thing < ndi_epochset & ndi_documentservice 
% NDI_THING - define or examine a thing in the experiment
%
	properties (SetAccess=protected, GetAccess=public)
		name
		type
		probe    % we need the probe so we can resolve timerefs

	end % properties

	methods
		function ndi_thing_obj = ndi_thing(thing_name, ndi_probe_obj)
			if ~isa(ndi_probe_obj, 'ndi_probe'),
				error(['NDI_PROBE_OBJ must be of type NDI_PROBE']);
			end;
			ndi_thing_obj.name = ndi_probe_obj.thing_name;
			ndi_thing_obj.probe = ndi_probe_obj;
		end; % ndi_thing()

	% NDI_EPOCHSET methods

		function ec = epochclock(ndi_thing_obj, epoch_number)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_THING_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch.
			%
			% The NDI_THING class always returns the clock type(s) of the probe it is based on
			%
				% make sure to call it by epochid because epoch_number of probe might not
				% match the ndi_thing, if the thing is sometimes not recorded by the probe (when it's hiding)
				ec = ndi_thing_obj.probe.epochclock(ndi_thing_obj.epochid(epoch_number));
		end; % epochclock

		function b = issyncgraphroot(ndi_thing_obj)
			% ISSYNCGRAPHROOT - should this object be a root in an NDI_SYNCGRAPH epoch graph?
			%
			% B = ISSYNCGRAPHROOT(NDI_THING_OBJ)
			%
			% This function tells an NDI_SYNCGRAPH object whether it should continue
			% adding the 'underlying' epochs to the graph, or whether it should stop at this level.
			%
			% For NDI_THING objects, this returns 0 so that underlying NDI_PROBE epochs are added.
				b = 0;
		end; % issyncgraphroot

		function name = epochsetname(ndi_thing_obj)
			% EPOCHSETNAME - the name of the NDI_THING object, for EPOCHNODES
			%
			% NAME = EPOCHSETNAME(NDI_THING_OBJ)
			%
			% Returns the object name that is used when creating epoch nodes.
			%
			% For NDI_THING objects, this is NDI_THING/THINGSTRING. 
				name = ndi_thing_obj.thingstring;
		end; % epochsetname

		function ec = epochclock(ndi_thing_obj, epoch_number)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_THING_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch.
			%
			% The NDI_THING class always returns the clock type(s) of the probe it is based on
			%
				et = epochtableentry(ndi_thing_obj.probe, epoch_number);
				ec = et.epoch_clock;
		end; % epochclock()

		function t0t1 = t0_t1(ndi_thing_obj, epoch_number)
			% 
			% T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the NDI_CLOCKTYPE objects returned by EPOCHCLOCK.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: NDI_CLOCKTYPE, EPOCHCLOCK
			%
				t0t1 = ndi_thing_obj.t0_t1(epoch_number);
		end; % t0t1()

		function [cache,key] = getcache(ndi_thing_obj)
			% GETCACHE - return the NDI_CACHE and key for NDI_THING
			%
			% [CACHE,KEY] = GETCACHE(NDI_THING_OBJ)
			%
			% Returns the CACHE and KEY for the NDI_THING object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the probe's PROBESTRING plus the name of the THING.
			%
			% See also: NDI_FILETREE, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_thing_obj.probe.experiment,'handle'),,
					exp = ndi_thing_obj.probe.experiment();
					cache = exp.cache;
					key = [ndi_thing_obj.thingstring ' | ' ndi_thing_obj.probe.probestring()];
				end
		end; % getcache()

		function et = buildepochtable(ndi_thing_obj)
			% BUILDEPOCHTABLE - build the epoch table for an NDI_THING
			%
			% ET = BUILDEPOCHTABLE(NDI_THING_OBJ)
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

				probe_et = ndi_thing_obj.probe.epochtable();

				% 
				% here figure out the epochs that are present
				% for now, punt
				epochs_here = 1:numel(probe_et); 
				probe_et = probe_et(epochs_here);

				for n=1:numel(probe_et),
					et_ = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
					et_(1).epoch_number = n;
					et_(1).epoch_id = probe_et(n).epoch_id;
					et_(1).epochcontents = []; % not applicable for ndi_thing objects
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

		%% unique NDI_THING methods

		function thingstr = thingstring(ndi_thing_obj)
			% THINGSTRING - Produce a human-readable thing string
			%
			% THINGSTR = THINGSTRING(NDI_THING_OBJ)
			%
			% Returns the name as a human-readable string.
			%
			% For NDI_THING objects, this is the string 'thing: ' followed by its name
			% 
				name = ['thing: ' name];
		end; %thingstring() 

		function ndi_thing_obj = addepoch(ndi_thing_obj, epochid, epochclock, t0_t1, timepoints, datapoints)
			% ADDEPOCH - add an epoch to the NDI_THING
			%
			% NDI_THING_OBJ = ADDEPOCH(NDI_THING_OBJ, EPOCHID, EPOCHCLOCK, T0_T1, TIMEPOINTS, DATAPOINTS)
			%
			% Registers the data for an epoch with the NDI_THING_OBJ.
			%
			% Inputs:
			%   NDI_THING_OBJ: The NDI_THING object to modify
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

		function et_added = loadaddedepochs(ndi_thing_obj)
			% LOADADDEDEPOCHS - load the added epochs from an NDI_THING
			%
			% ET_ADDED = LOADADDEDEOPCHS(NDI_THING_OBJ)
			%
			% Load the EPOCHTABLE that consists of added/registered epochs that provide information
			% about the NDI_THING.
			%
			% 
				% loads from database
				

		end; % LOADEDEPOCHS(NDI_THING_OBJ)

	%%% NDI_DOCUMENTSERVICE methods

		function ndi_document_obj = newdocument(ndi_thing_obj, epochid)
			% NEWDOCUMENT - return a new database document of type NDI_DOCUMENT based on a thing
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_THING_OBJ, [EPOCHID])
			%
			% Fill out the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_thing'
			% with the corresponding 'name' and 'type' fields of the thing NDI_THING_OBJ and the 
			% 'name', 'type', and 'reference' fields of its underlying NDI_PROBE_OBJ. 
			% If EPOCHID is provided, then an EPOCHID field is filled out as well
			% in accordance to 'ndi_document_epochid'.
			%
				ndi_document_obj = ndi_thing_obj.experiment.newdocument('ndi_document_thing',...
					'thing.ndi_thing_class', class(ndi_thing_obj), ...
					'thing.name',ndi_thing_obj.name,'thing.type',ndi_thing_obj.type) + 
						ndi_thing_obj.probe.newdocument();
		end; % newdocument

		function sq = searchquery(ndi_thing_obj)
			% SEARCHQUERY - return a search query for an NDI_DOCUMENT based on this thing
			%
			% SQ = SEARCHQUERY(NDI_THING_OBJ)
			%
			% Returns a search query for the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_thing'
			% with the corresponding 'name' and 'type' fields of the thing NDI_THING_OBJ.
			%
				sq = ndi_thing_obj.probe.searchquery();
				sq = cat(2,sq, ...
					{'thing.name',ndi_thing_obj.name,...
					 'thing.type',ndi_thing_obj.type,...
					 'thing.ndi_thing_class', classname(ndi_thing_obj) });
		end;

	end; % methods

end % classdef


