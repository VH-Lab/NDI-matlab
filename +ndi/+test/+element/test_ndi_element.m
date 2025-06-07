function test_ndi_element(dirname)
    % TEST_NDI_ELEMENT - Test the functionality of the NDI_ELEMENT object and the NDI_SESSION database
    %
    %  ndi.test.element([DIRNAME])
    %
    %  Given a directory, this function tries to create some
    %  NDI_VARIABLE objects in the session DATABASE. The test function
    %  removes them on completion.
    %
    %  If DIRNAME is not provided, the default directory
    %  [NDIEXAMPLEEXPERPATH/exp1_eg_saved] is used.
    %
    %

    test_struct = 0;

    if nargin<1
        dirname = [ndi.common.PathConstants.ExampleDataFolder filesep 'exp1_eg_saved'];
    end

    disp(['Creating a new session object in directory ' dirname '.']);
    E = ndi.session.dir('exp1',dirname);

    % if we ran the demo before, delete the entry

    doc = E.database_search(ndi.query('','isa','element',''));
    if ~isempty(doc)
        for i=1:numel(doc)
            E.database_rm(doc{i}.id());
        end
    end

    p = E.getprobes(); % should return 1 probe
    if numel(p)==0 % ndi.test.daq.build_intan_flat_exp hasn't been run yet
        disp(['Need to run ndi.test.daq.build_intan_flat_exp first, doing that now...']);
        ndi.test.daq.build_intan_flat_exp(dirname);
        p = E.getprobes(); % should return 1 probe
    end

    [d,t] = readtimeseries(p{1}, 1, -Inf, Inf);
    % low-pass filter
    [b,a]=cheby1(4,0.8,[300]/(0.5*1/median(diff(t))),'low');
    d_filter = filtfilt(b,a,d);

    myelement1 = ndi.element.timeseries(E,'mydirectelement',p{1}.reference,'field', p{1}, 1, 'anteater27@nosuchlab.org');

    et = p{1}.epochtable;
    % FIX here
    myelement2 = ndi.element.timeseries(E,'myindirectelement',p{1}.reference,'lfp', p{1}, 0, 'anteater27@nosuchlab.org');
    [myelement2]=myelement2.addepoch(et(1).epoch_id,et(1).epoch_clock{1},et(1).t0_t1{1},t,d_filter);

    % demo adding a element that does not depend on an antecedent element at all
    myelement3 = ndi.element.timeseries(E,'mymadeupelement',1,'madeup', [], 0,'anteater27@nosuchlab.org');
    [myelement3] = myelement3.addepoch('epoch1',ndi.time.clocktype('dev_local_time'),[0 10],[0:10]',[0:10]');

    et_t1 = myelement1.epochtable();
    et_t2 = myelement2.epochtable();
    et_t3 = myelement3.epochtable();

    element1 = E.getelements('element.name','mydirectelement');
    element2 = E.getelements('element.name','myindirectelement');
    element3 = E.getelements('element.name','mymadeupelement');

    [d1,t1] = readtimeseries(element1{1},1,-Inf,Inf);
    [d2,t2] = readtimeseries(element2{1},1,-Inf,Inf); % filtered data

    figure
    plot(t1,d1);
    hold on
    plot(t2,d2,'g');
    xlabel('Time (s)');
    ylabel('Voltage (V)');
    title(['Raw data is blue, filtered is green']);
    box off;

    [d3,t3] = readtimeseries(element3{1},1,-Inf,Inf),

    % remove the element documents

    doc = E.database_search(ndi.query('','isa','element',''));
    if ~isempty(doc)
        for i=1:numel(doc)
            E.database_rm(doc{i}.id());
        end
    end
