classdef nsd_synctable < nsd_base

	NOTE ONLY IN MY IMAGINATION RIGHT NOW

	% NSD_SYNCTABLE - A class for managing synchronization across NSD_CLOCK objects
	%

	properties (SetAccess=protected,GetAccess=public),
		entries % entries of the NSD_SYNCTABLE
		G  % adjacency matrix of clocks for construction of a graph
	end % properties
	methods
		function obj = nsd_synctable
			% NSD_SYNCTABLE - Creates a new NSD_SYNCTABLE object
			%
			% OBJ = NSD_SYNCTABLE()
			%
			% Creates an empty NSD_SYNCTABLE object.
			%
			obj=obj@nsd_base;
			obj.entries = emptystruct('clock1','clock2','rule','ruleparameters','cost','valid_range');
			obj.G = [];
		end % nsd_synctable()
			
		function nsd_synctable_obj = add(nsd_synctable_obj, clock1, clock2, rule, ruleparameters, cost, valid_range)

		end % add()

		function nsd_synctable_obj = remove(nsd_synctable_obj, index)
		
		end % remove()

		function epoch = epoch_overlap(nsd_synctable_obj, clock, epoch, t0, t1)

		end % epoch_overlap()

		function t = convert(nsd_synctable_obj, source_clock, source_t0, destination_clock)

		end % convert

	end % methods
end % nsd_synctable class

 % rule example: 
 %   'isequal' % they are the same, no parameters
 %   'commontriggers' % they acquire a common trigger
 %      parameters: dev1channel:'dev1:m1', dev2channel: 'dev2:d3'
 %  


