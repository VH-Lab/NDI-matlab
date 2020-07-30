function ndi_gui_v2()
    % Create figure
    
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
            
    figure('name', 'NDI GUI', 'position', [100, 100, 640, 480], ...
           'color', [0.8 0.8 0.8], 'WindowButtonUpFcn', @mouseRelease, ...
           'PointerShapeCData', scissor, 'PointerShapeHotSpot', [14 6]);
       
    %Create top bar
    top = axes('position', [0 5/6 1 1/6]);
    axis off;
    hold on;
    rectangle(top, 'position', [0 0 1/2 1/2], 'facecolor', [0.8 0.8 0.8], ...
              'EdgeColor', 'None', 'ButtonDownFcn', @displayLab, ...
              'Tag', 'LabTab');
    rectangle(top, 'position', [1/2 0 1/2 1/2], 'facecolor', [0.7 0.7 0.7], ...
              'ButtonDownFcn', @displayData, 'Tag', 'DataTab');
    rectangle(top, 'position', [0 1/2 1 1/2], 'facecolor', [0.7 0.7 0.7], ...
              'Tag', 'Title');
    text(top, 1/2, 3/4, 'Neuroscience Data Interface', ...
         'HorizontalAlignment', 'center');
    text(top, 1/4, 1/4, 'Experiment View', 'HorizontalAlignment', 'center', ...
         'ButtonDownFcn', @displayLab);
    text(top, 3/4, 1/4, 'Database View', 'HorizontalAlignment', 'center', ...
         'ButtonDownFcn', @displayData);
    
    %Create info
    data = Data();
    
    %Create lab
    lab = Lab();
    set(gcf, 'WindowButtonMotionFcn', @lab.move);

    
    %Add subject
    lab.addSubject({'mouse.jfif'});
    
    lab.addProbe({'microscope.png' 'tv.png'});
    
    lab.addDAQ({'gears.png'});
    
    %Add documents
    data.addDoc({'file.txt'});
    
    function displayData(~, ~)
        labCh = get(lab.window, 'children');
        labInfoCh = get(lab.info, 'children');
        dataCh = get(data.window, 'children');
        dataInfoCh = get(data.info, 'children');
        for i=1:numel(labCh)
            set(labCh(i), 'Visible', 'off');
        end
        for i = 1:numel(labInfoCh)
            set(labInfoCh(i), 'Visible', 'off');
        end
        for i=1:numel(dataCh)
            set(dataCh(i), 'Visible', 'on');
        end
        for i = 1:numel(dataInfoCh)
            set(dataInfoCh(i), 'Visible', 'on');
        end
        set(findobj(top, 'Tag', 'LabTab'), 'facecolor', [0.7 0.7 0.7], ...
            'EdgeColor', [0 0 0]);
        set(findobj(top, 'Tag', 'DataTab'), 'facecolor', [0.8 0.8 0.8], ...
            'EdgeColor', 'None');
    end
    
    function displayLab(~, ~)
        labCh = get(lab.window, 'children');
        labInfoCh = get(lab.info, 'children');
        dataCh = get(data.window, 'children');
        dataInfoCh = get(data.info, 'children');
        for i=1:numel(labCh)
            set(labCh(i), 'Visible', 'on');
        end
        for i=1:numel(labInfoCh)
            set(labInfoCh(i), 'Visible', 'on');
        end
        for i=1:numel(dataCh)
            set(dataCh(i), 'Visible', 'off');
        end
        for i=1:numel(dataInfoCh)
            set(dataInfoCh(i), 'Visible', 'off');
        end
        lab.grid();
        set(findobj(top, 'Tag', 'DataTab'), 'facecolor', [0.7 0.7 0.7], ...
            'EdgeColor', [0 0 0]);
        set(findobj(top, 'Tag', 'LabTab'), 'facecolor', [0.8 0.8 0.8], ...
            'EdgeColor', 'None');
    end
    
    function mouseRelease(~, ~)
        if ~lab.moved && ~isempty(lab.drag)
            lab.details(get(lab.drag.img, 'CData'));
        end
        set(gcf, 'Pointer', 'arrow');
        lab.moved = false;
        lab.drag = [];
    end
end