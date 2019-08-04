classdef ndi_iodevice < ndi_dbleaf & ndi_epochset_param
% NDI_IODEVICE - Create a new NDI_DEVICE class handle object
%
%  D = NDI_IODEVICE(NAME, THEFILETREE)
%
%  Creates a new NDI_IODEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.

	properties (GetAccess=public, SetAccess=protected)
		filetree   % The NDI_FILETREE associated with this device
	end

	methods
		function obj = ndi_iodevice(name,thefiletree)
		% NDI_IODEVICE - create a new NDI_DEVICE object
		%
		%  OBJ = NDI_IODEVICE(NAME, THEFILETREE)
		%
		%  Creates an NDI_IODEVICE with name NAME and NDI_IODEVICE
		%  THEFILETREE. THEFILETREE is an interface object to the raw data files
		%  on disk that are read by the NDI_IODEVICE.
		%
		%  NDI_IODEVICE is an abstract class, and a specific implementation must be called.
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

			obj = obj@ndi_dbleaf(name);
			if loadfromfile,
				obj = obj.readobjectfile(filename);
			else,
				obj.name = name;
				obj.filetree = thefiletree;
			end
			if isempty(obj.filetree),
				obj.epochcontents_class = 'ndi_epochcontents_iodevice';
			else,
				obj.epochcontents_class = obj.filetree.epochcontents_class;
			end;
		end % ndi_iodevice

		%% GUI functions

		function obj = ndi_iodevice_gui_createnew(ndi_iodevice_obj)
			% NDI_IODEVICE_GUI_CREATENEW - function for creating a new NDI_IODEVICE object based on a template
			% 
			% OBJ = NDI_IODEVICE_GUI_CREATENEW(NDI_IODEVICE_OBJ)
			%
			% This function will bring up a graphical window to prompt the user to input
			% parameters needed to define a new NDI_IODEVICE object.
			%
			%
				error(['Not implemented yet.']);
				% insert code here
		end;

		function obj = ndi_iodevice_gui_edit(ndi_iodevice_obj)
			% NDI_IODEVICE_GUI_EDIT - function for editing an NDI_IODEVICE object
			% 
			% OBJ = NDI_IODEVICE_GUI_EDIT(NDI_IODEVICE_OBJ)
			%
			% This function will bring up a graphical window to prompt the user to input
			% parameters that edit the NDI_IODEVICE_OBJ and return a new object.
			%
			%
				error(['Not implemented yet.']);
				% insert code here
		end;

		%% functions that used to override HANDLE, now just implement equal:

		function b = eq(ndi_iodevice_obj_a, ndi_iodevice_obj_b)
			% EQ - are two NDI_IODEVICE objects equal?
			%
			% B = EQ(NDI_IODEVICE_OBJ_A, NDI_IODEVICE_OBJ_B)
			%
			% Returns 1 if the NDI_IODEVICE objects have the same name and class type.
			% The objects do not have to be the same handle or have the same space in memory.
			% Otherwise, returns 0.
			%
				b = strcmp(ndi_iodevice_obj_a.name,ndi_iodevice_obj_b.name) & ...
					strcmp(class(ndi_iodevice_obj_a),class(ndi_iodevice_obj_b));
		end % eq()

		%% functions that override NDI_BASE/NDI_DBLEAF:

		function obj = readobjectfile(ndi_iodevice_obj, fname)
			% READOBJECTFILE
			%
			% NDI_IODEVICE_OBJ = READOBJECTFILE(NDI_DEVICE_OBJ, FNAME)
			%
			% Reads the NDI_IODEVICE_OBJ from the file FNAME (full path).

				obj=readobjectfile@ndi_dbleaf(ndi_iodevice_obj, fname);
				[dirname] = fileparts(fname); % same parent directory
				subdirname = [dirname filesep obj.objectfilename '.filetree.device.ndi'];
				f = dir([subdirname filesep 'object_*']);
				if isempty(f),
					error(['Could not find filetree file!']);
				end
				obj.filetree=ndi_filetree_readfromfile([subdirname filesep f(1).name]);
		end % readobjectfile

		function obj = writeobjectfile(ndi_iodevice_obj, dirname, islocked)
			% WRITEOBJECTFILE - write an ndi_iodevice to a directory
			%
			% NDI_IODEVICE_OBJ = WRITEOBJECTFILE(NDI_DEVICE_OBJ, dirname, [islocked])
			%
			% Writes the NDI_IODEVICE_OBJ to the directory DIRNAME (full path).
			% 
			% If ISLOCKED is present, it is passed along to the NDI_DBLEAF/WRITEOBJECT method.
			% Otherwise, it is assumed that the variable is not already locked (islocked=0).

				if nargin<3,
					islocked = 0;
				end

				obj=writeobjectfile@ndi_dbleaf(ndi_iodevice_obj, dirname, islocked);
				subdirname = [dirname filesep obj.objectfilename '.filetree.device.ndi'];
				if ~exist(subdirname,'dir'), mkdir(subdirname); end;
				obj.filetree.writeobjectfile(subdirname);
		end % writeobjectfile

		function [data, fieldnames] = stringdatatosave(ndi_iodevice_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NDI_IODEVICE_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% Note: NDI_IODEVICE objects do not save their NDI_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NDI_IODEVICE from disk to install the NDI_EXPERIMENT.
			%
				[data,fieldnames] = stringdatatosave@ndi_dbleaf(ndi_iodevice_obj);
		end % stringdatatosave

		function [obj,properties_set] = setproperties(ndi_iodevice_obj, properties, values)
			% SETPROPERTIES - set the properties of an NDI_IODEVICE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NDI_IODEVICE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NDI_IODEVICE_OBJ and returns the result in OBJ.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(ndi_iodevice_obj);
				obj = ndi_iodevice_obj;
				properties_set = {};
				for i=1:numel(properties),
					if strcmp(properties{i},'$ndiclocktype'),
						%obj.clock = ndi_clock_iodevice(values{i},obj); % do nothing, this is gone
					elseif any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						end
					end
				end
		end % setproperties()

		function b = deleteobjectfile(ndi_iodevice_obj, thedirname)
			% DELETEOBJECTFILE - Delete / remove the object file (or files) for NDI_IODEVICE
			%
			% B = DELETEOBJECTFILE(NDI_IODEVICE_OBJ, THEDIRNAME)
			%
			% Delete all files associated with NDI_IODEVICE_OBJ in directory THEDIRNAME (full path).
			%
			% If no directory is given, NDI_IODEVICE_OBJ.PATH is used.
			%
			% B is 1 if the process succeeds, 0 otherwise.
			%
				b = 1;
				subdirname = [thedirname filesep ndi_iodevice_obj.objectfilename '.filetree.device.ndi'];
				rmdir(subdirname,'s');
				b = b&deleteobjectfile@ndi_dbleaf(ndi_iodevice_obj, thedirname);

		end % deletefileobject

		%%

		function ec = epochclock(ndi_iodevice_obj, epoch_number)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_IODEVICE_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NDI_CLOCKTYPE objects (or sub-class members).
			%
			% For the generic NDI_IODEVICE, this returns a single clock
			% type 'no_time';
			%
			% See also: NDI_CLOCKTYPE
			%
				ec = {ndi_clocktype('no_time')};
		end % epochclock

		function t0t1 = t0_t1(ndi_epochset_obj, epoch_number)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
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
				t0t1 = {[NaN NaN]};
		end % t0t1

		function eid = epochid(ndi_iodevice_obj, epoch_number)
			% EPOCHID - return the epoch id string for an epoch
			%
			% EID = EOPCHID(NDI_IODEVICE_OBJ, EPOCH_NUMBER)
			%
			% Returns the EPOCHID for epoch with number EPOCH_NUMBER.
			% In NDI_IODEVICE, this is determined by the associated
			% NDI_FILETREE object.
			%
				eid = ndi_iodevice_obj.filetree.epochid(epoch_number);
		end % epochid

		function probes_struct=getprobes(ndi_iodevice_obj)
			% GETPROBES = Return all of the probes associated with an NDI_IODEVICE object
			%
			% PROBES_STRUCT = GETPROBES(NDI_IODEVICE_OBJ)
			%
			% Returns all probes associated with the NDI_IODEVICE object NDI_DEVICE_OBJ
			%
			% This function returns a structure with fields of all unique probes across
			% all EPOCHCONTENTS objects returned in NDI_IODEVICE/GETEPOCHCONTENTS.
			% The fields are 'name', 'reference', and 'type'.

				et = epochtable(ndi_iodevice_obj);

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

		function exp=experiment(ndi_iodevice_obj)
			% EXPERIMENT - return the NDI_EXPERIMENT object associated with the NDI_IODEVICE object
			%
			% EXP = EXPERIMENT(NDI_IODEVICE_OBJ)
			%
			% Return the NDI_EXPERIMENT object associated with the NDI_IODEVICE of the
			% NDI_IODEVICE object.
			%
				exp = ndi_iodevice_obj.filetree.experiment;
		end % experiment()

		function ndi_iodevice_obj=setexperiment(ndi_iodevice_obj, experiment)
			% SETEXPERIMENT - set the EXPERIMENT for an NDI_IODEVICE object's filetree (type NDI_IODEVICE)
			%
			% NDI_IODEVICE_OBJ = SETEXPERIMENT(NDI_DEVICE_OBJ, PATH)
			%
			% Set the EXPERIMENT property of an NDI_IODEVICE object's NDI_IODEVICE object
			%	
				ndi_iodevice_obj.filetree = setproperties(ndi_iodevice_obj.filetree,{'experiment'},{experiment});
		end % setpath()

		%% functions that override NDI_EPOCHSET, NDI_EPOCHSET_PARAM

		function deleteepoch(ndi_iodevice_obj, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(NDI_IODEVICE_OBJ, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and NDI_EPOCHCONTENTS_IODEVICE and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: NDI_IODEVICE, NDI_EPOCHCONTENTS_IODEVICE
			error(['Not implemented yet.']);
		end % deleteepoch()

                function [cache,key] = getcache(ndi_iodevice_obj)
			% GETCACHE - return the NDI_CACHE and key for NDI_IODEVICE
			%
			% [CACHE,KEY] = GETCACHE(NDI_IODEVICE_OBJ)
			%
			% Returns the CACHE and KEY for the NDI_IODEVICE object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the object's objectfilename.
			%
			% See also: NDI_IODEVICE, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_iodevice_obj.experiment,'handle'),
					exp = ndi_iodevice_obj.experiment();
					cache = exp.cache;
					key = ndi_iodevice_obj.objectfilename;
				end
		end

		function et = buildepochtable(ndi_iodevice_obj)
			% BUILDEPOCHTABLE - Build the epochtable for an NDI_IODEVICE object
			%
			% ET = BUILDEPOCHTABLE(NDI_IODEVICE_OBJ)
			%
			% Returns the epoch table for NDI_IODEVICE_OBJ
			%
				et = ndi_iodevice_obj.filetree.epochtable;
				for i=1:numel(et),
					% need slight adjustment from filetree epochtable
					et(i).epochcontents = getepochcontents(ndi_iodevice_obj,et(i).epoch_number);
					et(i).epoch_clock = epochclock(ndi_iodevice_obj, et(i).epoch_number);
					et(i).t0_t1 = t0_t1(ndi_iodevice_obj, et(i).epoch_number);
				end
		end % epochtable

		function ecfname = epochcontentsfilename(ndi_iodevice_obj, epochnumber)
			% EPOCHCONTENTSFILENAME - return the filename for the NDI_EPOCHCONTENTS_IODEVICE file for an epoch
			%
			% ECFNAME = EPOCHCONTENTSFILENAME(NDI_IODEVICE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the EPOCHCONTENTSFILENAME for the NDI_IODEVICE epoch EPOCH_NUMBER_OR_ID.
			% If there is no epoch NUMBER, an error is generated. The file name is returned with
			% a full path.
			%
			%
				ecfname = ndi_iodevice_obj.filetree.epochcontentsfilename(epochnumber);
                end % epochcontentsfilename

		function [b,msg] = verifyepochcontents(ndi_iodevice_obj, epochcontents, number)
			% VERIFYEPOCHCONTENTS - Verifies that an EPOCHCONTENTS is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHCONTENTS(NDI_IODEVICE_OBJ, EPOCHCONTENTS, NUMBER)
			%
			% Examines the NDI_EPOCHCONTENTS_IODEVICE EPOCHCONTENTS and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class NDI_IODEVICE, EPOCHCONTENTS is always valid as long as
			% EPOCHCONTENTS is an NDI_EPOCHCONTENTS_IODEVICE object.
			%
			% See also: NDI_IODEVICE, NDI_EPOCHCONTENTS_IODEVICE
				msg = '';
				b = isa(epochcontents, 'ndi_epochcontents_iodevice');
				if ~b,
					msg = 'epochcontents is not a member of the class NDI_EPOCHCONTENTS_IODEVICE; it must be.';
					return;
				end;

				for i=1:numel(epochcontents),
					try,
						thedevicestring = ndi_iodevicestring(epochcontents(i).devicestring);
					catch,
						b = 0;
						msg = ['Error evaluating devicestring ' epochcontents(i).devicestring '.'];
                                        end
                                end
		end % verifyepochcontents

		function etfname = epochtagfilename(ndi_epochset_param_obj, epochnumber)
			% EPOCHTAGFILENAME - return the file path for the tag file for an epoch
			%
			% ETFNAME = EPOCHTAGFILENAME(NDI_FILETREE_OBJ, EPOCHNUMBER)
			%
			% In this base class, empty is returned because it is an abstract class.
			%
				etfname = ndi_epochset_param.obj.filetree.epochtagfilename(epochnumber);
                end % epochtagfilename()

	end % methods
end % ndi_iodevice classdef

