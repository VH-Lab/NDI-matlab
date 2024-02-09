classdef system < ndi.ido & ndi.epoch.epochset.param & ndi.documentservice
% ndi.daq.system - Create a new NDI_DEVICE class handle object
%
%  D = ndi.daq.system(NAME, THEFILENAVIGATOR)
%
%  Creates a new ndi.daq.system object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.

	properties (GetAccess=public, SetAccess=protected)
		name               % The name of the daq system
		filenavigator      % The ndi.file.navigator associated with this device
		daqreader          % The ndi.daq.reader associated with this device
		daqmetadatareader  % The ndi.daq.metadatareader associated with this device (cell array)
	end

	methods
		function obj = system(name,thefilenavigator,thedaqreader,thedaqmetadatareader)
			% ndi.daq.system - create a new NDI_DEVICE object
			%
			%  OBJ = ndi.daq.system(NAME, THEFILENAVIGATOR, THEDAQREADER)
			%
			%  Creates an ndi.daq.system with name NAME, NDI_FILENAVIGTOR THEFILENAVIGATOR and
			%  and ndi.daq.reader THEDAQREADER.
			%
			%  An ndi.file.navigator is an interface object to the raw data files
			%  on disk that are read by the ndi.daq.reader object.
			%
			%  ndi.daq.system is an abstract class, and a specific implementation must be called.
			%
				obj = obj@ndi.ido();
				loadfromfile = 0;
				if nargin==2 & isa(name,'ndi.session') & isa(thefilenavigator,'ndi.document');
					session = name;
					daqsystem_doc = thefilenavigator;
					daqreader_id = daqsystem_doc.dependency_value('daqreader_id');
					filenavigator_id = daqsystem_doc.dependency_value('filenavigator_id');
					docs = session.database_search(ndi.query('base.id','exact_string',daqreader_id,''));
					if numel(docs)~=1,
						error(['Could not find daqreader document with id ' daqreader_id '.']);
					end;
					daqreader_doc = docs{1};
					docs = session.database_search(ndi.query('base.id','exact_string',filenavigator_id,''));
					if numel(docs)~=1,
						error(['Could not find file navivgator document with id ' filenavigator_id'.']);
					end;
					filenavigator_doc = docs{1};

					D = daqsystem_doc.dependency_value_n('daqmetadatareader_id','ErrorIfNotFound',0);
					metadatadocs = {};
					thedaqmetadatareader = {};
					for i=1:numel(D),
						metadatadocs{i} = session.database_search(ndi.query('base.id','exact_string',D{i},''));
						if numel(metadatadocs{i})~=1,
							error(['Could not find daqmetadatareader document with id ' D{i} '.']);
						end;
						metadatadocs{i} = metadatadocs{i}{1};
						thedaqmetadatareader{i} = ndi.database.fun.ndi_document2ndi_object(metadatadocs{i},session);
					end;
					
					obj.daqreader = ndi.database.fun.ndi_document2ndi_object(daqreader_doc, session);
					obj.filenavigator = ndi.database.fun.ndi_document2ndi_object(filenavigator_doc,session);
					obj.name = daqsystem_doc.document_properties.base.name;
					obj.identifier = daqsystem_doc.document_properties.base.id;
					obj = obj.set_daqmetadatareader(thedaqmetadatareader);
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
						if ~isa(thedaqreader,'ndi.daq.reader'),
							error(['thedaqreader must be of type ndi.daq.reader']);
						end;
					end;

					if nargin>=4,
						
					else,
						thedaqmetadatareader = {};
					end;

					if (nargin==1) | (nargin>4),
						error(['Function requires 2, 3, or 4 input arguments exactly.']);
					end
		
					obj.name = name;
					if loadfromfile,
						error(['Loadfromfile no longer supported.']);
					else,
						obj.name = name;
						obj.filenavigator = thefilenavigator;
						obj.daqreader = thedaqreader;
						obj = obj.set_daqmetadatareader(thedaqmetadatareader);
					end;
				end;
		end; % ndi.daq.system()

		function ndi_daqsystem_obj = set_daqmetadatareader(ndi_daqsystem_obj, thedaqmetadatareaders)
			% SET_DAQMETADATAREADER - set the cell array of ndi.daq.metadatareader objects
			%
			% NDI_DAQSYSTEM_OBJ = SET_DAQMETADATAREADER(NDI_DAQSYSTEM_OBJ, NEWDAQMETADATAREADERS)
			%
			% Sets the 'daqmetadatareader' property of an ndi.daq.system object.
			% NEWDAQMETADATAREADERS should be a cell array of objects that have 
			% ndi.daq.metadatareader as a superclass.
			%
				if ~iscell(thedaqmetadatareaders),
					error(['THEDAQMETADATAREADERS must be a cell array.']);
				end;

				for i=1:numel(thedaqmetadatareaders),
					if ~isa(thedaqmetadatareaders{i},'ndi.daq.metadatareader'),
						error(['Element ' int2str(i) ' of THEDAQMETADATAREADERS is not of type ndi.daq.metadatareader.']);
					end;
				end;
				% if we are here, there are no errors
				ndi_daqsystem_obj.daqmetadatareader = thedaqmetadatareaders;
		end; % set_daqmetadatareader

		%% GUI functions
		function obj = ndi_daqsystem_gui_edit(ndi_daqsystem_obj)
			% NDI_DAQSYSTEM_GUI_EDIT - function for editing an ndi.daq.system object
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
			% EQ - are two ndi.daq.system objects equal?
			%
			% B = EQ(NDI_DAQSYSTEM_OBJ_A, NDI_DAQSYSTEM_OBJ_B)
			%
			% Returns 1 if the ndi.daq.system objects have the same name and class type.
			% The objects do not have to be the same handle or have the same space in memory.
			% Otherwise, returns 0.
			%
				b = strcmp(ndi_daqsystem_obj_a.name,ndi_daqsystem_obj_b.name) & ...
					strcmp(class(ndi_daqsystem_obj_a),class(ndi_daqsystem_obj_b));
		end % eq()

		%% functions that override ndi.epoch.epochset.param

		function ec = epochclock(ndi_daqsystem_obj, epoch_number)
			% EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of ndi.time.clocktype objects (or sub-class members).
			%
			% For the generic ndi.daq.system, this returns a single clock
			% type 'no_time';
			%
			% See also: ndi.time.clocktype
			%
				ec = {ndi.time.clocktype('no_time')};
		end % epochclock

		function t0t1 = t0_t1(ndi_epochset_obj, epoch_number)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: ndi.time.clocktype, EPOCHCLOCK
			%
				t0t1 = {[NaN NaN]};
		end % t0t1

		function eid = epochid(ndi_daqsystem_obj, epoch_number)
			% EPOCHID - return the epoch id string for an epoch
			%
			% EID = EOPCHID(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
			%
			% Returns the EPOCHID for epoch with number EPOCH_NUMBER.
			% In ndi.daq.system, this is determined by the associated
			% ndi.file.navigator object.
			%
				eid = ndi_daqsystem_obj.filenavigator.epochid(epoch_number);
		end % epochid

		function probes_struct=getprobes(ndi_daqsystem_obj)
			% GETPROBES = Return all of the probes associated with an ndi.daq.system object
			%
			% PROBES_STRUCT = GETPROBES(NDI_DAQSYSTEM_OBJ)
			%
			% Returns all probes associated with the ndi.daq.system object NDI_DEVICE_OBJ
			%
			% This function returns a structure with fields of all unique probes across
			% all EPOCHPROBEMAP objects returned in ndi.daq.system/GETEPOCHPROBEMAP.
			% The fields are 'name', 'reference', and 'type'.

				et = epochtable(ndi_daqsystem_obj);

				probes_struct = vlt.data.emptystruct('name','reference','type','subject_id');
				
				for n=1:numel(et),
					epc = et(n).epochprobemap;
					if ~isempty(epc),
						for ec = 1:numel(epc),
							% is it mine?
							myprobemap = ndi.daq.daqsystemstring(epc(ec).devicestring);
							if strcmpi(myprobemap.devicename, ndi_daqsystem_obj.name),
								newentry.name = epc(ec).name;
								newentry.reference= epc(ec).reference;
								newentry.type= epc(ec).type;
								newentry.subject_id = epc(ec).subjectstring;
								probes_struct(end+1) = newentry;
							end
						end
					end
				end
				probes_struct = vlt.data.equnique(probes_struct);
		end % getprobes()

		function exp=session(ndi_daqsystem_obj)
			% SESSION - return the ndi.session object associated with the ndi.daq.system object
			%
			% EXP = SESSION(NDI_DAQSYSTEM_OBJ)
			%
			% Return the ndi.session object associated with the ndi.daq.system of the
			% ndi.daq.system object.
			%
				exp = ndi_daqsystem_obj.filenavigator.session;
		end % session()

		function ndi_daqsystem_obj=setsession(ndi_daqsystem_obj, session)
			% SETSESSION - set the SESSION for an ndi.daq.system object's filenavigator (type ndi.daq.system)
			%
			% NDI_DAQSYSTEM_OBJ = SETSESSION(NDI_DEVICE_OBJ, SESSION)
			%
			% Set the SESSION property of an ndi.daq.system object's ndi.daq.system object
			%	
				ndi_daqsystem_obj.filenavigator = setsession(ndi_daqsystem_obj.filenavigator,session);
		end % setsession()

		%% functions that override ndi.epoch.epochset, ndi.epoch.epochset.param

		function deleteepoch(ndi_daqsystem_obj, number, removedata)
		% DELETEEPOCH - Delete an epoch and an epoch record from a device
		%
		%   DELETEEPOCH(NDI_DAQSYSTEM_OBJ, NUMBER ... [REMOVEDATA])
		%
		% Deletes the data and ndi.epoch.epochprobemap_daqsystem and epoch data for epoch NUMBER.
		% If REMOVEDATA is present and is 1, the data and record are physically deleted.
		% If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
		%
		% In the abstract class, this command takes no action.
		%
		% See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem
			error(['Not implemented yet.']);
		end % deleteepoch()

                function [cache,key] = getcache(ndi_daqsystem_obj)
			% GETCACHE - return the NDI_CACHE and key for ndi.daq.system
			%
			% [CACHE,KEY] = GETCACHE(NDI_DAQSYSTEM_OBJ)
			%
			% Returns the CACHE and KEY for the ndi.daq.system object.
			%
			% The CACHE is returned from the associated session.
			% The KEY is the string 'daqsystem_' followed by the object's id.
			%
			% See also: ndi.daq.system, NDI_BASE

				cache = [];
				key = [];
				if isa(ndi_daqsystem_obj.session,'handle'),
					exp = ndi_daqsystem_obj.session();
					cache = exp.cache;
					key = ['daqsystem_' ndi_daqsystem_obj.id() ] ;
				end
		end

		function et = buildepochtable(ndi_daqsystem_obj)
			% BUILDEPOCHTABLE - Build the epochtable for an ndi.daq.system object
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
			% EPOCHPROBEMAPFILENAME - return the filename for the ndi.epoch.epochprobemap_daqsystem file for an epoch
			%
			% ECFNAME = EPOCHPROBEMAPFILENAME(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the EPOCHPROBEMAPFILENAME for the ndi.daq.system epoch EPOCH_NUMBER_OR_ID.
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
			% Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
			% epoch EPOCH.
			%
			% For the abstract class ndi.daq.system, EPOCHPROBEMAP is always valid as long as
			% EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
			%
			% See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem
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
				etfname = ndi.epoch.epochset.param.obj.filenavigator.epochtagfilename(epochnumber);
                end % epochtagfilename()

		function epochprobemap = getepochprobemap(ndi_daqsystem_obj, epoch)
			% GETEPOCHPROBEMAP - Return the epoch record for an ndi.daq.system object
			%
			% EPOCHPROBEMAP = GETEPOCHPROBEMAP(NDI_DAQSYSTEM_OBJ, EPOCH)
			%
			% Inputs:
			%     NDI_EPOCHSET_PARAM_OBJ - the ndi.epoch.epochset.param object
			%     EPOCH - the epoch number or identifier
			%
			% Output:
			%     EPOCHPROBEMAP - The epoch record information associated with epoch N for device with name DEVICENAME
			%
			%
			% The ndi.daq.system GETEPOCHPROBEMAP checks its DAQREADER object to see if it has a method called
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

		function metadata = getmetadata(ndi_daqsystem_obj, epoch, channel)
			% GETMETADATA - get metadata for an epoch
			% 
			% METADATA = GETMETADATA(NDI_DAQSYSTEM_OBJ, EPOCH, CHANNEL)
			%
			% Returns the metadata (cell array of entries) for EPOCH for metadata channel
			% CHANNEL. CHANNEL indicates the number of the ndi.daq.metadatareader to use 
			% to obtain the data.
				N = numel(ndi_daqsystem_obj.daqmetadatareader);
				if ~ (channel >=1 & channel <= N),
					error(['Metadata channel out of range of ' int2str(min(N,1)) '..' int2str(N) '.']);
				end;
				epochfiles = ndi_daqsystem_obj.filenavigator.getepochfiles(epoch);
				if ~ndi.file.navigator.isingested(epochfiles),
					metadata = ndi_daqsystem_obj.daqmetadatareader{channel}.readmetadata(epochfiles);
				else,
					metadata = ndi_daqsystem_obj.daqmetadatareader{channel}.readmetadata_ingested(epochfiles,...
						ndi_daqsystem_obj.session());
				end;
		end; % getmetadata()

		function [b,d] = ingest(ndi_daqsystem_obj)
			% INGEST - ingest the data from an ndi.daq.system into the database
			%
			% [B,D] = INGEST(NDI_DAQSYSTEM_OBJ)
			%
			% Ingest any uningested epochs from an ndi.daq.system object into the database.
			% B is 1 if the operation is successful. D is a cell array of new ndi.document objects
			% that were created and added to the database.
			%
				b = 0;
				et = ndi_daqsystem_obj.epochtable();
				filenavigator_ingest_called = 0;
				d = {}; % our array of many documents to be added to database

				for i=1:numel(et),
					ef = et(i).underlying_epochs.underlying; % epochfiles
					if ndi.file.navigator.isingested(ef), % already ingested, skip it
					else, % not ingested, we need to ingest it
							% future note: down the road we might want to add one epoch at a time
						if ~filenavigator_ingest_called,
							new_d = ndi_daqsystem_obj.filenavigator.ingest();
							d = cat(1,d,new_d(:));
							filenavigator_ingest_called = 1;
						end;
						new_d = ndi_daqsystem_obj.daqreader.ingest_epochfiles(ef,et(i).epoch_id);
						if ~iscell(new_d),
							new_d = {new_d};
						end;
						d = cat(1,d,new_d(:));
						for j=1:numel(ndi_daqsystem_obj.daqmetadatareader),
							new_d = ndi_daqsystem_obj.daqmetadatareader{j}.ingest_epochfiles(ef,et(i).epoch_id);
							if ~iscell(new_d),
								new_d = {new_d};
							end;
							d = cat(1,d,new_d(:));
						end;
					end;
				end;
				ndi_daqsystem_obj.filenavigator.session.database_add(d);
				ndi_daqsystem_obj.session.cache.clear();
				b = 1;
		end; % ingest()

		%% functions that override ndi.documentservice

		function ndi_document_obj_set = newdocument(ndi_daqsystem_obj)
			% NEWDOCUMENT - create a new document set for ndi.daq.system objects
			% 
			% NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_DAQSYSTEM_OBJ)
			%
			% Creates a set of documents that describe an ndi.daq.system.
			
				ndi_document_obj_set{1} = ndi_daqsystem_obj.filenavigator.newdocument();
				ndi_document_obj_set{2} = ndi_daqsystem_obj.daqreader.newdocument();
				ndi_document_obj_set{3} = ndi.document('daq/daqsystem',...
					'daqsystem.ndi_daqsystem_class', class(ndi_daqsystem_obj),...
					'base.id', ndi_daqsystem_obj.id(),...
					'base.name', ndi_daqsystem_obj.name,...
					'base.session_id', ndi_daqsystem_obj.session.id());
				ndi_document_obj_set{3} = ndi_document_obj_set{3}.set_dependency_value( ...
					'filenavigator_id', ndi_daqsystem_obj.filenavigator.id());
				ndi_document_obj_set{3} = ndi_document_obj_set{3}.set_dependency_value( ...
					'daqreader_id', ndi_daqsystem_obj.daqreader.id());
				for i=1:numel(ndi_daqsystem_obj.daqmetadatareader),
					ndi_document_obj_set{end+1} = ndi_daqsystem_obj.daqmetadatareader{i}.newdocument();
					ndi_document_obj_set{3} = ndi_document_obj_set{3}.add_dependency_value_n('daqmetadatareader_id',...
						ndi_document_obj_set{end}.id());
				end;
		end;  % newdocument()

		function sq = searchquery(ndi_daqsystem_obj)
			% SEARCHQUERY - search for an ndi.daq.system
			%
			% SQ = SEARCHQUERY(NDI_DAQSYSTEM_OBJ)
			%
			% Returns SQ, an ndi.query object that searches the database for the ndi.daq.system object
			%
				sq = ndi.query({'base.id',ndi_daqsystem_obj.id(), ...  % really this is the only one necessary
						'base.name', ndi_daqsystem_obj.name, ...
						'base.session_id', ndi_daqsystem_obj.session.id()});

				sq = sq & ndi.query('','depends_on','filenavigator_id',ndi_daqsystem_obj.filenavigator.id()) & ...
					ndi.query('','depends_on','daqreader_id',ndi_daqsystem_obj.daqreader.id());

		end; % searchquery()

	end % methods
end % ndi.daq.system classdef

