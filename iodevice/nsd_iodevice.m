classdef nsd_iodevice < nsd_dbleaf
% NSD_IODEVICE - Create a new NSD_DEVICE class handle object
%
%  D = NSD_IODEVICE(NAME, THEFILETREE)
%
%  Creates a new NSD_IODEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.

	properties (GetAccess=public, SetAccess=protected)
		filetree   % The NSD_IODEVICE associated with this device
		clock      % The NSD_CLOCK object associated with this device
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
			obj.clock = nsd_clock('no_time');
		end % nsd_iodevice

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

		function deleteepoch(self, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(NSD_IODEVICE_OBJ, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and NSD_EPOCHCONTENTS and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS
			error(['Not implemented yet.']);
		end % deleteepoch()

		function setepochcontents(self, epochcontents, number, overwrite)
			% SETEPOCHCONTENTS - Sets the epoch record of a particular epoch
			%
			%   SETEPOCHCONTENTS(NSD_IODEVICE_OBJ, EPOCHCONTENTS, NUMBER, [OVERWRITE])
			%
			% Sets or replaces the NSD_EPOCHCONTENTS object for NSD_IODEVICE_OBJ with EPOCHCONTENTS for the epoch
			% numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
			% Otherwise, an error is given if there is an existing epoch record.
			%
			% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS
				
				if nargin<4,
					overwrite = 0;
				end

				% check for well-formed nsd_iodevicestrings

				for i=1:numel(epochcontents),
					try,
						thedevicestring = nsd_iodevicestring(epochcontents(i).devicestring);
					catch,
						error(['Error evaluating devicestring ' epochcontents(i).devicestring '.']);
					end
				end

				self.filetree.setepochcontents(epochcontents, number, overwrite);
		end % setepochcontents()

                function epochcontents = getepochcontents(self, number)
			% GETEPOCHCONTENTS - retreive the epoch record associated with a recording epoch
			%
			%   EPOCHCONTENTS = GETEPOCHCONTENTS(NSD_IODEVICE_OBJ, NUMBER)
			%
			% Returns the EPOCHCONTENTS associated the the data epoch NUMBER for the
			% NSD_IODEVICE.
			%
			% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS
			%
				   % Developer note: Why is this function present in nsd_iodevice, when it pretty much 
				   % just calls the nsd_filetree version? Because, some devices may include some sort of epoch
				   % record in their own files natively, and the nsd_iodevice_DRIVER that reads it may simply read from that
				   % information. So nsd_iodevice_DRIVER needs the ability to override this function.

				epochcontents = self.filetree.getepochcontents(number, self.name);
				if ~(verifyepochcontents(self,epochcontents))
					error(['the numbered epoch is not a valid epoch for the given device']);
				end
                end %getepochcontents()

		function b = verifyepochcontents(self, epochcontents, number)
			% VERIFYEPOCHCONTENTS - Verifies that an EPOCHCONTENTS is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHCONTENTS(NSD_IODEVICE_OBJ, EPOCHCONTENTS, NUMBER)
			%
			% Examines the NSD_EPOCHCONTENTS EPOCHCONTENTS and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class NSD_IODEVICE, EPOCHCONTENTS is always valid as long as
			% EPOCHCONTENTS is an NSD_EPOCHCONTENTS object.
			%
			% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS
				b = isa(epochcontents, 'nsd_epochcontents');
		end % verifyepochcontents

		function probes_struct=getprobes(self)
			% GETPROBES = Return all of the probes associated with an NSD_IODEVICE object
			%
			% PROBES_STRUCT = GETPROBES(NSD_IODEVICE_OBJ)
			%
			% Returns all probes associated with the NSD_IODEVICE object NSD_DEVICE_OBJ
			%
			% This function returns a structure with fields of all unique probes across
			% all EPOCHCONTENTS objects returned in NSD_IODEVICE/GETEPOCHCONTENTS.
			% The fields are 'name', 'reference', and 'type'.
				probes_struct = emptystruct('name','reference','type');
				N = self.filetree.numepochs();
				for n=1:N,
					epc = self.getepochcontents(n);
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

		function self=setexperiment(self, experiment)
			% SETEXPERIMENT - set the EXPERIMENT for an NSD_IODEVICE object's filetree (type NSD_IODEVICE)
			%
			% NSD_IODEVICE_OBJ = SETEXPERIMENT(NSD_DEVICE_OBJ, PATH)
			%
			% Set the EXPERIMENT property of an NSD_IODEVICE object's NSD_IODEVICE object
			%	
				self.filetree = setproperties(self.filetree,{'experiment'},{experiment});
		end % setpath()

		function tag = getepochtag(self, number)
			% GETEPOCHTAG - Get tag(s) from an epoch
			%
			% TAG = GETEPOCHTAG(NSD_IODEVICE_OBJ, EPOCHNUMBER)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				tag = self.filetree.getepochtag(number);
		end % getepochtag()

		function setepochtag(self, number, tag)
			% SETEPOCHTAG - Set tag(s) for an epoch
			%
			% SETEPOCHTAG(NSD_IODEVICE_OBJ, EPOCHNUMBER, TAG)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. These tags will replace any
			% tags in the epoch directory. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				self.filetree.setepochtag(number,tag);
		end % setepochtag()

		function addepochtag(self, number, tag)
			% ADDEPOCHTAG - Add tag(s) for an epoch
			%
			% ADDEPOCHTAG(NSD_IODEVICE_OBJ, EPOCHNUMBER, TAG)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. These tags will be added to any
			% tags in the epoch EPOCHNUMBER. If tags with the same names as those in TAG
			% already exist, they will be overwritten. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				self.filetree.addepochtag(number, tag);
		end % addepochtag()

		function removeepochtag(self, number, name)
			% REMOVEEPOCHTAG - Remove tag(s) for an epoch
			%
			% REMOVEEPOCHTAG(NSD_IODEVICE_OBJ, EPOCHNUMBER, NAME)
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
				self.filetree.removeepochtag(number,name);
		end % removeepochtag()

		function exp=experiment(self)
			% EXPERIMENT - return the NSD_EXPERIMENT object associated with the NSD_IODEVICE object
			%
			% EXP = EXPERIMENT(NSD_IODEVICE_OBJ)
			%
			% Return the NSD_EXPERIMENT object associated with the NSD_IODEVICE of the
			% NSD_IODEVICE object.
			%
				exp = self.filetree.experiment;
		end % experiment()

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
			% For NSD_IODEVICE, this returns the type of clock (NSD_IODEVICE_OBJ.CLOCK.TYPE).
			%
			% Note: NSD_IODEVICE objects do not save their NSD_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NSD_IODEVICE from disk to install the NSD_EXPERIMENT.
			%
				[data,fieldnames] = stringdatatosave@nsd_dbleaf(nsd_iodevice_obj);
				if isa(nsd_iodevice_obj.clock,'nsd_clock_iodevice'),
					data{end+1} = nsd_iodevice_obj.clock.type;
				else,
					data{end+1} = ''; % we are about to read it from disk
				end
				fieldnames{end+1} = '$nsdclocktype';
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
						obj.clock = nsd_clock_iodevice(values{i},obj);
					elseif any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						end
					end
				end
		end % setproperties()

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
			
	end % methods
end
