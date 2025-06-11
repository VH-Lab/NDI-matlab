function [b,errmsg] = mfdaq_compare(daq1,daq2)
    % MFDAQ_COMPARE - compare data from two ndi.daq.system.mfdaq objects
    %
    % [B,ERRMSG] = MFDAQ_COMPARE(DAQ1, DAQ2)
    %
    % Compare output from two MFDAQ objects. DAQ1 is a non-ingested daq system
    % and DAQ2 should be an ingested daq system.
    %

    b = 0;

    errmsg = {};

    S1 = session(daq1);
    S2 = session(daq2);
    S1.cache.clear();
    S2.cache.clear();

    fn1 = daq1.filenavigator;
    et1 = daq1.epochtable();
    dr1 = daq1.daqreader();

    fn2 = daq2.filenavigator;
    et2 = daq2.epochtable();
    dr2 = daq2.daqreader();

    continuous_types = {'analog_in','analog_out','auxiliary_in',...
        'digital_in','digital_out','time'};
    event_types = {'event','marker','text'};

    for i=1:numel(et1)
        number = sscanf(et1(i).epoch_id,'t%d')
        if number<63, continue; end
        disp(['Testing epoch ' et1(i).epoch_id '...']);
        f1 = fn1.getepochfiles(et1(i).epoch_id);
        f2 = fn2.getepochfiles(et1(i).epoch_id);
        c1 = dr1.getchannelsepoch(f1);
        c2 = dr2.getchannelsepoch_ingested(f2,S2);
        [dummy,sortorder1] = sort({c1.name});
        [dummy,sortorder2] = sort({c2.name});
        c1 = c1(sortorder1);
        c2 = c2(sortorder2);
        if ~isequaln(c1,c2)
            errmsg{end+1} = ['Channel list in ' et1(i).epoch_id ' do not match.'];
            return;
        end

        % now try common channel types in turn

        for j=1:numel(continuous_types)
            disp(['Examining ' continuous_types{j} '.']);
            channels_entries = find(strcmp(continuous_types{j},{c1.type}));
            if ~isempty(channels_entries)
                channels_here = [];
                for k=1:numel(channels_entries)
                    [dummy,channels_here(k)] = ndi.fun.channelname2prefixnumber(c1(channels_entries(k)).name);
                end
                t_start = et1(i).t0_t1{1}(1) + rand * diff(et1(i).t0_t1{1});
                t_stop = min(t_start + 300,et1(i).t0_t1{1}(2));
                D1 = daq1.readchannels(continuous_types{j},channels_here,et1(i).epoch_id,t_start,t_stop);
                D2 = daq2.readchannels(continuous_types{j},channels_here,et1(i).epoch_id,t_start,t_stop);
                if ~strcmp(continuous_types{j},'time')
                    if ~isequaln(D1,D2)
                        errmsg{end+1} = ['Reading ' continuous_types{j} ' produced unequal results.'];
                        keyboard
                    end
                else
                    disp('checking time values')
                    passing = 1;
                    if ~isequal(size(D1),size(D2))
                        passing = 0;
                    else
                        mx = max(abs(D1(:)-D2(:)));
                        if mx>1e-6
                            passing = 0;
                        else, disp(['Time matches close enough.']);
                        end
                    end
                    if ~passing
                        errmsg{end+1} = ['Reading ' continuous_types{j} ' produced unequal results.'];
                    end
                end
            end
        end

        % non-continuous

        for j=1:numel(event_types)
            disp(['Examining ' event_types{j} '.']);
            channels_entries = find(strcmp(event_types{j},{c1.type}));
            if ~isempty(channels_entries)
                channels_here = [];
                for k=1:numel(channels_entries)
                    [dummy,channels_here(k)] = ndi.fun.channelname2prefixnumber(c1(channels_entries(k)).name);
                end
                t_start = et1(i).t0_t1{1}(1) + rand * diff(et1(i).t0_t1{1});
                t_stop = min(t_start + 300,et1(i).t0_t1{1}(2));
                [T1,D1] = daq1.readevents(event_types{j},channels_here,et1(i).epoch_id,t_start,t_stop);
                [T2,D2] = daq2.readevents(event_types{j},channels_here,et1(i).epoch_id,t_start,t_stop);
                if iscell(T1)
                    for TT=1:numel(T1)
                        if isempty(T1{TT})
                            T1{TT} = zeros(0,1);
                        end
                    end
                end
                if ~isequaln(T1,T2)
                    errmsg{end+1} = ['Reading ' event_types{j} ' produced unequal results in time.'];
                    keyboard

                end
                if iscell(D1)
                    for TT=1:numel(D1)
                        if isempty(D1{TT})
                            D1{TT} = zeros(0,1);
                        end
                    end
                else
                    if isempty(D1),D1=zeros(0,1);end
                end
                if isempty(D2) & isempty(D1), D2 = D1; end
                if ~isequaln(D1,D2)
                    errmsg{end+1} = ['Reading ' event_types{j} ' produced unequal results in codes/text.'];
                    keyboard

                end
            end
        end
    end

    b = 1;

    for i=1:numel(errmsg)
        if ~isempty(errmsg{i})
            b = 0;
        end
    end
