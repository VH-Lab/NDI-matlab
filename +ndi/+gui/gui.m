function gui(varargin)
    % GUI - A gui to display the contents of an NDI_SESSION
    %
    %  ndi.gui.gui(NDI_SESSION_OBJ)
    %
    %  Brings up a graphical user interface to view the ndi.session
    %  NDI_SESSION_OBJ
    %
    %  See also: ndi.session


    if nargin==1
        ndi_session_obj = varargin{1};
    end

    % internal variables, for the function only

    command = 'Main';    % internal variable, the command
    fig = '';                 % the figure
    success = 0;

    windowheight = 500;
    windowwidth = 1000;
    windowrowheight = 35;

    % user-specified variables
    ds = [];               % dirstruct
    windowlabel = 'NDI GUI';

    varlist = {'ndi_session_obj','windowheight','windowwidth','windowrowheight','windowlabel'};

    vlt.data.assign(varargin{:});

    command,

    if isempty(fig)
        z = findobj(allchild(0),'flat','tag','ndi.gui.gui');
        if isempty(z)
            fig = figure('name','NDI_GUI','NumberTitle','off'); % we need to make a new figure
        else
            success,
            fig = z;
            figure(fig); % makes the figure specified by fig the current figure and displays it on top of all other figures.
            ndi.gui.gui('fig',fig,'command','UpdateDBList');
            return; % just pop up the existing window after updating
        end
    end

    % initialize userdata field
    if strcmp(command,'Main')
        for i=1:length(varlist)
            eval(['ud.' varlist{i} '=' varlist{i} ';']);
        end
    else
        ud = get(fig,'userdata');
    end

    %command,

    switch command
        case 'Main'
            set(fig,'userdata',ud);
            ndi.gui.gui('fig',fig,'command','NewWindow');
            ndi.gui.gui('fig',fig,'command','UpdateDBList');
            ndi.gui.gui('fig',fig,'command','UpdateDAQList');

        case 'NewWindow'

            % control object defaults

            % this callback was a nasty puzzle in quotations:
            callbackstr = [ 'eval([    get(gcbf,''Tag'') ''  (''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);  ''       ]);'];

            txt.Style='text';
            %                 txt.BackgroundColor = get(gcf,'Color');
            txt.BackgroundColor = [1 1 1];
            txt.fontsize = 12; txt.fontweight = 'normal';
            txt.HorizontalAlignment = 'left';
            txt.Units = 'Normalized';
            edit = txt;
            edit.Style = 'Edit';
            edit.BackgroundColor = [1 1 1];
            edit.Callback = callbackstr;

            button = txt;
            button.Style='pushbutton';
            button.HorizontalAlignment = 'center';
            button.Callback = callbackstr;

            popup = txt;
            popup.style = 'popupmenu';
            popup.Callback = callbackstr;
            list = txt;
            list.style = 'list';
            list.Callback = callbackstr;
            chkbox = txt;
            chkbox.Style = 'Checkbox';
            chkbox.Callback = callbackstr;


            % Initialization of layout
            set(fig,'userdata',ud);
            right = ud.windowwidth;
            top = ud.windowheight;
            row = ud.windowrowheight;

            % Figure/Window layout & Static Texts at top of the ndi.gui.gui Window
            set(fig,'position',[50 50 right top],'tag','ndi.gui.gui','name',['NDI: ' ud.ndi_session_obj.reference],'Visible','off');
            movegui(fig,'center');


            uicontrol(txt,'position',[0.01 0.95 0.95 0.04],'string',ud.windowlabel,'horizontalalignment','left','fontweight','bold','fontsize', 18); % Label
            uicontrol(txt,'position',[0.01 0.95-0.05 0.30 0.04],'string',['Path:' getpath(ud.ndi_session_obj)],'fontsize',13); % Path
            uicontrol(txt,'position',[0.36 0.95-0.05 0.15 0.04],'string',['Reference: ' ud.ndi_session_obj.reference],'fontsize',13); % Reference
            uicontrol(txt,'position',[0.61 0.95-0.05 0.35 0.04],'string',['ID: ' ud.ndi_session_obj.id()],'fontsize',13); % Unique Reference


            % "Update" PushButton
            uicontrol(button,'position',[0.4 0.95-0.05*2 0.1 0.04],'string','Update','tag','UpdateBt');
            %         uicontrol(button,'position',[0.5 0.95-0.05*2 0.1 0.04],'string','View','tag','ViewBt');

            % Probes/Things Section
            uicontrol(txt,'position',[0.03 0.95-0.05*3 0.1 0.04],'string','Probes/Things','horizontalalignment','center','fontweight','bold','fontsize',15);
            uicontrol(list,'position',[0.01 0.95-0.05*9-0.01 0.15 0.3],'string',{' ', ' '},'Max',2, 'value',[],'tag','ProbesList');
            uicontrol(list,'position',[0.01 0.95-0.05*15-0.01 0.15 0.3],'string',{' ', ' '},'Max',2, 'value',[],'tag','ThingsList');
            uicontrol(button,'position',[0.03 0.95-0.05*16 0.05 0.04],'string','View','tag','ViewPTBt');

            % DaqReader Section
            uicontrol(txt,'position',[0.23 0.95-0.05*3 0.1 0.04],'string','DAQ-Readers','horizontalalignment','center','fontweight','bold','fontsize',15);
            uicontrol(list,'position',[0.2 0.95-0.05*9-0.01 0.15 0.3],'string',{' ', ' '},'Max',2, 'value',[],'tag','DAQList');
            uicontrol(button,'position',[0.21 0.95-0.05*10 0.03 0.04],'string','+','tag','AddDAQ');
            uicontrol(button,'position',[0.25 0.95-0.05*10 0.03 0.04],'string','-','tag','DeleDAQ');
            uicontrol(button,'position',[0.3 0.95-0.05*10 0.05 0.04],'string','View','tag','ViewDRBt');

            % Cache Section
            uicontrol(txt,'position',[0.23 0.95-0.05*11 0.1 0.04],'string','Cache','horizontalalignment','center','fontweight','bold','fontsize',15);
            uicontrol(list,'position',[0.2 0.95-0.05*15 0.15 0.2],'string',{' ', ' '},'Max',2, 'value',[],'tag','CacheList');
            uicontrol(button,'position',[0.2 0.95-0.05*16+0.01 0.05 0.04],'string','Delete','tag','DeleCache');
            uicontrol(button,'position',[0.25 0.95-0.05*16+0.01 0.05 0.04],'string','Clear','tag','ClearCache');
            uicontrol(button,'position',[0.3 0.95-0.05*16+0.01 0.05 0.04],'string','View','tag','ViewCacheBt');

            % DATABASE Section
            uicontrol(txt,'position',[0.45 0.95-0.05*3 0.12 0.04],'string','Database','horizontalalignment','center','fontweight','bold','fontsize',15);
            uicontrol(txt,'position',[0.65 0.95-0.05*3 0.30 0.04],'string','Document Properties','horizontalalignment','center','fontweight','bold','fontsize',15);
            uicontrol(list,'position',[0.4 0.95-0.05*15.5 0.2 0.61],'string',{' ', ' '},'Max',2, 'value',[],'tag','DBList');
            uicontrol(txt,'position',[0.65 0.95-0.05*18 0.35 0.71],'string',{' ',' '},'Max',2, 'value',[],'tag','doc_properties');

            fig.Visible = 'on';

        case 'UpdateBt'
            ndi.gui.gui('fig',fig,'command','UpdateDBList');
            ndi.gui.gui('fig',fig,'command','UpdateDAQList');
        case 'ImportBt'
            vhintan_importcells(ud.ds);
        case 'ClusterBt'
            v = get(findobj(fig,'tag','DBList'),'value');
            for i=1:length(v)
                vhintan_clusternameref(ud.ds,ud.nr(v(i)).name,ud.nr(v(i)).ref);
            end

        case 'UpdateDAQList'
            ud.ndi_session_obj,
            daq_list = ud.ndi_session_obj.daqsystem_load;
            names = {};
            unique_names = {};
            for i=1:numel(daq_list)
                %            names{i} = daq_list{i}.name;
                %       unique_names{i} = daq_list{i}.id();
            end

            set(findobj(fig,'tag','DAQList'),'string',names,'value',[],'userdata',unique_names);
            ndi.gui.gui('fig',fig,'command','EnableDisable');



            %      case 'DeleDAQList'
            %         ud.ndi_session_obj,
            %         daq_list = ud.ndi_session_obj.daqsystem_load;
            %         name_list = {};
            %         doc_ref = {};
            %         for i=1:numel(daq_list)
            %             name_list{i} = [doc_list{i}.document_properties.document_class.class_name ' | ' doc_list{i}.document_properties.base.name];
            %             doc_ref{i} = [doc_list{i}.document_properties.base.id];
            %         end
            %         name_list;
            %         set(findobj(fig,'tag','DBList'),'string',name_list,'value',[],'userdata',doc_ref);
            %         ndi.gui.gui('fig',fig,'command','EnableDisable');
            %
            %

        case 'DBList'
            disp(['here at DBList']);
            ref_list = get(findobj(fig,'tag','DBList'),'userdata');
            value = get(findobj(fig,'tag','DBList'),'value');
            if ~isempty(value)
                mydaq = ud.ndi_session_obj.database_search({'base.id',ref_list{value}});
                j_pretty = vlt.data.prettyjson(vlt.data.jsonencodenan(mydaq{1}.document_properties));
                j_pretty = char(j_pretty); %% convert java string to a single-line matlab char vector
                %j_pretty = strsplit(char(j_pretty), char(10)); split further into cell array of char vectors
                set(findobj(fig,'tag','doc_properties'),'string',j_pretty);
            end
            ndi.gui.gui('fig',fig,'command','EnableDisable');

        case 'UpdateDBList'
            ud.ndi_session_obj,
            doc_list = ud.ndi_session_obj.database_search({'document_class.class_name','(.*)'});
            name_list = {};
            doc_ref = {};
            for i=1:numel(doc_list)
                name_list{i} = [doc_list{i}.document_properties.document_class.class_name ' | ' doc_list{i}.document_properties.base.name];
                doc_ref{i} = [doc_list{i}.document_properties.base.id()];
            end
            name_list;
            set(findobj(fig,'tag','DBList'),'string',name_list,'value',[],'userdata',doc_ref);
            ndi.gui.gui('fig',fig,'command','EnableDisable');


        case 'EnableDisable'
            v = get(findobj(fig,'tag','DBList'),'value');
            if isempty(v)
                set(findobj(fig,'tag','ClusterBt'),'enable','off');
            else
                set(findobj(fig,'tag','ClusterBt'),'enable','on');
            end
    end

