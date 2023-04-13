classdef reader < ndi.ido & ndi.documentservice
% NDI_DAQREADER - A class for objects that read samples for NDI_DAQSYSTEM objects
%
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods

		function obj = reader(varargin)
		% ndi.daq.reader - create a new ndi.daq.reader object
		%
		%  OBJ = ndi.daq.reader()
		%  
		%  Creates an ndi.daq.reader. 
		%
		%  OBJ = ndi.daq.reader(NDI_SESSION_OBJ, NDI_DOCUMENT_OBJ)
		%    
		%  Creates an ndi.daq.reader from an NDI_DOCUMENT_OBJ.
		%
		%  ndi.daq.reader is essentially an abstract class, and a specific implementation must be used.
		%
			obj = obj@ndi.ido();

			loadfromfile = 0;

			if nargin==2 & isa(varargin{1},'ndi.session') & isa(varargin{2},'ndi.document'),
				obj.identifier = varargin{2}.document_properties.ndi_document.id;
			elseif nargin>=2,
				if ischar(varargin{2}), % it is a command
					loadfromfile = 1;
					filename = varargin{1};
					if ~strcmp(lower(varargin{2}), lower('OpenFile')),
						error(['Unknown command.']);
					end
				end;
			end;

			if loadfromfile,
				error(['Load from file no longer supported.']);
			end
		end % ndi.daq.reader

		% EPOCHSET functions, although this object is NOT an EPOCHSET object

		function ec = epochclock(ndi_daqreader_obj, epochfiles)
			% EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_DAQREADER_OBJ, EPOCHFILES)
			%
			% Return the clock types available for this epoch as a cell array
			% of ndi.time.clocktype objects (or sub-class members).
			%
			% For the generic ndi.daq.reader, this returns a single clock
			% type 'no_time';
			%
			% See also: ndi.time.clocktype
			%
				ec = {ndi.time.clocktype('no_time')};
		end % epochclock

		function t0t1 = t0_t1(ndi_epochset_obj, epochfiles)
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

		function [b,msg] = verifyepochprobemap(ndi_daqreader_obj, epochprobemap, epochfiles)
			% VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_OBJ, EPOCHPROBEMAP, NUMBER)
			%
			% Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class ndi.daq.reader, EPOCHPROBEMAP is always valid as long as
			% EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
			%
			% See also: ndi.daq.reader, ndi.epoch.epochprobemap_daqsystem
				msg = '';
				b = isa(epochprobemap, 'ndi.epoch.epochprobemap_daqsystem');
				if ~b,
					msg = 'epochprobemap is not a member of the class ndi.epoch.epochprobemap_daqsystem; it must be.';
					return;
				end;

				for i=1:numel(epochprobemap),
					try,
						thedevicestring = ndi_daqreaderstring(epochprobemap(i).devicestring);
					catch,
						b = 0;
						msg = ['Error evaluating devicestring ' epochprobemap(i).devicestring '.'];
                                        end
                                end
		end % verifyepochprobemap

		function b = eq(ndi_daqreader_obj1, ndi_daqreader_obj2)
			% EQ - tests whether 2 ndi.daq.reader objects are equal
			%
			% B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
			%
			% Examines whether or not the ndi.daq.reader objects are equal.
			%
				b = strcmp(class(ndi_daqreader_obj1),class(ndi_daqreader_obj2));
				b = b & strcmp(ndi_daqreader_obj1.id(), ndi_daqreader_obj2.id());
		end; % eq()
		
		%% functions that override ndi.documentservice

		function ndi_document_obj = newdocument(ndi_daqreader_obj)
			% NEWDOCUMENT - create a new ndi.document for an ndi.daq.reader object
			%
			% DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
			%
			% Creates an ndi.document object DOC that represents the
			%    ndi.daq.reader object. 
				ndi_document_obj = ndi.document('daqreader.json',...
					'daqreader.ndi_daqreader_class',class(ndi_daqreader_obj),...
					'ndi_document.id', ndi_daqreader_obj.id());
		end; % newdocument()

		function sq = searchquery(ndi_daqreader_obj)
			% SEARCHQUERY - create a search for this ndi.daq.reader object
			%
			% SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
			%
			% Creates a search query for the ndi.daq.reader object. 
			% 
				sq = {'ndi_document.id', ndi_daqreader_obj.id() };
		end; % searchquery()

	end % methods
		
end % ndi.daq.reader classdef

