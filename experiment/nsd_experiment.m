classdef nsd_experiment < handle
	% NSD_EXPERIMENT - NSD_EXPERIMENT object class

	properties (GetAccess=public, SetAccess = protected)
		reference         % A string reference for the experiment
		variable          % An array of NSD_VARIABLE_BRANCH objects associated with this experiment
		iodevice          % An array of NSD_IODEVICE objects associated with this experiment
		syncgraph         % An NSD_SYNCGRAPH object related to this experiment
		cache             % An NSD_CACHE object for the experiment's use
	end
	properties (GetAccess=protected, SetAccess = protected)
	end
	methods
		function nsd_experiment_obj = nsd_experiment(reference)
			% nsd_experiment - Create a new NSD_EXPERIMENT object
			%
			%   NSD_EXPERIMENT_OBJ=NSD_EXPERIMENT(REFERENCE)
			%
			% Creates a new NSD_EXPERIMENT object. The experiment has a unique
			% reference REFERENCE. This class is an abstract class and typically
			% an end user will open a specific subclass such as NSD_EXPERIMENT_DIR.
			%
			% NSD_EXPERIMENT objects can access 0 or more NSD_IODEVICE objects.
			%
			% See also: NSD_EXPERIMENT/IODEVICE_ADD, NSD_EXPERIMENT/IODEVICE_RM, 
			%   NSD_EXPERIMENT/GETPATH, NSD_EXPERIMENT/GETREFERENCE

				nsd_experiment_obj.reference = reference;
				nsd_experiment_obj.iodevice = nsd_dbleaf_branch('','device',{'nsd_iodevice'},1);
				nsd_experiment_obj.database = nsd_variable_branch('','database',0);
				nsd_experiment_obj.syncgraph = nsd_syncgraph(nsd_experiment_obj);
				nsd_experiment_obj.cache = nsd_cache();
		end

		%%%%%% DEVICE METHODS

		function nsd_experiment_obj = iodevice_add(nsd_experiment_obj, dev)
			%IODEVICE_ADD - Add a sampling device to a NSD_EXPERIMENT object
			%
			%   NSD_EXPERIMENT_OBJ = IODEVICE_ADD(NSD_EXPERIMENT_OBJ, DEV)
			%
			% Adds the device DEV to the NSD_EXPERIMENT NSD_EXPERIMENT_OBJ
			%
			% The devices can be accessed by referencing NSD_EXPERIMENT_OBJ.device
			%  
			% See also: IODEVICE_RM, NSD_EXPERIMENT

				if ~isa(dev,'nsd_iodevice'),
					error(['dev is not a nsd_iodevice']);
				end;
				nsd_experiment_obj.iodevice.add(dev);
			end 
		function nsd_experiment_obj = iodevice_rm(nsd_experiment_obj, dev)
			% IODEVICE_RM - Remove a sampling device from an NSD_EXPERIMENT object
			%
			%   NSD_EXPERIMENT_OBJ = IODEVICE_RM(NSD_EXPERIMENT_OBJ, DEV)
			%
			% Removes the device DEV from the device list.
			%
			% See also: IODEVICE_ADD, NSD_EXPERIMENT
			
				leaf = nsd_experiment_obj.iodevice.load('name',dev.name);
				if ~isempty(leaf),
					nsd_experiment_obj.iodevice.remove(leaf.objectfilename);
				else,
					error(['No iodevice named ' dev.name ' found.']);
				end
			end

		function dev = iodevice_load(nsd_experiment_obj, varargin)
			% LOAD - Load iodevice objects from an NSD_EXPERIMENT
			%
			% DEV = IODEVICE_LOAD(NSD_EXPERIMENT_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
			%         or
			% DEV = IODEVICE_LOAD(NSD_EXPERIMENT_OBJ, INDEXES)
			%
			% Returns the device object(s) in the NSD_EXPERIMENT at index(es) INDEXES or
			% searches for an object whose metadata parameters PARAMS1, PARAMS2, and so on, match
			% VALUE1, VALUE2, and so on (see NSD_DBLEAF_BRANCH/SEARCH).
			%
			% If more than one object is requested, then DEV will be a cell list of matching objects.
			% Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
			%
				dev = nsd_experiment_obj.iodevice.load(varargin{:});
				if numel(dev)==1,
					dev=dev.setexperiment(nsd_experiment_obj);
				else,
					for i=1:numel(dev),
						dev{i}=dev{i}.setexperiment(nsd_experiment_obj);
					end
				end
		end % ioiodevice_load()	

		% DATABASE / NSD_VARIABLE METHODS

		function nsd_experiment_obj = database_add(nsd_experiment_obj, var)
			%DATABASE_ADD - Add an NSD_VARIABLE to an NSD_EXPERIMENT object
			%
			%   NSD_EXPERIMENT_OBJ = DATABASE_ADD(NSD_EXPERIMENT_OBJ, VAR)
			%
			% Adds the NSD_VARIABLE VAR to the NSD_EXPERIMENT NSD_EXPERIMENT_OBJ
			%
			% The variable can be accessed by referencing NSD_EXPERIMENT_OBJ.database
			%  
			% See also: DATABASE_RM, NSD_EXPERIMENT

				if ~isa(var,'nsd_variable')|~isa(var,'nsd_variable_branch'), error(['var is not an NSD_VARIABLE']); end;
				nsd_experiment_obj.variable.add(var);
		end

		function nsd_experiment_obj = database_rm(nsd_experiment_obj, var)
			% DATABASE_RM - Remove an NSD_VARIABLE from an NSD_EXPERIMENT object
			%
			%   NSD_EXPERIMENT_OBJ = DATABASE_RM(NSD_EXPERIMENT_OBJ, VAR)
			%
			% 
			% Removes the variable VAR from the NSD_EXPERIMENT_OBJ.database.
			%
			% See also: DATABASE_ADD, NSD_EXPERIMENT
			
				leaf = nsd_experiment_obj.variable.load('name',var.name);
				if ~isempty(leaf),
					nsd_experiment_obj.variable.remove(leaf.objectfilename);
				else,
					error(['No variable named ' var.name ' found.']);
				end
		end

		function nsd_experiment_obj = syncgraph_addrule(nsd_experiment_obj, rule)
			% SYNCGRAPH_ADDRULE - add an NSD_SYNCRULE to the syncgraph
			%
			% NSD_EXPERIMENT_OBJ = SYNCGRAPH_ADDRULE(NSD_EXPERIMENT_OBJ, RULE)
			%
			% Adds the NSD_SYNCRULE RULE to the NSD_SYNCGRAPH of the NSD_EXPERIMENT
			% object NSD_EXPERIMENT_OBJ. 
			%
				nsd_experiment_obj.syncgraph = nsd_experiment_obj.syncgraph.addrule(rule);
		end % syncgraph_addrule

		function nsd_experiment_obj = syncgraph_rmrule(nsd_experiment_obj, index)
			% SYNCGRAPH_RMRULE - remove an NSD_SYNCRULE from the syncgraph
			%
			% NSD_EXPERIMENT_OBJ = SYNCGRAPH_RMRULE(NSD_EXPERIMENT_OBJ, INDEX)
			%
			% Removes the INDEXth NSD_SYNCRULE from the NSD_SYNCGRAPH of the NSD_EXPERIMENT
			% object NSD_EXPERIMENT_OBJ. 
			%
				nsd_experiment_obj.syncgraph = nsd_experiment_obj.syncgraph.removerule(index);

		end % syncgraph_rmrule

		%%%%%% PATH methods

		function p = getpath(nsd_experiment_obj)
			% GETPATH - Return the path of the experiment
			%
			%   P = GETPATH(NSD_EXPERIMENT_OBJ)
			%
			% Returns the path of an NSD_EXPERIMENT object.
			%
			% The path is some sort of reference to the storage location of 
			% the experiment. This might be a URL, or a file directory, depending upon
			% the subclass.
			%
			% In the NSD_EXPERIMENT class, this returns empty.
			%
			% See also: NSD_EXPERIMENT
			p = [];
		end

		%%%%%% REFERENCE methods

		function probes = getprobes(nsd_experiment_obj, varargin)
			% GETPROBES - Return all NSD_PROBES that are found in NSD_IODEVICE epoch contents entries
			%
			% PROBES = GETPROBES(NSD_EXPERIMENT_OBJ, ...)
			%
			% Examines all NSD_IODEVICE entries in the NSD_EXPERIMENT_OBJ's device array
			% and returns all NSD_PROBE entries that can be constructed from each device's
			% NSD_EPOCHCONENTS entries.
			%
			% PROBES is a cell array of NSD_PROBE objects.
			%
			% One can pass additional arguments that specify the classnames of the probes
			% that are returned:
			%
			% PROBES = GETPROBES(NSD_EXPERIMENT_OBJ, CLASSMATCH1, CLASSMATCH2, ...)
			%
			% Only probes that are members of the classes CLASSMATCH1, CLASSMATCH2, etc., are
			% returned.
			%
				probestruct = [];
				devs = nsd_experiment_obj.iodevice_load('name','(.*)');
				if ~isempty(devs),
					probestruct = getprobes(celloritem(devs,1));
				end
				for d=2:numel(devs),
					probestruct = cat(1,probestruct,getprobes(devs{d}));
				end
				probestruct = equnique(probestruct);
				probes = nsd_probestruct2probe(probestruct, nsd_experiment_obj);
				if numel(varargin)>0,
					include = [];
					for i=1:numel(probes),
						includehere = 1;
						for j=1:numel(varargin),
							includehere = includehere & isa(probes{i},varargin{j});
						end
						if includehere,
							include(end+1) = i;
						end
					end
					probes = probes(include);
				end
		end % getprobes

	end % methods
end % classdef
