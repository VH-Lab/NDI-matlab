classdef ndi_daqsystem < ndi_base & ndi_epochset_param
% NDI_DAQSYSTEM - Create a new NDI_DEVICE class handle object
%
%  D = NDI_DAQSYSTEM(NAME, THEFILENAVIGATOR)
%
%  Creates a new NDI_DAQSYSTEM object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.

	properties (GetAccess=public, SetAccess=protected)
		name            % The name of the daq system
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
			obj = obj@ndi_base('dummy');
			loadfromfile = 0;
			if nargin==2 & isa(name,'ndi_experiment') & isa(thefilenavigator,'ndi_document');
				experiment = name;
				daqsystem_doc = thefilenavigator;
				daqreader_id = daqsystem_doc.dependency_value('daqreader_id');
				filenavigator_id = daqsystem_doc.dependency_value('filenavigator_id');
				docs = experiment.database_search(ndi_query('ndi_document.id','exact_string',daqreader_id,''));
				if numel(docs)~=1,
					error(['Could not find daqreader document with id ' daqreader_id '.']);
				end;
				daqreader_doc = docs{1};
				docs = experiment.database_search(ndi_query('ndi_document.id','exact_string',filenavigator_id,''));
				if numel(docs)~=1,
					error(['Could not find daqreader document with id ' daqreader_id '.']);
				end;
				filenavigator_doc = docs{1};
				
				obj.daqreader = ndi_document2ndi_object(daqreader_doc, experiment);
				obj.filenavigator = ndi_document2ndi_object(filenavigator_doc,experiment);
				obj.name = daqsystem_doc.document_properties.ndi_document.name;
				obj.identifier = daqsystem_doc.document_properties.ndi_document.id();
			else
				if nargin==0, % undocumented 0 argument creator
					name = '';
					thefilenavigator = [];
					thedaqreader = [];
				end;
				if nargin>=2,
					if ischar(thefilenavigator), % it is a command
						loadfromfile = 1;
						error(['Loadfromfile no longer supported.']);
						filename = name;
						name='';
						if ~strcmp(lower(thefilenavigator), lower('OpenFile')),
							error(['Unknown command.']);
						else,
							thefilenavigator=[];
						end;
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
        
				obj.name = name;
				if loadfromfile,
					error(['Loadfromfile no longer supported.']);
				else,
					obj.name = name;
					obj.filenavigator = thefilenavigator;
					obj.daqreader = thedaqreader;
				end;
			end;
	end; % ndi_daqsystem()

		%% GUI functions
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

		%% functions that override NDI_EPOCHSET_PARAM

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
			% NDI_DAQSYSTEM_OBJ = SETEXPERIMENT(NDI_DEVICE_OBJ, EXPERIMENT)
			%
			% Set the EXPERIMENT property of an NDI_DAQSYSTEM object's NDI_DAQSYSTEM object
			%	
				ndi_daqsystem_obj.filenavigator = setexperiment(ndi_daqsystem_obj.filenavigator,experiment);
		end % setexperiment()

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
			% The KEY is the string 'daqsystem_' followed by the object's id.
			%
			% See also: NDI_DAQSYSTEM, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_daqsystem_obj.experiment,'handle'),
					exp = ndi_daqsystem_obj.experiment();
					cache = exp.cache;
					key = ['daqsystem_' ndi_daqsystem_obj.id() ] ;
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
				ndi_document_obj_set{3} = ndi_document('ndi_document_daqsystem.json',...
					'daqsystem.ndi_daqsystem_class', class(ndi_daqsystem_obj),...
					'ndi_document.id', ndi_daqsystem_obj.id(),...
					'ndi_document.name', ndi_daqsystem_obj.name,...
					'ndi_document.experiment_id', ndi_daqsystem_obj.experiment.id());
				ndi_document_obj_set{3} = ndi_document_obj_set{3}.set_dependency_value( ...
					'filenavigator_id', ndi_daqsystem_obj.filenavigator.id());
				ndi_document_obj_set{3} = ndi_document_obj_set{3}.set_dependency_value( ...
					'daqreader_id', ndi_daqsystem_obj.daqreader.id());
		end;  % newdocument()

		function sq = searchquery(ndi_daqsystem_obj)
			% SEARCHQUERY - search for an NDI_DAQSYSTEM
			%
			% SQ = SEARCHQUERY(NDI_DAQSYSTEM_OBJ)
			%
			% Returns SQ, an NDI_QUERY object that searches the database for the NDI_DAQSYSTEM object
			%
				sq = ndi_query({'ndi_document.id',ndi_daqsystem_obj.id(), ...
						'ndi_document.name', ndi_daqsystem_obj.name, ...
						'ndi_document.experiment_id', ndi_daqsystem_obj.experiment.id()});

				sq = sq & ndi_query('','depends_on','filenavigator_id',ndi_daqsystem_obj.filenavigator.id()) & ...
					ndi_query('','depends_on','daqreader_id',ndi_daqsystem_obj.daqreader.id());

		end; % searchquery()

	end % methods
end % ndi_daqsystem classdef

