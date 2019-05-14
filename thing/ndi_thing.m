classef ndi_thing < ndi_epochset & ndi_documentservice 
% NDI_THING - define or examine a thing in the experiment
%
	properties (SetAccess=protected, GetAccess=public)
		name
		type
		probe    % we need the probe so we can resolve timerefs
		direct   % is it direct from a probe (1) or do observations need to be added by other software?

	end % properties

	methods
		function ndi_thing_obj = ndi_thing(thing_name, ndi_probe_obj)
			% NDI_THING_OBJ = NDI_THING - creator for NDI_THING
			%
			% NDI_THING_OBJ = NDI_THING(THING_NAME, NDI_PROBE_OBJ)
			%    or
			% NDI_THING_OBJ = NDI_THING(THING_DOCUMENT, NDI_EXPERIMENT_OBJ)
			%
			% Creates an NDI_THING object, either from a name and and associated NDI_PROBE object,
			% or builds the NDI_THING in memory from an NDI_DOCUMENT of type 'ndi_document_thing'.
			%
				% NEED EDIT HERE
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

				if nsd_thing_obj.direct,
					ib = 1:numel(probe_et);
					ia = 1:numel(probe_et);
				else,
					et_added = ndi_thing_obj.loadaddedepochs();
					[c,ia,ib] = intersect({et_added.epoch_id}, {probe_et.epoch_id});
				end

				for n=1:numel(ia),
					et_ = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
					et_(1).epoch_number = n;
					et_(1).epoch_id = probe_et(ib(n)).epoch_id;
					et_(1).epochcontents = []; % not applicable for ndi_thing objects
					if nsd_thing_obj.direct,
						et_(1).epoch_clock = probe_et(ib(n)).epoch_clock;
						et_(1).t0_t1 = probe_et(ib(n)).t0_t1; 
					else,
						et_(1).epoch_clock = et_added(ia(n)).epoch_clock;
						et_(1).t0_t1 = et_added(ia(n).t0_t1);
					end;
					underlying_epochs = emptystruct('underlying','epoch_id','epochcontents','epoch_clock');
					underlying_epochs(1).underlying = probe_et(ib(n));
					underlying_epochs.epoch_id = probe_et(ib(n)).epoch_id;
					underlying_epochs.epochcontents = probe_et(ib(n)).epochcontents;
					underlying_epochs.epoch_clock = probe_et(ib(n)).epoch_clock;
					underlying_epochs.t0_t1 = probe_et(ib(n)).t0_t1;
				
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

		function E = experiment(ndi_thing_obj)
			% EXPERIMENT - the NDI_EXPERIMENT object associated with an NDI_THING
			%
			% E = EXPERIMENT(NDI_THING_OBJ)
			%
			% Return the NDI_EXPERIMENT associated with an NDI_THING.
			%
			% (Returns the thing's probe's 'experiment' parameter.)
			%
				E = nsd_thing_obj.probe.experiment;
		end; % experiment

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
				if ndi_thing_obj.direct,
					error(['Cannot add external observations to an NDI_THING that is directly based on NDI_PROBE.']);
				end;
				E = [];
				if ~isempty(ndi_thing_obj.probe),
					E = ndi_thing_obj.probe.experiment; 
				end;
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
				et_added = emptystruct('epoch_number','epoch_id','epochcontents','epoch_clock','t0_t1','underlying_epochs');
				if nsd_thing_obj.direct,
					% nothing can be added
					return; 
				end;
				% loads from database
				thing_doc = ndi_thing_obj.load_thing_doc();
				if ~isempty(thing_doc),
					sq = {'thing_epoch.thing_unique_reference', ...
						thing_doc.document_properties.ndi_document.document_unique_reference};
					E = ndi_thing_obj.experiment();
					epochdocs = E.database.search(sq);

					if ~isempty(epochdocs),
						for i=1:numel(epochdocs),
							newet.epoch_number = i;
							newet.epoch_id = epochdocs{i}.document_properties.epoch.epochid;
							newet.epochcontents = '';
							newet.epoch_clock = epochdocs{i}.document_properties.thing_epoch.epoch_clock;
							newet.t0_t1 = epochdocs{i}.document_properties.thing_epoch.t0_t1;
							newet.underlyingepochs = []; % leave this for buildepochtable
						end;
						et_added(end+1) = newt;
					end
				end;
		end; % LOADEDEPOCHS(NDI_THING_OBJ)

		function thing_doc = load_thing_doc(ndi_thing_obj)
			% LOAD_THING_DOC - load a thing doc from the experiment database
			%
			% THING_DOC = LOAD_THING_DOC(NDI_THING_OBJ)
			%
			% Load an NDI_DOCUMENT that is based on the NDI_THING object.
			%
			% Returns empty if there is no such document.
			%
				sq = ndi_thing_obj.searchquery();
				E = ndi_thing_obj.experiment;
				thing_doc = E.database.search(sq);
		end; % load_thing_doc

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
				ndi_document_obj = newdocument(ndi_thing_obj.experiment(), 'ndi_document_thing',...
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


