function tutorial_02_02(prefix, testing)
    % ndi.example.tutorial.tutorial_02_02 - runs the code in Tutorial 2.2
    %
    % out = ndi.example.tutorial.tutorial_02_02(PREFIX, [TESTING])
    %
    % Runs (and tests) the code for
    %
    % NDI Tutorial 2: Analyzing your first electrophysiology experiment with NDI
    %    Tutorial 2.2: The automated way
    % The tutorial is available at
    %     https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/2_theautomatedway
    %
    % PREFIX should be the directory that contains the directory 'ts_exper2'. If it is not
    % provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
    %
    % If TESTING is 1, then the files are copied to the temporary directory before proceeding so that the files
    % in the directory called PREFIX are not touched.
    %

    if nargin<1 | isempty(prefix)
        prefix = [userpath filesep 'Documents' filesep 'NDI']; % or '/Users/yourusername/Desktop/' if you put it on the desktop perhaps
    end;

    if nargin<2
        testing = 0;
    end;

    tutorial_dir = 'ts_exper2';

    if testing % copy the files to the temp directory
        prefix = [userpath filesep 'Documents' filesep 'NDI' filesep 'Test'];
        disp(['Assuming clean data files ts_exper2 are in ' prefix '.']);

        disp(['Clearing any ''' tutorial_dir  ''' in the temporary directory']);
        try
            rmdir([ndi.common.PathConstants.TempFolder filesep tutorial_dir],'s');
        end;
        disp(['Copying ''' tutorial_dir ''' to the temporary directory']);
        copyfile([prefix filesep tutorial_dir], [ndi.common.PathConstants.TempFolder filesep tutorial_dir]);

        prefix = ndi.common.PathConstants.TempFolder;
    end

    % Code block 2.2.7.1

    disp(['Code block 2.2.7.1:']);
    % prefix line is set above
    S = ndi.setup.vhlab('ts_exper2',[prefix filesep 'ts_exper2']);

    p_ctx1_list = S.getprobes('name','ctx','reference',1) % returns a cell array of matches
    p_ctx1 = p_ctx1_list{1}; % take the first one, should be the only one

    epoch_to_read = 1;
    [data,t,timeref_p_ctx1]=p_ctx1.readtimeseries(epoch_to_read,-Inf,Inf); % read all data from epoch 1
    figure(100);
    plot(t,data);
    xlabel('Time(s)');
    ylabel('Voltage (V)');
    set(gca,'xlim',[t(1) t(end)]);
    box off;

    p_visstim_list = S.getprobes('type','stimulator') % returns a cell array of matches
    p_visstim = p_visstim_list{1}; % take the first one, should be the only one
    [data,t,timeref_stim]=p_visstim.readtimeseries(timeref_p_ctx1,-Inf,Inf); % read all data from epoch 1 of p_ctx1 !
    figure(100);
    hold on;
    vlt.neuro.stimulus.plot_stimulus_timeseries(7,t.stimon,t.stimoff,'stimid',data.stimid);
