function E = angeluccilab(ref, dirname)
    % ndi.test.setup.angeluccilab - test reading from Angelucci lab data
    %
    % E = ndi.test.setup.angeluccilab(REF, DIRNAME)
    %
    % Open a directory from test data provided by Angelucci lab
    %
    % Example:
    %   E = ndi.test.setup.angeluccilab('2017-09-11','/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Angelucci/2017-09-11');
    %
    %

    if nargin==0
        disp(['No reference or dirname given, using defaults:']);
        ref = '2017-09-11',
        dirname = '/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Angelucci/2017-09-11'
    end

    E = ndi.setup.angeluccilab(ref, dirname);

    p = E.getprobes('type','n-trode')

    p{1}

    stimprobe = E.getprobes('type','stimulator')
    stimprobe = stimprobe{1};

    t_start = 25;
    t_stop = 50;

    [d,t,timeref] = p{1}.readtimeseries(1,t_start,t_stop); % read first epoch, 100 seconds
    [ds, ts, timeref_]=stimprobe.readtimeseries(timeref,t(1),t(end));

    if 0

        figure;
        vlt.plot.plot_multichan(d,t,400); % plot with 400 units of space between channels
        xlabel('Time(s)');
        ylabel('Microvolts');

        hold on;

        A = axis;

        for i=1:numel(ts.stimon)
            plot(ts.stimon(i)*[1 1], [A(3) -200],'k-');
            text(ts.stimon(i),A(3)-400,int2str(ds.stimid(i)),'horizontalalignment','center');
        end

        A = axis;
        axis([t_start t_stop A(3) A(4)]);
        box off;

    else

        d = d(:,[4 17 21 24 26]);  % hand-picked nice channels

        [b,a] = cheby1(4,0.8,300/(30000*0.5),'high');

        for i=1:size(d,2)
            d(:,i) = filtfilt(b,a,d(:,i));
        end

        figure;
        vlt.plot.plot_multichan(d,t,150); % plot with 100 units of space between channels
        xlabel('Time(s)');
        ylabel('Microvolts');

        hold on;

        A = axis;

        for i=1:numel(ts.stimon)
            plot(ts.stimon(i)*[1 1], [A(3) -100],'k-');
            text(ts.stimon(i),A(3)-100,int2str(ds.stimid(i)),'horizontalalignment','center');
        end

        A = axis;
        axis([t_start t_stop A(3) A(4)]);
        box off;

    end
