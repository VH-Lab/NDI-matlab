classdef param < ndi.epoch.epochset
    % NDI_EPOCHSET_PARAM - special class of NDI_EPOCHSET that can read/write parameters about epochs
    %

    properties (SetAccess=protected,GetAccess=public)
        epochprobemap_class  % The (sub)class of ndi.epoch.epochprobemap_daqsystem to be used; NDI_EPOCHCONTS is the default; a string

    end % properties

    methods

        function obj = param(epochprobemap_class_)
            % ndi.epoch.epochset.param - Constructor for ndi.epoch.epochset.param objects
            %
            % NDI_EPOCHSET_PARAM_OBJ = ndi.epoch.epochset.param(EPOCHPROBEMAP_CLASS)
            %
            % Create a new ndi.epoch.epochset.param object. It has one optional input argument,
            % EPOCHPROBEMAP_CLASS, a string, that specifies the name of the class or subclass
            % of ndi.epoch.epochprobemap_daqsystem to be used.
            %
            if nargin==0,
                obj.epochprobemap_class = 'ndi.epoch.epochprobemap_daqsystem';
            else,
                obj.epochprobemap_class = epochprobemap_class_;
            end
        end % ndi.epoch.epochset.param

        %% EPOCHPROBEMAP methods

        function ecfname = epochprobemapfilename(ndi_epochset_param_obj, epochnumber)
            % EPOCHPROBEMAPFILENAME - return the filename for the ndi.epoch.epochprobemap_daqsystem file for an epoch
            %
            % ECFNAME = EPOCHPROBEMAPFILENAME(NDI_EPOCHSET_PARAM_OBJ, EPOCH_NUMBER_OR_ID)
            %
            % Returns the EPOCHPROBEMAPFILENAME for the NDI_EPOCHSET_PARAM_OBJ epoch EPOCH_NUMBER_OR_ID.
            % If there is no epoch NUMBER, an error is generated. The file name is returned with
            % a full path.
            %
            % In this abstract class, an error is always generated. It must be overridden by child classes.
            %
            %
            error('Abstract class, no filenames');
        end % epochprobemapfilename

        function [b,msg] = verifyepochprobemap(ndi_epochset_param_obj, epochprobemap, number)
            % VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is appropriate for the ndi.epoch.epochset.param object
            %
            %   [B,MSG] = VERIFYEPOCHPROBEMAP(ndi.epoch.epochset.param, EPOCHPROBEMAP, EPOCH_NUMBER_OR_ID)
            %
            % Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given
            % epoch number or epoch id EPOCH_NUMBER_OR_ID.
            %
            % For the abstract class EPOCHPROBEMAP is always valid as long as EPOCHPROBEMAP is an
            % ndi.epoch.epochprobemap_daqsystem object.
            %
            % If B is 0, then the error message is returned in MSG.
            %
            % See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem
            msg = '';
            b = isa(epochprobemap, 'ndi.epoch.epochprobemap');
            if ~b,
                msg = 'epochprobemap is not a member of the class ndi.epoch.epochprobemap_daqsystem; it must be.';
            end
        end % verifyepochprobemap()

        function epochprobemap = getepochprobemap(ndi_epochset_param_obj, N)
            % GETEPOCHPROBEMAP - Return the epoch record for a given ndi.epoch.epochset.param epoch number
            %
            %  EPOCHPROBEMAP = GETEPOCHPROBEMAP(NDI_EPOCHSET_PARAM_OBJ, N)
            %
            % Inputs:
            %     NDI_EPOCHSET_PARAM_OBJ - the ndi.epoch.epochset.param object
            %     N - the epoch number or identifier
            %
            % Output:
            %     EPOCHPROBEMAP - The epoch record information associated with epoch N for device with name DEVICENAME
            %
            epochprobemapfile_fullpath = epochprobemapfilename(ndi_epochset_param_obj, N);
            eval(['epochprobemap = ' ndi_epochset_param_obj.epochprobemap_class '(epochprobemapfile_fullpath);']);
            [b,msg]=verifyepochprobemap(ndi_epochset_param_obj,epochprobemap, N);
            if ~b,
                error(['The epochprobemap are not valid for this object: ' msg]);
            end
        end

        function setepochprobemap(ndi_epochset_param_obj, epochprobemap, number, overwrite)
            % SETEPOCHPROBEMAP - Sets the epoch record of a particular epoch
            %
            %   SETEPOCHPROBEMAP(NDI_EPOCHSET_PARAM_OBJ, EPOCHPROBEMAP, NUMBER, [OVERWRITE])
            %
            % Sets or replaces the ndi.epoch.epochprobemap_daqsystem for NDI_EPOCHSET_PARAM_OBJ with EPOCHPROBEMAP for the epoch
            % numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
            % Otherwise, an error is given if there is an existing epoch record.
            %
            % See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem

            if nargin<4,
                overwrite = 0;
            end

            [b,msg] = verifyepochprobemap(ndi_epochset_param_obj,epochprobemap,number);

            if b,
                ecfname = ndi_epochset_param_obj.epochprobemapfilename(number);
                if isfile(ecfname) & ~overwrite,
                    error(['epochprobemap file exists and overwrite was not requested.']);
                end
                epochprobemap.savetofile(ecfname);
            else,
                error(['Invalid epochprobemap: ' msg '.']);
            end
        end % setepochprobemap()

        %% TAG methods

        function etfname = epochtagfilename(ndi_epochset_param_obj, epochnumber)
            % EPOCHTAGFILENAME - return the file path for the tag file for an epoch
            %
            % ETFNAME = EPOCHTAGFILENAME(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
            %
            % In this base class, empty is returned because it is an abstract class.
            %
            etfname = ''; % abstract class
            error('Abstract class does not have epochtagfiles.');
        end % epochtagfilename()

        function tag = getepochtag(ndi_epochset_param_obj, number)
            % GETEPOCHTAG - Get tag(s) from an epoch
            %
            % TAG = GETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
            %
            % Tags are name/value pairs returned in the form of a structure
            % array with fields 'name' and 'value'. If there are no files in
            % EPOCHNUMBER then an error is returned.
            %
            etfname = epochtagfilename(ndi_epochset_param_obj, number);
            if isfile(etfname),
                tag = vlt.file.loadStructArray(etfname);
            else,
                tag = vlt.data.emptystruct('name','value');
            end
        end % getepochtag()

        function setepochtag(ndi_epochset_param_obj, number, tag)
            % SETEPOCHTAG - Set tag(s) for an epoch
            %
            % SETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
            %
            % Tags are name/value pairs returned in the form of a structure
            % array with fields 'name' and 'value'. These tags will replace any
            % tags in the epoch directory. If there is no epoch EPOCHNUMBER, then
            % an error is returned.
            %
            if ~isfield(tag,'name') | ~isfield(tag,'value') | ~(numel(fieldnames(tag))==2),
                error(['TAG should have fields ''name'' and ''value'' only.']);
            end

            etfname = epochtagfilename(ndi_epochset_param_obj, number, epochfiles);
            if ~isempty(tag),
                vlt.file.saveStructArray(etfname,tag);
            else, % delete the file so it is empty
                if isfile(etfname),
                    delete(etfname);
                end
            end
        end % setepochtag()

        function addepochtag(ndi_epochset_param_obj, number, tag)
            % ADDEPOCHTAG - Add tag(s) for an epoch
            %
            % ADDEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
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
            etfname = epochtagfilename(ndi_epochset_param_obj, number, epochfiles);
            currenttag = getepochtag(ndi_epochset_param_obj, number);
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
            setepochtag(ndi_epochset_param_obj, number, currenttag, epochfiles);
        end % addepochtag()

        function removeepochtag(ndi_epochparams_obj, number, name)
            % REMOVEEPOCHTAG - Remove tag(s) for an epoch
            %
            % REMOVEEPOCHTAG(NDI_EPOCH_PARAM_OBJ, EPOCHNUMBER, NAME)
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
            etfname = epochtagfilename(ndi_epochparams_obj, number, epochfiles);
            currenttag = getepochtag(ndi_epochparams_obj, number);
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
            setepochtag(ndi_epochparams_obj, number, currenttag, epochfiles);
        end % removeepochtag()

    end % methods

end % classdef

