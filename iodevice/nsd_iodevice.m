classdef nsd_iodevice < nsd_dbleaf & nsd_epochset_param
% NSD_IODEVICE - Create a new NSD_DEVICE class handle object
%
%  D = NSD_IODEVICE(NAME, THEFILETREE)
%
%  Creates a new NSD_IODEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.

	properties (GetAccess=public, SetAccess=protected)
		filetree   % The NSD_FILETREE associated with this device
	end

	methods
		function obj = nsd_iodevice(name,thefiletree)
		% NSD_IODEVICE - create a new NSD_DEVICE object
		%
		%  OBJ = NSD_IODEVICE(NAME, THEFILETREE)
		%
		%  Creates an NSD_IODEVICE with name NAME and NSD_IODEVICE
		%  THEFILETREE. THEFILETREE is an interface object to the raw data files
		%  on disk that are read by the NSD_IODEVICE.
		%
		%  NSD_IODEVICE is an abstract class, and a specific implementation must be called.
		%

			loadfromfile = 0;

			if nargin==0, % undocumented 0 argument creator
				name = '';
				thefiletree = [];
			elseif nargin==2,
				if ischar(thefiletree), % it is a command
					loadfromfile = 1;
					filename = name;
					name='';
					if ~strcmp(lower(thefiletree), lower('OpenFile')),
						error(['Unknown command.']);
					else,
						thefiletree=[];
					end
				end;
			else,
				error(['Function requires 2 input arguments exactly.']);
			end

			obj = obj@nsd_dbleaf(name);
			if loadfromfile,
				obj = obj.readobjectfile(filename);
			else,
				obj.name = name;
				obj.filetree = thefiletree;
			end
			if isempty(obj.filetree),
				obj.epochcontents_class = 'nsd_epochcontents_iodevice';
			else,
				obj.epochcontents_class = obj.filetree.epochcontents_class;
			end;
		end % nsd_iodevice

		%% functions that used to override HANDLE, now just implement equal:

		function b = eq(nsd_iodevice_obj_a, nsd_iodevice_obj_b)
			% EQ - are two NSD_IODEVICE objects equal?
			%
			% B = EQ(NSD_IODEVICE_OBJ_A, NSD_IODEVICE_OBJ_B)
			%
			% Returns 1 if the NSD_IODEVICE objects have the same name and class type.
			% The objects do not have to be the same handle or have the same space in memory.
			% Otherwise, returns 0.
			%
				b = strcmp(nsd_iodevice_obj_a.name,nsd_iodevice_obj_b.name) & ...
					strcmp(class(nsd_iodevice_obj_a),class(nsd_iodevice_obj_b));
		end % eq()

		%% functions that override NSD_BASE/NSD_DBLEAF:

		function obj = readobjectfile(nsd_iodevice_obj, fname)
			% READOBJECTFILE
			%
			% NSD_IODEVICE_OBJ = READOBJECTFILE(NSD_DEVICE_OBJ, FNAME)
			%
			% Reads the NSD_IODEVICE_OBJ from the file FNAME (full path).

				obj=readobjectfile@nsd_dbleaf(nsd_iodevice_obj, fname);
				[dirname] = fileparts(fname); % same parent directory
				subdirname = [dirname filesep obj.objectfilename '.filetree.device.nsd'];
				f = dir([subdirname filesep 'object_*']);
				if isempty(f),
					error(['Could not find filetree file!']);
				end
				obj.filetree=nsd_filetree_readfromfile([subdirname filesep f(1).name]);
		end % readobjectfile

		function obj = writeobjectfile(nsd_iodevice_obj, dirname, islocked)
			% WRITEOBJECTFILE - write an nsd_iodevice to a directory
			%
			% NSD_IODEVICE_OBJ = WRITEOBJECTFILE(NSD_DEVICE_OBJ, dirname, [islocked])
			%
			% Writes the NSD_IODEVICE_OBJ to the directory DIRNAME (full path).
			% 
			% If ISLOCKED is present, it is passed along to the NSD_DBLEAF/WRITEOBJECT method.
			% Otherwise, it is assumed that the variable is not already locked (islocked=0).

				if nargin<3,
					islocked = 0;
				end

				obj=writeobjectfile@nsd_dbleaf(nsd_iodevice_obj, dirname, islocked);
				subdirname = [dirname filesep obj.objectfilename '.filetree.device.nsd'];
				if ~exist(subdirname,'dir'), mkdir(subdirname); end;
				obj.filetree.writeobjectfile(subdirname);
		end % writeobjectfile

		function [data, fieldnames] = stringdatatosave(nsd_iodevice_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NSD_IODEVICE_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% Note: NSD_IODEVICE objects do not save their NSD_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NSD_IODEVICE from disk to install the NSD_EXPERIMENT.
			%
				[data,fieldnames] = stringdatatosave@nsd_dbleaf(nsd_iodevice_obj);
		end % stringdatatosave

		function [obj,properties_set] = setproperties(nsd_iodevice_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_IODEVICE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_IODEVICE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_IODEVICE_OBJ and returns the result in OBJ.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(nsd_iodevice_obj);
				obj = nsd_iodevice_obj;
				properties_set = {};
				for i=1:numel(properties),
					if strcmp(properties{i},'$nsdclocktype'),
						%obj.clock = nsd_clock_iodevice(values{i},obj); % do nothing, this is gone
					elseif any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						end
					end
				end
		end % setproperties()

		function b = deleteobjectfile(nsd_iodevice_obj, thedirname)
			% DELETEOBJECTFILE - Delete / remove the object file (or files) for NSD_IODEVICE
			%
			% B = DELETEOBJECTFILE(NSD_IODEVICE_OBJ, THEDIRNAME)
			%
			% Delete all files associated with NSD_IODEVICE_OBJ in directory THEDIRNAME (full path).
			%
			% If no directory is given, NSD_IODEVICE_OBJ.PATH is used.
			%
			% B is 1 if the process succeeds, 0 otherwise.
			%
				b = 1;
				subdirname = [thedirname filesep nsd_iodevice_obj.objectfilename '.filetree.device.nsd'];
				rmdir(subdirname,'s');
				b = b&deleteobjectfile@nsd_dbleaf(nsd_iodevice_obj, thedirname);

		end % deletefileobject

		%%

		function ec = epochclock(nsd_iodevice_obj, epoch_number)
			% EPOCHCLOCK - return the NSD_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NSD_IODEVICE_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NSD_CLOCKTYPE objects (or sub-class members).
			%
			% For the generic NSD_IODEVICE, this returns a single clock
			% type 'no_time';
			%
			% See also: NSD_CLOCKTYPE
			%
				ec = {nsd_clocktype('no_time')};
		end % epochclock

		function eid = epochid(nsd_iodevice_obj, epoch_number)
			% EPOCHID - return the epoch id string for an epoch
			%
			% EID = EOPCHID(NSD_IODEVICE_OBJ, EPOCH_NUMBER)
			%
			% Returns the EPOCHID for epoch with number EPOCH_NUMBER.
			% In NSD_IODEVICE, this is determined by the associated
			% NSD_FILETREE object.
			%
				eid = nsd_iodevice_obj.filetree.epochid(epoch_number);
		end % epochid

		function probes_struct=getprobes(nsd_iodevice_obj)
			% GETPROBES = Return all of the probes associated with an NSD_IODEVICE object
			%
			% PROBES_STRUCT = GETPROBES(NSD_IODEVICE_OBJ)
			%
			% Returns all probes associated with the NSD_IODEVICE object NSD_DEVICE_OBJ
			%
			% This function returns a structure with fields of all unique probes across
			% all EPOCHCONTENTS objects returned in NSD_IODEVICE/GETEPOCHCONTENTS.
			% The fields are 'name', 'reference', and 'type'.

				et = epochtable(nsd_iodevice_obj);

				probes_struct = emptystruct('name','reference','type');
				
				for n=1:numel(et),
					epc = et(n).epochcontents;
					if ~isempty(epc),
						for ec = 1:numel(epc),
							newentry.name = epc(ec).name;
							newentry.reference= epc(ec).reference;
							newentry.type= epc(ec).type;
							probes_struct(end+1) = newentry;
						end
					end
				end
				probes_struct = equnique(probes_struct);
		end % getprobes()

		function exp=experiment(nsd_iodevice_obj)
			% EXPERIMENT - return the NSD_EXPERIMENT object associated with the NSD_IODEVICE object
			%
			% EXP = EXPERIMENT(NSD_IODEVICE_OBJ)
			%
			% Return the NSD_EXPERIMENT object associated with the NSD_IODEVICE of the
			% NSD_IODEVICE object.
			%
				exp = nsd_iodevice_obj.filetree.experiment;
		end % experiment()

		function nsd_iodevice_obj=setexperiment(nsd_iodevice_obj, experiment)
			% SETEXPERIMENT - set the EXPERIMENT for an NSD_IODEVICE object's filetree (type NSD_IODEVICE)
			%
			% NSD_IODEVICE_OBJ = SETEXPERIMENT(NSD_DEVICE_OBJ, PATH)
			%
			% Set the EXPERIMENT property of an NSD_IODEVICE object's NSD_IODEVICE object
			%	
				nsd_iodevice_obj.filetree = setproperties(nsd_iodevice_obj.filetree,{'experiment'},{experiment});
		end % setpath()

		%% functions that override NSD_EPOCHSET, NSD_EPOCHSET_PARAM

		function deleteepoch(nsd_iodevice_obj, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(NSD_IODEVICE_OBJ, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and NSD_EPOCHCONTENTS_IODEVICE and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS_IODEVICE
			error(['Not implemented yet.']);
		end % deleteepoch()

                function [cache,key] = getcache(nsd_iodevice_obj)
			% GETCACHE - return the NSD_CACHE and key for NSD_IODEVICE
			%
			% [CACHE,KEY] = GETCACHE(NSD_IODEVICE_OBJ)
			%
			% Returns the CACHE and KEY for the NSD_IODEVICE object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the object's objectfilename.
			%
			% See also: NSD_IODEVICE, NSD_BASE

				cache = [];
				key = [];
				if isa(nsd_iodevice_obj.experiment,'handle'),
					exp = nsd_iodevice_obj.experiment();
					cache = exp.cache;
					key = nsd_iodevice_obj.objectfilename;
				end
		end

		function et = buildepochtable(nsd_iodevice_obj)
			% BUILDEPOCHTABLE - Build the epochtable for an NSD_IODEVICE object
			%
			% ET = BUILDEPOCHTABLE(NSD_IODEVICE_OBJ)
			%
			% Returns the epoch table for NSD_IODEVICE_OBJ
			%
				et = nsd_iodevice_obj.filetree.epochtable;
				for i=1:numel(et),
					% developer note: you might ask, why is this here?
					%    this allows future iodevice subclasses to override getepochcontents without
					%    also needing to override epochtable
					et(i).epochcontents = getepochcontents(nsd_iodevice_obj,et(i).epoch_number);
					et(i).epoch_clock = epochclock(nsd_iodevice_obj, et(i).epoch_number);
				end
		end % epochtable

		function ecfname = epochcontentsfilename(nsd_iodevice_obj, epochnumber)
			% EPOCHCONTENTSFILENAME - return the filename for the NSD_EPOCHCONTENTS_IODEVICE file for an epoch
			%
			% ECFNAME = EPOCHCONTENTSFILENAME(NSD_IODEVICE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the EPOCHCONTENTSFILENAME for the NSD_IODEVICE epoch EPOCH_NUMBER_OR_ID.
			% If there is no epoch NUMBER, an error is generated. The file name is returned with
			% a full path.
			%
			%
				ecfname = nsd_iodevice_obj.filetree.epochcontentsfilename(epochnumber);
                end % epochcontentsfilename

		function [b,msg] = verifyepochcontents(nsd_iodevice_obj, epochcontents, number)
			% VERIFYEPOCHCONTENTS - Verifies that an EPOCHCONTENTS is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHCONTENTS(NSD_IODEVICE_OBJ, EPOCHCONTENTS, NUMBER)
			%
			% Examines the NSD_EPOCHCONTENTS_IODEVICE EPOCHCONTENTS and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class NSD_IODEVICE, EPOCHCONTENTS is always valid as long as
			% EPOCHCONTENTS is an NSD_EPOCHCONTENTS_IODEVICE object.
			%
			% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS_IODEVICE
				msg = '';
				b = isa(epochcontents, 'nsd_epochcontents_iodevice');
				if ~b,
					msg = 'epochcontents is not a member of the class NSD_EPOCHCONTENTS_IODEVICE; it must be.';
					return;
				end;

				for i=1:numel(epochcontents),
					try,
						thedevicestring = nsd_iodevicestring(epochcontents(i).devicestring);
					catch,
						b = 0;
						msg = ['Error evaluating devicestring ' epochcontents(i).devicestring '.'];
                                        end
                                end
		end % verifyepochcontents

		function etfname = epochtagfilename(nsd_epochset_param_obj, epochnumber)
			% EPOCHTAGFILENAME - return the file path for the tag file for an epoch
			%
			% ETFNAME = EPOCHTAGFILENAME(NSD_FILETREE_OBJ, EPOCHNUMBER)
			%
			% In this base class, empty is returned because it is an abstract class.
			%
				etfname = nsd_epochset_param.obj.filetree.epochtagfilename(epochnumber);
                end % epochtagfilename()

	end % methods
end % nsd_iodevice classdef

