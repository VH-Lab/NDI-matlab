function ndi_gui_v2()
    % Create figure
    figure('name', 'NDI GUI', 'position', [200, 200, 640, 480], ...
               'color', [0.8 0.8 0.8], 'WindowButtonUpFcn', @mouseRelease);
    
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
        for i = 1:numel(labInfoCh)
            set(labInfoCh(i), 'Visible', 'on');
        end
        for i=1:numel(dataCh)
            set(dataCh(i), 'Visible', 'off');
        end
        for i = 1:numel(dataInfoCh)
            set(dataInfoCh(i), 'Visible', 'off');
        end
        lab.grid();
        set(findobj(top, 'Tag', 'DataTab'), 'facecolor', [0.7 0.7 0.7], ...
            'EdgeColor', [0 0 0]);
        set(findobj(top, 'Tag', 'LabTab'), 'facecolor', [0.8 0.8 0.8], ...
            'EdgeColor', 'None');
    end
    
    function mouseRelease(~, ~)
        if lab.moved == false & lab.drag ~= 0
            lab.details(get(lab.drag.img, 'CData'));
        end
        lab.moved = false;
        lab.drag = 0;
    end
end