classdef nsd_epochset_param < nsd_epochset
% NSD_EPOCHSET_PARAM - special class of NSD_EPOCHSET that can read/write parameters about epochs
%

	properties (SetAccess=protected,GetAccess=public)
		epochcontents_class  % The (sub)class of NSD_EPOCHCONTENTS to be used; NSD_EPOCHCONTS is the default; a string
		
	end % properties

	methods

		function obj = nsd_epochset_param(epochcontents_class_)
			% NSD_EPOCHSET_PARAM - Constructor for NSD_EPOCHSET_PARAM objects
			%
			% NSD_EPOCHSET_PARAM_OBJ = NSD_EPOCHSET_PARAM(EPOCHCONTENTS_CLASS)
			%
			% Create a new NSD_EPOCHSET_PARAM object. It has one optional input argument,
			% EPOCHCONTENTS_CLASS, a string, that specifies the name of the class or subclass
			% of NSD_EPOCHCONTENTS to be used.
			%
				if nargin==0,
					obj.epochcontents_class = 'nsd_epochcontents';
				else,
					obj.epochcontents_class = epochcontents_class_;
				end
		end % nsd_epochset_param

		%% EPOCHCONTENTS methods

		function ecfname = epochcontentsfilename(nsd_epochset_param_obj, epochnumber)
			% EPOCHCONTENTSFILENAME - return the filename for the NSD_EPOCHCONTENTS file for an epoch
			%
			% ECFNAME = EPOCHCONTENTSFILENAME(NSD_EPOCHSET_PARAM_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the EPOCHCONTENTSFILENAME for the NSD_EPOCHSET_PARAM_OBJ epoch EPOCH_NUMBER_OR_ID.
			% If there is no epoch NUMBER, an error is generated. The file name is returned with
			% a full path.
			%
			% In this abstract class, an error is always generated. It must be overridden by child classes.
			%
			%
				error('Abstract class, no filenames');
		end % epochcontentsfilename

		function [b,msg] = verifyepochcontents(nsd_epochset_param_obj, epochcontents, number)
			% VERIFYEPOCHCONTENTS - Verifies that an EPOCHCONTENTS is appropriate for the NSD_EPOCHSET_PARAM object
			%
			%   [B,MSG] = VERIFYEPOCHCONTENTS(NSD_EPOCHSET_PARAM, EPOCHCONTENTS, EPOCH_NUMBER_OR_ID)
			%
			% Examines the NSD_EPOCHCONTENTS EPOCHCONTENTS and determines if it is valid for the given 
			% epoch number or epoch id EPOCH_NUMBER_OR_ID.
			%
			% For the abstract class EPOCHCONTENTS is always valid as long as EPOCHCONTENTS is an
			% NSD_EPOCHCONTENTS object.
			%
			% If B is 0, then the error message is returned in MSG.
			%
			% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS
				msg = '';
				b = isa(epochcontents, 'nsd_epochcontents');
				if ~b,
					msg = 'epochcontents is not a member of the class NSD_EPOCHCONTENTS; it must be.';
				end
                end % verifyepochcontents()

		function epochcontents = getepochcontents(nsd_epochset_param_obj, N)
			% GETEPOCHCONTENTS - Return the epoch record for a given nsd_filetree and epoch number
			%
			%  EPOCHCONTENTS = GETEPOCHCONTENTS(SELF, N, IODEVICENAME)
			%
			% Inputs:
			%     SELF - the data tree object
			%     N - the epoch number
			%     DEVICENAME - The NSD name of the device
			%
			% Output:
			%     EPOCHCONTENTS - The epoch record information associated with epoch N for device with name DEVICENAME
			%
			%
				epochcontentsfile_fullpath = epochcontentsfilename(nsd_epochset_param_obj, N);
				eval(['epochcontents = ' nsd_epochset_param_obj.epochcontents_class '(epochcontentsfile_fullpath);']);
				[b,msg]=verifyepochcontents(nsd_epochset_param_obj,epochcontents);
				if b,
					error(['The epochcontents are not valid for this object: ' msg]);
				end
		end

		function setepochcontents(nsd_epochset_param_obj, epochcontents, number, overwrite)
			% SETEPOCHCONTENTS - Sets the epoch record of a particular epoch
			%
			%   SETEPOCHCONTENTS(NSD_EPOCHSET_PARAM_OBJ, EPOCHCONTENTS, NUMBER, [OVERWRITE])
			%
			% Sets or replaces the NSD_EPOCHCONTENTS for NSD_EPOCHSET_PARAM_OBJ with EPOCHCONTENTS for the epoch
			% numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
			% Otherwise, an error is given if there is an existing epoch record.
			%
			% See also: NSD_IODEVICE, NSD_EPOCHCONTENTS

				if nargin<4,
					overwrite = 0;
				end

				[b,msg] = verifyepochcontents(nsd_epochset_param_obj,epochcontents,number);

				if b,
					ecfname = nsd_epochset_param_obj.epochcontentsfilename(number);
					if exist(ecfname,'file') & ~overwrite,
						error(['epochcontents file exists and overwrite was not requested.']);
					end
					epochcontents.savetofile(ecfname);
				else,
					error(['Invalid epochcontents: ' msg '.']);
				end
		end % setepochcontents()

		%% TAG methods

                function etfname = epochtagfilename(nsd_epochset_param_obj, epochnumber)
			% EPOCHTAGFILENAME - return the file path for the tag file for an epoch
			%
			% ETFNAME = EPOCHTAGFILENAME(NSD_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
			%
			% In this base class, empty is returned because it is an abstract class.
			%
				etfname = ''; % abstract class
				error('Abstract class does not have epochtagfiles.');
                end % epochtagfilename()

                function tag = getepochtag(nsd_epochset_param_obj, number)
			% GETEPOCHTAG - Get tag(s) from an epoch
			%
			% TAG = GETEPOCHTAG(NSD_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. If there are no files in
			% EPOCHNUMBER then an error is returned.
			%
				etfname = epochtagfilename(nsd_epochset_param_obj, number);
				if exist(etfname,'file'),
					tag = loadStructArray(etfname);
				else,
					tag = emptystruct('name','value');
				end
                end % getepochtag()

                function setepochtag(nsd_epochset_param_obj, number, tag)
			% SETEPOCHTAG - Set tag(s) for an epoch
			%
			% SETEPOCHTAG(NSD_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. These tags will replace any
			% tags in the epoch directory. If there is no epoch EPOCHNUMBER, then 
			% an error is returned.
			%
				if ~isfield(tag,'name') | ~isfield(tag,'value') | ~(numel(fieldnames(tag))==2),
					error(['TAG should have fields ''name'' and ''value'' only.']);
				end

				etfname = epochtagfilename(nsd_epochset_param_obj, number, epochfiles);
				if ~isempty(tag),
					saveStructArray(etfname,tag);
				else, % delete the file so it is empty
					if exist(etfname,'file'),
						delete(etfname);
					end
				end
                end % setepochtag()

                function addepochtag(nsd_epochset_param_obj, number, tag)
			% ADDEPOCHTAG - Add tag(s) for an epoch
			%
			% ADDEPOCHTAG(NSD_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. These tags will be added to any
			% tags in the epoch EPOCHNUMBER. If tags with the same names as those in TAG
			% already exist, they will be overwritten. If there is no epoch 
			% EPOCHNUMBER, then an error is returned.
			%
				if ~isfield(tag,'name') | ~isfield(tag,'value'),
					error(['TAG should have fields ''name'' and ''value'' only.']);
				end
				etfname = epochtagfilename(nsd_epochset_param_obj, number, epochfiles);
				currenttag = getepochtag(nsd_epochset_param_obj, number);
				% update current tags, replacing any existing names
				tagsadded = [];
				if ~isempty(currenttag),
					for i=1:numel(tag),
						% check for matches
						index = find(strcmp(tag(i).name,{currenttag.name}));
						if ~isempty(index),
							currenttag(index) = tag(i);
							tagsadded(end+1) = i;
						end
					end
				end
				tag = tag(setdiff(1:numel(tag),tagsadded));
				currenttag = cat(1,currenttag(:),tag(:));
				setepochtag(nsd_epochset_param_obj, number, currenttag, epochfiles);
                end % addepochtag()

		function removeepochtag(nsd_epochparams_obj, number, name)
			% REMOVEEPOCHTAG - Remove tag(s) for an epoch
			%
			% REMOVEEPOCHTAG(NSD_EPOCH_PARAM_OBJ, EPOCHNUMBER, NAME)
			%
			% Tags are name/value pairs returned in the form of a structure
			% array with fields 'name' and 'value'. Any tags with name 'NAME' will
			% be removed from the tags in the epoch EPOCHNUMBER.
			% tags in the epoch directory. If tags with the same names as those in TAG
			% already exist, they will be overwritten. If there is no epoch
			% EPOCHNUMBER, then an error is returned.
			%
			% NAME can be a single string, or it can be a cell array of strings
			% (which will result in the removal of multiple tags).
			%
				etfname = epochtagfilename(nsd_epochparams_obj, number, epochfiles);
				currenttag = getepochtag(nsd_epochparams_obj, number);
				% update current tags, replacing any existing names
				tagstoremove = [];
				if ~isempty(currenttag),
					for i=1:numel(name),
						index = find(strcmp(name,{currenttag.name}));
						if ~isempty(index),
							tagstoremove(end+1) = i;
						end
					end
				end
				currenttag = currenttag(setdiff(1:numel(currenttag),tagstoremove));
				currenttag = cat(1,currenttag(:),tag(:));
				setepochtag(nsd_epochparams_obj, number, currenttag, epochfiles);
                end % removeepochtag()

	end % methods

end % classdef

