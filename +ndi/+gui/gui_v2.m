function ndi_gui_v2(ndi_session_obj)
    scr_siz = get(0,'ScreenSize') ;
    scissor = rand(32);
    scissor(1:32,1:32) = NaN;
    scissor([74 87 105:106 119:120 136:139 150:153 168:171 182:185 ...
        200:204 213:217 232:236 245:249 264:269 276:281 296:301 ...
        308:313 328:334 339:345 361:366 371:376 394:399 402:407 ...
        427:431 434:438 460:469 493:500 526:531 559:562 591 ...
        594 623 626 655 658 687 690 714:717 719 722 724:727 ...
        745 750:751 754:755 760 776 783 786 793 808 815 818 ...
        825 840 847 850 857 872 879 882 889 905 910 915 920 ...
        938:941 948:951]) = 1;
    scissor([592:593 624:625 656:657 688:689 720:721 746:749 752:753 ...
        756:759 777:782 784:785 787:792 809:814 816:817 819:824 ...
        841:846 848:849 851:856 873:878 880:881 883:888 906:909 ...
        911:914 916:919]) = 2;

    figure('position', floor([scr_siz(3)/2 scr_siz(4)/2 scr_siz(3)/2 scr_siz(4)/2]), 'resize', 'on', ...
        'Units','normalized', ...
        'color', [0.8 0.8 0.8], 'WindowButtonUpFcn', @mouseRelease, ...
        'PointerShapeCData', scissor, 'PointerShapeHotSpot', [14 6], ...
        'defaultFigureColor', [0.8 0.8 0.8]);

    % Create top bar
    top = axes('position', [0 5/6 1 1/6]);
    axis off;
    hold on;
    lTab = rectangle(top, 'position', [0 0 1/2 1/2], 'facecolor', [0.8 0.8 0.8], ...
        'EdgeColor', 'None', 'ButtonDownFcn', @displayLab);
    dTab = rectangle(top, 'position', [1/2 0 1/2 1/2], 'facecolor', [0.7 0.7 0.7], ...
        'ButtonDownFcn', @displayData);
    rectangle(top, 'position', [0 1/2 1 1/2], 'facecolor', [0.7 0.7 0.7], ...
        'Tag', 'Title');
    text(top, 1/2, 3/4, 'Neuroscience Data Interface', ...
        'HorizontalAlignment', 'center');
    text(top, 1/4, 1/4, 'Experiment View', 'HorizontalAlignment', 'center', ...
        'ButtonDownFcn', @displayLab);
    text(top, 3/4, 1/4, 'Database View', 'HorizontalAlignment', 'center', ...
        'ButtonDownFcn', @displayData);

    % Create info
    data = ndi.gui.Data();

    % Create lab
    lab = ndi.gui.Lab();
    set(gcf, 'WindowButtonMotionFcn', @lab.move);

    % Import ndi_session_obj
    e = ndi_session_obj.getelements();
    docs = ndi_session_obj.database_search({'base.id','(.*)'});
    d = ndi_session_obj.daqsystem_load('name','(.*)');
    p = ndi_session_obj.getprobes();
    s_id = {};
    for i = 1:numel(p)
        s_id{i} = p{i}.subject_id;
    end
    for i = 1:numel(e)
        s_id{end+1} = e{i}.subject_id;
    end
    s_id = unique(s_id);
    s = {};
    for i = 1:numel(s_id)
        s{i} = ndi_session_obj.database_search(ndi.query('base.id','exact_string',s_id{i},''));
    end

    % Add elements
    lab.addSubject(s);

    lab.addProbe(p);

    lab.addDAQ(d);

    % Add documents
    data.addDoc(docs);

    % Connect elements
    for i = 1:numel(p)
        ps_id = p{i}.subject_id;
        ps = p{i}.session.database_search(ndi.query('base.id','exact_string',ps_id,''));
        lab.connect(findobj(lab.subjects, 'elem', ps));
        lab.connect(findobj(lab.probes, 'elem', p{i}));
        et = p{i}.epochtable();
        epochids = {et.epoch_id};
        daqnames = {};
        channel_types = {};
        channels = {};
        for k = 1:numel(et)
            [DEV, DEVNAME, ~, CHANNELTYPE, CHANNELLIST] = getchanneldevinfo(p{i}, et(i).epoch_id);
            daqnames{k} = DEVNAME;
            channel_types{k} = CHANNELTYPE;
            channels{k} = CHANNELLIST;
        end
        lab.connect(findobj(lab.probes, 'elem', p{i}));
        lab.connect(findobj(lab.DAQs, 'elem', DEV{1}));
    end

    function displayData(~, ~)
        set(lab.window, 'Visible', 'off');
        set(lab.panel, 'Visible', 'off');
        set(data.table, 'Visible', 'on');
        set(data.panel, 'Visible', 'on');
        set(data.search, 'Visible', 'on');
        set(lTab, 'facecolor', [0.7 0.7 0.7], ...
            'EdgeColor', [0 0 0]);
        set(dTab, 'facecolor', [0.8 0.8 0.8], ...
            'EdgeColor', 'None');
    end

    function displayLab(~, ~)
        set(lab.window, 'Visible', 'on');
        set(lab.panel, 'Visible', 'on');
        axis(lab.window, 'off');
        set(data.table, 'Visible', 'off');
        set(data.panel, 'Visible', 'off');
        set(data.search, 'Visible', 'off');
        lab.grid();
        lab.buttons();
        set(dTab, 'facecolor', [0.7 0.7 0.7], ...
            'EdgeColor', [0 0 0]);
        set(lTab, 'facecolor', [0.8 0.8 0.8], ...
            'EdgeColor', 'None');
    end

    function mouseRelease(~, ~)
        if ~lab.moved && ~isempty(lab.drag)
            lab.details(lab.drag);
        end
        set(gcf, 'Pointer', 'arrow');
        lab.moved = false;
        lab.drag = [];
    end
end
