function ndi_gui(varargin)
% NDI_GUI - A gui to display the contents of an NDI_EXPERIMENT
%
%  NDI_GUI(NDI_EXPERIMENT_OBJ)
%
%  Brings up a graphical user interface to view the NDI_EXPERIMENT
%  NDI_EXPERIMENT_OBJ
%
%  See also: NDI_EXPERIMENT


if nargin==1,
    ndi_experiment_obj = varargin{1};
end;

 % internal variables, for the function only

command = 'Main';    % internal variable, the command
fig = '';                 % the figure
success = 0;
windowheight = 380;
windowwidth = 450;
windowrowheight = 35;

 % user-specified variables
ds = [];               % dirstruct
windowlabel = 'VHINTAN Spike sorting';

spikesortingprefs = struct('sigma',4,'pretime',20,'usemedian',0,'MEDIAN_FILTER_ACROSS_CHANNELS',0,'SAMPLES',[-10 25],'REFRACTORY_PERIOD_SAMPLES',15);

spikesortingprefs_help = {'Number of standard deviations away to set automatic threshold (default 4)',...
			'Number of seconds of data to examine to determine threshold (default 20)',...
			'0/1 Should we use the median method to determine standard deviation, or standard method? (default 0)',...
			'0/1 Should we perform a median filter across all channels? (default 0)' ...
			'What range of samples should we examine around each threshold crossing? (eg, [-10 25] is 10 before threshold until 25 after)',...
			'What is threshold crossing refractory period in samples? (default 15)' ...
};


varlist = {'ndi_experiment_obj','windowheight','windowwidth','windowrowheight','windowlabel','spikesortingprefs','spikesortingprefs_help'};

assign(varargin{:});

if isempty(fig),
	z = findobj(allchild(0),'flat','tag','ndi_gui');
	if isempty(z),
		fig = figure('name','NDI_GUI','NumberTitle','off'); % we need to make a new figure
	else,
		fig = z;
		figure(fig); % makes the figure specified by fig the current figure and displays it on top of all other figures.
		ndi_gui('fig',fig,'command','UpdateDBList');
		return; % just pop up the existing window after updating
	end;
end;

 % initialize userdata field
if strcmp(command,'Main'),
	for i=1:length(varlist),
		eval(['ud.' varlist{i} '=' varlist{i} ';']);
	end;
else,
	ud = get(fig,'userdata');
end;

%command,

switch command,
	case 'Main',
		set(fig,'userdata',ud);
		ndi_gui('command','NewWindow','fig',fig);
		ndi_gui('fig',fig,'command','UpdateDBList');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% what do these inputs specify? ---the internal variables for the function ndi_gui?
	case 'NewWindow',
		% control object defaults

		% this callback was a nasty puzzle in quotations:
		callbackstr = [  'eval([    get(gcbf,''Tag'') ''  (''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);  ''       ]);']; 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Questions:
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Is evaluating  the above
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% callbackstring the same as executing the following line?
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ndi_gui('command','some_command','fig',fig);
		button.Units = 'pixels';
                button.BackgroundColor = [0.8 0.8 0.8];
                button.HorizontalAlignment = 'center';
                button.Callback = callbackstr;
                txt.Units = 'pixels'; txt.BackgroundColor = [0.8 0.8 0.8];
                txt.fontsize = 12; txt.fontweight = 'normal';
                txt.HorizontalAlignment = 'left';txt.Style='text';
                edit = txt; edit.BackgroundColor = [ 1 1 1]; edit.Style = 'Edit';
                popup = txt; popup.style = 'popupmenu';
                popup.Callback = callbackstr;
		list = txt; list.style = 'list';
		list.Callback = callbackstr;
                cb = txt; cb.Style = 'Checkbox';
                cb.Callback = callbackstr;
                cb.fontsize = 12;

		right = ud.windowwidth;
		top = ud.windowheight;
		row = ud.windowrowheight;

        set(fig,'position',[50 50 right top],'tag','ndi_gui');
		uicontrol(txt,'position',[5 top-row*1 600 30],'string',ud.windowlabel,'horizontalalignment','left','fontweight','bold'); % 1st line: window label
		uicontrol(txt,'position',[5 top-row*2 600 30],'string',getpath(ud.ndi_experiment_obj));  % 2nd line: path of experiment dir
		uicontrol(button,'position',[5 top-row*3 200 30],'string','Auto threshold','tag','AutoThresholdsBt'); % 3rd line: why do 'string' and 'tag' have different values?
		uicontrol(button,'position',[5 top-row*4 200 30],'string','Set/Edit thresholds/extract','tag','ThresholdsBt'); % 4th line: 
        
		uicontrol(list,'position',[5+210 top-row*3-200+row 200 200],'string',{' ', ' '},'Max',2, 'value',[],'tag','DBList');
        
		uicontrol(button,'position',[5 top-row*5 200 30],'string','Choose directories to extract','tag','ExtractSelectBt');
        
		uicontrol(button,'position',[5 top-row*6 200 30],'string','Cluster','tag','ClusterBt');
		uicontrol(button,'position',[5 top-row*7 200 30],'string','Update','tag','UpdateBt'); % move the update button to 
		uicontrol(button,'position',[5 top-row*9 200 30],'string','Import extracted cells','tag','ImportBt');
        
		uicontrol(button,'position',[5 top-row*10 200 30],'string','Preferences','tag','PreferencesBt');
		set(fig,'userdata',ud);
	case 'UpdateBt',  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% what is Bt?
		ndi_gui('fig',fig,'command','UpdateDBList');
	case 'ImportBt',
		vhintan_importcells(ud.ds); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ds---directory struct?
	case 'ClusterBt',
		v = get(findobj(fig,'tag','DBList'),'value'); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% what arrays of values is it getting? 
		for i=1:length(v),
			vhintan_clusternameref(ud.ds,ud.nr(v(i)).name,ud.nr(v(i)).ref);
		end;
        
	case 'DBList',
        disp(['here at DBList']);
        ref_list = get(findobj(fig,'tag','DBList'),'userdata') %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% what is the object to be found? The graphics object of DBList/an ui-control?
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% what is stored in the field of 'userdata'
        value = get(findobj(fig,'tag','DBList'),'value'); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% what is stored in the field of 'value'
        if ~isempty(value),
            mydoc = ud.ndi_experiment_obj.database_search({'ndi_document.document_unique_reference',ref_list{value}});
            mydoc,
        end;
    	ndi_gui('fig',fig,'command','EnableDisable');
            
	case 'UpdateDBList',
        doc_list = ud.ndi_experiment_obj.database_search({'document_class.class_name','(.*)'});
        name_list = {};
        doc_ref = {};
        for i=1:numel(doc_list),
            name_list{i} = [doc_list{i}.document_properties.document_class.class_name ' | ' doc_list{i}.document_properties.ndi_document.name];
            doc_ref{i} = [doc_list{i}.document_properties.ndi_document.document_unique_reference];
        end;
		set(findobj(fig,'tag','DBList'),'string',name_list,'value',[],'userdata',doc_ref);
		ndi_gui('fig',fig,'command','EnableDisable');
	case 'ThresholdsBt',
        a = 5
        
	case 'EnableDisable',
		v = get(findobj(fig,'tag','DBList'),'value');
		if isempty(v),
			set(findobj(fig,'tag','ClusterBt'),'enable','off');
		else,
			set(findobj(fig,'tag','ClusterBt'),'enable','on');
		end;

end;
