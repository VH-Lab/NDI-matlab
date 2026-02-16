classdef epochprobemap_daqsystem_vhlab < ndi.epoch.epochprobemap_daqsystem
    properties
    end % properties
    methods
        function obj = epochprobemap_daqsystem_vhlab(name_, reference_, type_, devicestring_, subjectstring_)
            % ndi.setup.epoch.epochprobemap_daqsystem_vhlab - Create a new ndi.epoch.epochprobemap_daqsystem object derived from the vhlab device implementation
            %
            % MYNDI_EPOCHPROBEMAP_DAQSYSTEM = NDI.SETUP.EPOCH.EPOCHPROBEMAP_DAQSYSTEM_VHLAB(NAME, REFERENCE, TYPE, DEVICESTRING, SUBJECTSTRING)
            %
            % Creates a new ndi.setup.epoch.epochprobemap_daqsystem_vhlab with name NAME, reference REFERENCE, type TYPE,
            % and devicestring DEVICESTRING.
            %
            % NAME can be any string that begins with a letter and contains no whitespace. It
            % is CASE SENSITIVE.
            % REFERENCE must be a non-negative scalar integer.
            % TYPE is the type of recording.
            % DEVICESTRING is a string that indicates the channels that were used to acquire
            % this record.
            %
            %   MYNDI_EPOCHPROBEMAP_DAQSYSTEM = NDI_EPOCHPROBEMAP_VHLAB(FILENAME)
            %
            % Here, FILENAME is assumed to be a (full path) tab-delimitted text file in the style of
            % 'vhintan_channelgrouping.txt' (see HELP VHINTAN_CHANNELGROUPING)
            % that has entries 'name<tab>ref<tab>channel_list<tab>'.
            %
            % The device type of each channel is assumed to be 'n-trode', where n is
            % set to be the number of channels in the channel_list for each name/ref pair.
            %
            % The NDI device name for this device must be 'vhintan' (VH Intan RHD device), 'vhlv' (VH Lab Labview custom
            % acquisition code), 'vhspike2', or 'vhwillow'. The device name will be taken from the filename,
            % following [VHDEVICENAME '_channelgrouping.txt']
            %

            is_struct = 0;

            if nargin==0
                name_ = 'a';
            end
            if nargin==1
                filename = name_;
                name_ = 'a';
                if numel(find(filename==sprintf('\n'))) > 0
                    is_struct = 1;
                    ndi_struct = ndi.epoch.epochprobemap.decode(filename);
                end
            end
            if nargin<4
                reference_ = 0;
                type_ = 'a';
                devicestring_ = 'a';
                subjectstring_ = '';
            end

            obj = obj@ndi.epoch.epochprobemap_daqsystem(name_, reference_, type_, devicestring_, subjectstring_);

            if is_struct
                for i=1:numel(ndi_struct)
                    obj(i)=ndi.setup.epoch.epochprobemap_daqsystem_vhlab(...
                        ndi_struct(i).name,ndi_struct(i).reference,ndi_struct(i).type,ndi_struct(i).devicestring,ndi_struct(i).subjectstring);
                end
                return;
            end

            if nargin==1
                [filepath, localfile, ext] = fileparts(filename);

                [parentpath, localdirname] = fileparts(filepath);
                if endsWith([localfile ext], '_stimulus_triggers_log.tsv')
                   parentpath = fileparts(parentpath);
                end
                subjectfile = [parentpath filesep 'subject.txt'];
                if vlt.file.isfile(subjectfile)
                    subjecttext = vlt.file.textfile2char(subjectfile);
                    subject_id = vlt.string.trimws(vlt.string.line_n(subjecttext,1));
                else
                    error(['No subject.txt file found:' subjectfile '.']);
                end

                [b,msg] = ndi.subject.isvalidlocalidentifierstring(subject_id);
                if ~b
                    error(['subject_id string ' subject_id ' is not a valid subject id: ' msg]);
                end

                if strcmp([localfile ext],'stimtimes.txt') % vhvis_spike2
                    mylist = {'mk1','mk2','mk3','e1','e2','e3','md1'};
                    for i=1:numel(mylist)
                        nextentry = ndi.setup.epoch.epochprobemap_daqsystem_vhlab('vhvis_spike2',...
                            1,...
                            ['stimulator'  ] , ...  % type
                            ['vhvis_spike2' ':' mylist{i}], ...  % device string
                            subject_id);
                        obj(i) = nextentry;
                    end
                    return;
                end

                trigger_suffix = '_stimulus_triggers_log.tsv';
                if endsWith([localfile ext], trigger_suffix)
                    devicename = [localfile ext];
                    devicename = devicename(1:end-length(trigger_suffix));

                    mylist = {'mk1','e1','e2','md1'};
                    for i=1:numel(mylist)
                        nextentry = ndi.setup.epoch.epochprobemap_daqsystem_vhlab(devicename,...
                            1,...
                            'stimulator', ...  % type
                            [devicename ':' mylist{i}], ...  % device string
                            subject_id);
                        obj(i) = nextentry;
                    end
                    return;
                end

                if ~contains([localfile],'channelgrouping')
                    error(['Expected file ' [localfile ] ' to include the string channelgrouping. Maybe unintended files in epoch?']);
                end

                vhdevice_string = regexp(lower([localfile ext]),'(\w*)_channelgrouping.txt','tokens');
                if isempty(vhdevice_string)
                    error(['File name not of expected form VHDEVICENAME_channelgrouping.txt']);
                end
                vhdevice_string = vhdevice_string{1}{1};
                valid_vhdevice_strings = {'vhspike2','vhintan','vhlv','vhwillow'};
                vhdevice_string = intersect(vhdevice_string, valid_vhdevice_strings);
                if isempty(vhdevice_string)
                    error(['VHDEVICENAME must be one of ' strjoin(valid_vhdevice_strings,', ') ]);
                end
                vhdevice_string = vhdevice_string{1};

                ndi_struct = vlt.file.loadStructArray(filename);
                fn = fieldnames(ndi_struct);
                if ~vlt.data.eqlen(fn,{'name','ref','channel_list'}')
                    fn,
                    error(['fields must be (case-sensitive match): name, ref, channel_list. See HELP VHINTAN_CHANNELGROUPING.']);
                end

                % now pull reference.txt file to determine type
                [myfilepath,myfilename] = fileparts(filename);
                ref_struct = vlt.file.loadStructArray([myfilepath filesep 'reference.txt']);

                for i=1:length(ndi_struct)
                    tf_name = strcmp(ndi_struct(i).name,{ref_struct.name});
                    tf_ref = [ndi_struct(i).ref == [ref_struct.ref]];
                    index = intersect(tf_name,tf_ref);
                    if numel(index)~=1
                        disp(['Error: Looking for name ' ndi_struct(i).name ' and ref ' int2str(ndi_struct(i).ref) '.']);
                        disp(['Ref struct is '])
                        ref_struct,
                        disp(['Looking in filename ' filename]);
                        error(['Cannot find exclusive match for name/ref in reference.txt file.']);
                    end
                    ec_type = ref_struct(index).type;
                    probeTypeMap = ndi.probe.fun.getProbeTypeMap();
                    if ~isKey(probeTypeMap, ec_type)
                        % examine vhlab table
                        if strcmpi(ec_type,'singleEC') | strcmpi(ec_type,'ntrode')
                            ec_type = 'n-trode';
                        else
                            error(['Unknown type ' ec_type '.']);

                        end
                    end
                    nextentry = ndi.setup.epoch.epochprobemap_daqsystem_vhlab(ndi_struct(i).name,...
                        ndi_struct(i).ref,...
                        ec_type, ...  % type
                        [vhdevice_string ':ai' vlt.string.intseq2str(ndi_struct(i).channel_list)], ...  % device string
                        subject_id);
                    obj(i) = nextentry;
                end
            end

        end

        function savetofile(obj, filename)
            %  SAVETOFILE - Write ndi.epoch.epochprobemap_daqsystem object array to disk
            %
            %    SAVETOFILE(OBJ, FILENAME)
            %
            %  Writes the ndi.epoch.epochprobemap_daqsystem_vhlab object to disk in filename FILENAME (full path).
            %
            %
            error(['Sorry, I only know how to read these files, I don''t write (yet? ever?).']);
        end
    end  % methods
end
