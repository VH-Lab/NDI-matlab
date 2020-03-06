classdef ndi_daqsystem < ndi_dbleaf & ndi_epochset_param
% NDI_DAQSYSTEM - Create a new NDI_DEVICE class handle object
%
%  D = NDI_DAQSYSTEM(NAME, THEFILENAVIGATOR)
%
%  Creates a new NDI_DAQSYSTEM object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.

	properties (GetAccess=public, SetAccess=protected)
		filenavigator   % The NDI_FILENAVIGATOR associated with this device
		daqreader       % The NDI_DAQREADER associated with this device
	end

	methods
		function obj = ndi_daqsystem(name,thefilenavigator,thedaqreader)
		% NDI_DAQSYSTEM - create a new NDI_DEVICE object
		%
		%  OBJ = NDI_DAQSYSTEM(NAME, THEFILENAVIGATOR, THEDAQREADER)
		%
		%  Creates an NDI_DAQSYSTEM with name NAME, NDI_FILENAVIGTOR THEFILENAVIGATOR and
		%  and NDI_DAQREADER THEDAQREADER.
		%
		%  An NDI_FILENAVIGATOR is an interface object to the raw data files
		%  on disk that are read by the NDI_DAQREADER.
		%
		%  NDI_DAQSYSTEM is an abstract class, and a specific implementation must be called.
		%
            loadfromfile = 0;
             if nargin==2 & isa(name,'ndi_experiment') & isa(thefilenavigator,'ndi_document')
                experiment = name
                daqsystem_doc = thefilenavigator
                
                daqreader_id = dasystem_doc.document_properties.daqsystem.daqreader
                filenavigator_id = dasystem_doc.document_properties.daqsystem.daqreader
                docs = experiment.database_search(ndi_query('ndi_document.id','exactstring',daqreader_id,''))
                daqreader_doc = docs{1}
                docs = experiment.database_search(ndi_query('ndi_document.id','exactstring',filenavigator_id,''))
                filenavigator_doc = docs{1}
                
                thedaqreader = ndi_daqreader(daqreader_doc)
                thefilenavigator = ndi_filenavigator(experiment,filenavigator_doc)
                
                obj.name = thedaqreader;
                    obj.filenavigator = thefilenavigator;
                    obj.daqreader = thedaqreader;
			
            else
                if nargin==0, % undocumented 0 argument creator
                    name = '';
                    thefilenavigator = [];
                    thedaqreader = [];
                end;
                if nargin>=2,
                    if ischar(thefilenavigator), % it is a command
                        loadfromfile = 1;
                        filename = name;
                        name='';
                        if ~strcmp(lower(thefilenavigator), lower('OpenFile')),
                            error(['Unknown command.']);
                        else,
                            thefilenavigator=[];
                        end
                    end;
                end;

                if nargin>=3,
                    if ~isa(thedaqreader,'ndi_daqreader'),
                        error(['thedaqreader must be of type NDI_DAQREADER.']);
                    end;
                end;

                if (nargin==1) | (nargin>3),
                    error(['Function requires 2 or 3 input arguments exactly.']);
                end

                obj = obj@ndi_dbleaf(name);
                if loadfromfile,
                    obj = obj.readobjectfile(filename);
                else,
                    obj.name = name;
                    obj.filenavigator = thefilenavigator;
                    obj.daqreader = thedaqreader;
                end
            end
		end % ndi_daqsystem

		%% GUI functions

		function obj = ndi_daqsystem_gui_createnew(ndi_daqsystem_obj)
			% NDI_DAQSYSTEM_GUI_CREATENEW - function for creating a new NDI_DAQSYSTEM object based on a template
			% 
			% OBJ = NDI_DAQSYSTEM_GUI_CREATENEW(NDI_DAQSYSTEM_OBJ)
			%
			% This function will bring up a graphical window to prompt the user to input
			% parameters needed to define a new NDI_DAQSYSTEM object.
			%
			%
				error(['Not implemented yet.']);
				% insert code here
		end;

		function obj = ndi_daqsystem_gui_edit(ndi_daqsystem_obj)
			% NDI_DAQSYSTEM_GUI_EDIT - function for editing an NDI_DAQSYSTEM object
			% 
			% OBJ = NDI_DAQSYSTEM_GUI_EDIT(NDI_DAQSYSTEM_OBJ)
			%
			% This function will bring up a graphical window to prompt the user to input
			% parameters that edit the NDI_DAQSYSTEM_OBJ and return a new object.
			%
			%
				error(['Not implemented yet.']);
				% insert code here
		end;

		%% functions that used to override HANDLE, now just implement equal:

		function b = eq(ndi_daqsystem_obj_a, ndi_daqsystem_obj_b)
			% EQ - are two NDI_DAQSYSTEM objects equal?
			%
			% B = EQ(NDI_DAQSYSTEM_OBJ_A, NDI_DAQSYSTEM_OBJ_B)
			%
			% Returns 1 if the NDI_DAQSYSTEM objects have the same name and class type.
			% The objects do not have to be the same handle or have the same space in memory.
			% Otherwise, returns 0.
			%
				b = strcmp(ndi_daqsystem_obj_a.name,ndi_daqsystem_obj_b.name) & ...
					strcmp(class(ndi_daqsystem_obj_a),class(ndi_daqsystem_obj_b));
		end % eq()

		%% functions that override NDI_BASE/NDI_DBLEAF:

		function obj = readobjectfile(ndi_daqsystem_obj, fname)
			% READOBJECTFILE
			%
			% NDI_DAQSYSTEM_OBJ = READOBJECTFILE(NDI_DEVICE_OBJ, FNAME)
			%
			% Reads the NDI_DAQSYSTEM_OBJ from the file FNAME (full path).

				obj=readobjectfile@ndi_dbleaf(ndi_daqsystem_obj, fname);
				[dirname] = fileparts(fname); % same parent directory
				subdirname = [dirname filesep obj.objectfilename '.filenavigator.device.ndi'];
				f = dir([subdirname filesep 'object_*']);
				if isempty(f),
					error(['Could not find filenavigator file!']);
				end
				obj.filenavigator=ndi_filenavigator_readfromfile([subdirname filesep f(1).name]);
				subdirname = [dirname filesep obj.objectfilename '.daqreader.device.ndi'];
				f = dir([subdirname filesep 'object_*']);
				if isempty(f),
					error(['Could not find daqreader file!']);
				end
				obj.daqreader =ndi_daqreader_readfromfile([subdirname filesep f(1).name]);
		end % readobjectfile

		function obj = writeobjectfile(ndi_daqsystem_obj, dirname, islocked)
			% WRITEOBJECTFILE - write an ndi_daqsystem to a directory
			%
			% NDI_DAQSYSTEM_OBJ = WRITEOBJECTFILE(NDI_DEVICE_OBJ, dirname, [islocked])
			%
			% Writes the NDI_DAQSYSTEM_OBJ to the directory DIRNAME (full path).
			% 
			% If ISLOCKED is present, it is passed along to the NDI_DBLEAF/WRITEOBJECT method.
			% Otherwise, it is assumed that the variable is not already locked (islocked=0).

				if nargin<3,
					islocked = 0;
				end

				obj=writeobjectfile@ndi_dbleaf(ndi_daqsystem_obj, dirname, islocked);
				subdirname = [dirname filesep obj.objectfilename '.filenavigator.device.ndi'];
				if ~exist(subdirname,'dir'), mkdir(subdirname); end;
				obj.filenavigator.writeobjectfile(subdirname);
				subdirname = [dirname filesep obj.objectfilename '.daqreader.device.ndi'];
				if ~exist(subdirname,'dir'), mkdir(subdirname); end;
				obj.daqreader.writeobjectfile(subdirname);
		end % writeobjectfile

		function [data, fieldnames] = stringdatatosave(ndi_daqsystem_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NDI_DAQSYSTEM_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% Note: NDI_DAQSYSTEM objects do not save their NDI_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NDI_DAQSYSTEM from disk to install the NDI_EXPERIMENT.
			%
				[data,fieldnames] = stringdatatosave@ndi_dbleaf(ndi_daqsystem_obj);
		end % stringdatatosave

		function [obj,properties_set] = setproperties(ndi_daqsystem_obj, properties, values)
			% SETPROPERTIES - set the properties of an NDI_DAQSYSTEM object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NDI_DAQSYSTEM_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NDI_DAQSYSTEM_OBJ and returns the result in OBJ.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(ndi_daqsystem_obj);
				obj = ndi_daqsystem_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						end
					end
				end
		end % setproperties()

		function b = deleteobjectfile(ndi_daqsystem_obj, thedirname)
			% DELETEOBJECTFILE - Delete / remove the object file (or files) for NDI_DAQSYSTEM
			%
			% B = DELETEOBJECTFILE(NDI_DAQSYSTEM_OBJ, THEDIRNAME)
			%
			% Delete all files associated with NDI_DAQSYSTEM_OBJ in directory THEDIRNAME (full path).
			%
			% If no directory is given, NDI_DAQSYSTEM_OBJ.PATH is used.
			%
			% B is 1 if the process succeeds, 0 otherwise.
			%
				b = 1;
				subdirname = [thedirname filesep ndi_daqsystem_obj.objectfilename '.filenavigator.device.ndi'];
				rmdir(subdirname,'s');
				b = b&deleteobjectfile@ndi_dbleaf(ndi_daqsystem_obj, thedirname);

		end % deletefileobject

		%%

		function ec = epochclock(ndi_daqsystem_obj, epoch_number)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NDI_CLOCKTYPE objects (or sub-class members).
			%
			% For the generic NDI_DAQSYSTEM, this returns a single clock
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

		function eid = epochid(ndi_daqsystem_obj, epoch_number)
			% EPOCHID - return the epoch id string for an epoch
			%
			% EID = EOPCHID(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
			%
			% Returns the EPOCHID for epoch with number EPOCH_NUMBER.
			% In NDI_DAQSYSTEM, this is determined by the associated
			% NDI_FILENAVIGATOR object.
			%
				eid = ndi_daqsystem_obj.filenavigator.epochid(epoch_number);
		end % epochid

		function probes_struct=getprobes(ndi_daqsystem_obj)
			% GETPROBES = Return all of the probes associated with an NDI_DAQSYSTEM object
			%
			% PROBES_STRUCT = GETPROBES(NDI_DAQSYSTEM_OBJ)
			%
			% Returns all probes associated with the NDI_DAQSYSTEM object NDI_DEVICE_OBJ
			%
			% This function returns a structure with fields of all unique probes across
			% all EPOCHPROBEMAP objects returned in NDI_DAQSYSTEM/GETEPOCHPROBEMAP.
			% The fields are 'name', 'reference', and 'type'.

				et = epochtable(ndi_daqsystem_obj);

				probes_struct = emptystruct('name','reference','type');
				
				for n=1:numel(et),
					epc = et(n).epochprobemap;
					if ~isempty(epc),
						for ec = 1:numel(epc),
							% is it mine?
							myprobemap = ndi_daqsystemstring(epc(ec).devicestring);
							if strcmpi(myprobemap.devicename, ndi_daqsystem_obj.name),
								newentry.name = epc(ec).name;
								newentry.reference= epc(ec).reference;
								newentry.type= epc(ec).type;
								probes_struct(end+1) = newentry;
							end
						end
					end
				end
				probes_struct = equnique(probes_struct);
		end % getprobes()

		function exp=experiment(ndi_daqsystem_obj)
			% EXPERIMENT - return the NDI_EXPERIMENT object associated with the NDI_DAQSYSTEM object
			%
			% EXP = EXPERIMENT(NDI_DAQSYSTEM_OBJ)
			%
			% Return the NDI_EXPERIMENT object associated with the NDI_DAQSYSTEM of the
			% NDI_DAQSYSTEM object.
			%
				exp = ndi_daqsystem_obj.filenavigator.experiment;
		end % experiment()

		function ndi_daqsystem_obj=setexperiment(ndi_daqsystem_obj, experiment)
			% SETEXPERIMENT - set the EXPERIMENT for an NDI_DAQSYSTEM object's filenavigator (type NDI_DAQSYSTEM)
			%
			% NDI_DAQSYSTEM_OBJ = SETEXPERIMENT(NDI_DEVICE_OBJ, PATH)
			%
			% Set the EXPERIMENT property of an NDI_DAQSYSTEM object's NDI_DAQSYSTEM object
			%	
				ndi_daqsystem_obj.filenavigator = setproperties(ndi_daqsystem_obj.filenavigator,{'experiment'},{experiment});
		end % setpath()

		%% functions that override NDI_EPOCHSET, NDI_EPOCHSET_PARAM

		function deleteepoch(ndi_daqsystem_obj, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(NDI_DAQSYSTEM_OBJ, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and NDI_EPOCHPROBEMAP_DAQSYSTEM and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: NDI_DAQSYSTEM, NDI_EPOCHPROBEMAP_DAQSYSTEM
			error(['Not implemented yet.']);
		end % deleteepoch()

                function [cache,key] = getcache(ndi_daqsystem_obj)
			% GETCACHE - return the NDI_CACHE and key for NDI_DAQSYSTEM
			%
			% [CACHE,KEY] = GETCACHE(NDI_DAQSYSTEM_OBJ)
			%
			% Returns the CACHE and KEY for the NDI_DAQSYSTEM object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the object's objectfilename.
			%
			% See also: NDI_DAQSYSTEM, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_daqsystem_obj.experiment,'handle'),
					exp = ndi_daqsystem_obj.experiment();
					cache = exp.cache;
					key = ndi_daqsystem_obj.objectfilename;
				end
		end

		function et = buildepochtable(ndi_daqsystem_obj)
			% BUILDEPOCHTABLE - Build the epochtable for an NDI_DAQSYSTEM object
			%
			% ET = BUILDEPOCHTABLE(NDI_DAQSYSTEM_OBJ)
			%
			% Returns the epoch table for NDI_DAQSYSTEM_OBJ
			%
				et = ndi_daqsystem_obj.filenavigator.epochtable;
				for i=1:numel(et),
					% need slight adjustment from filenavigator epochtable
					et(i).epochprobemap = getepochprobemap(ndi_daqsystem_obj,et(i).epoch_number);
					et(i).epoch_clock = epochclock(ndi_daqsystem_obj, et(i).epoch_number);
					et(i).t0_t1 = t0_t1(ndi_daqsystem_obj, et(i).epoch_number);
				end
		end % epochtable

		function ecfname = epochprobemapfilename(ndi_daqsystem_obj, epochnumber)
			% EPOCHPROBEMAPFILENAME - return the filename for the NDI_EPOCHPROBEMAP_DAQSYSTEM file for an epoch
			%
			% ECFNAME = EPOCHPROBEMAPFILENAME(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the EPOCHPROBEMAPFILENAME for the NDI_DAQSYSTEM epoch EPOCH_NUMBER_OR_ID.
			% If there is no epoch NUMBER, an error is generated. The file name is returned with
			% a full path.
			%
			%
				ecfname = ndi_daqsystem_obj.filenavigator.epochprobemapfilename(epochnumber);
                end % epochprobemapfilename

		function [b,msg] = verifyepochprobemap(ndi_daqsystem_obj, epochprobemap, epoch)
			% VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHPROBEMAP(NDI_DAQSYSTEM_OBJ, EPOCHPROBEMAP, EPOCH)
			%
			% Examines the NDI_EPOCHPROBEMAP_DAQSYSTEM EPOCHPROBEMAP and determines if it is valid for the given device
			% epoch EPOCH.
			%
			% For the abstract class NDI_DAQSYSTEM, EPOCHPROBEMAP is always valid as long as
			% EPOCHPROBEMAP is an NDI_EPOCHPROBEMAP_DAQSYSTEM object.
			%
			% See also: NDI_DAQSYSTEM, NDI_EPOCHPROBEMAP_DAQSYSTEM
				epochfiles = ndi_daqsystem_obj.filenavigator.getepochfiles(epoch);
				[b,msg] = ndi_daqsystem_obj.daqreader.verifyepochprobemap(epochprobemap,epochfiles);
		end % verifyepochprobemap

		function etfname = epochtagfilename(ndi_epochset_param_obj, epochnumber)
			% EPOCHTAGFILENAME - return the file path for the tag file for an epoch
			%
			% ETFNAME = EPOCHTAGFILENAME(NDI_FILENAVIGATOR_OBJ, EPOCHNUMBER)
			%
			% In this base class, empty is returned because it is an abstract class.
			%
				etfname = ndi_epochset_param.obj.filenavigator.epochtagfilename(epochnumber);
                end % epochtagfilename()

		function epochprobemap = getepochprobemap(ndi_daqsystem_obj, epoch)
			% GETEPOCHPROBEMAP - Return the epoch record for an NDI_DAQSYSTEM object
			%
			% EPOCHPROBEMAP = GETEPOCHPROBEMAP(NDI_DAQSYSTEM_OBJ, EPOCH)
			%
			% Inputs:
			%     NDI_EPOCHSET_PARAM_OBJ - the NDI_EPOCHSET_PARAM object
			%     EPOCH - the epoch number or identifier
			%
			% Output:
			%     EPOCHPROBEMAP - The epoch record information associated with epoch N for device with name DEVICENAME
			%
			%
			% The NDI_DAQSYSTEM GETEPOCHPROBEMAP checks its DAQREADER object to see if it has a method called
			% 'GETEPOCHPROBEMAP' that accepts the EPOCHPROBEMAP filename and the EPOCHFILES for that epoch.
			% If it does have a method by that name, it is called and the output returned. If it does not, then the FILENAVIGATOR
			% parameter's method is called.
			% 
				m = methods(ndi_daqsystem_obj.daqreader);
				if ~isempty(intersect(m,'getepochprobemap')),
					ecfname = ndi_daqsystem_obj.epochprobemapfilename(epoch);
					epochfiles = ndi_daqsystem_obj.filenavigator.getepochfiles(epoch);
						% it is remarkable that this is allowed in Matlab but it is beautiful
					epochprobemap = ndi_daqsystem_obj.daqreader.getepochprobemap(ecfname,epochfiles);
				else,
					epochprobemap = ndi_daqsystem_obj.filenavigator.getepochprobemap(epoch);
				end;

		end; % getepochprobemap
		
		%% functions that override ndi_documentservice
		function ndi_document_obj_set = newdocument(ndi_daqsystem_obj)
		% NEWDOCUMENT - create a new document set for NDI_DAQSYSTEM objects
		% 
		% NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_DAQSYSTEM_OBJ)
		%
		% Creates a set of documents that describe an NDI_DAQSYSTEM.
			ndi_document_obj_set{1} = ndi_daqsystem_obj.filenavigator.newdocument();
			ndi_document_obj_set{2} = ndi_daqsystem_obj.daqreader.newdocument();
			ndi_document_obj_set{3} = ndi_document('ndi_document_daqsystem.json','daqsystem.filenavigator',ndi_document_obj_set{1}.doc_unique_id(),...
					'daqsystem.daqreader',ndi_document_obj_set{2}.doc_unique_id);
		end

	end % methods
end % ndi_daqsystem classdef

