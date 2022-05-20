classdef pipeline
        
	properties (SetAccess=protected,GetAccess=public)
        fast_start = 'ndi.pipeline.pipeline_edit(''command'',''new'',''name'',''newpipe'')';
    end % properties
    
	methods
    end % methods
    
	methods (Static)
        function pipeline_edit(varargin)
			% PIPELINE_EDIT - create and control a GUI to graphically edit a PIPELINE EDITOR instance
			%
			% PIPELINE_EDIT(...)
			%
			% Creates and controls a graphical user interface for creating an instance of
			% an pipeline.editor object.
			% 
			% Usage by the user:
			%
			%   PIPELINE_EDIT('new','newpipe')
			%
			%
                
                command = varargin{2};
                name = varargin{4};
                
                window_params.height = 500;
				window_params.width = 400;
                fig = []; % figure to use

				if strcmpi(command,'new'),
					if isempty(fig),
						fig = figure;
					end;
					command = 'NewWindow';
                else 
                    fig = gcf;
				end;

				if isempty(fig),
					error(['Empty figure, do not know what to work on.']);
				end;
                
				disp(['Command is ' command '.']);
                
				switch (command),
					case 'NewWindow',
                        set(fig,'tag','ndi.pipeline.pipeline_edit');    
                        uid = vlt.ui.basicuitools_defs;
                        
						callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);']; 

						% Step 1: Establish window geometry

						top = window_params.height;
						right = window_params.width;
						row = 25;
						title_height = 25;
						title_width = 200;
						edge = 5;

						doc_width = (right - 2*edge)/3*2;
						doc_height = (window_params.height)/4*3;
						menu_width = right - 2*edge;
						menu_height = title_height;
						button_width = 120;
                        button_height = 25;
						button_y = [400-2*row 400-4.5*row 400-6*row 400-8.5*row 400-10*row 400-11.5*row];
						button_center = right-(right-doc_width)/2;

						% Step 2 now build it
					
						set(fig,'position',[50 50 right top]);
						set(fig,'NumberTitle','off');
						set(fig,'Name',['Editing ' name]);
                            
						% Pipeline selection portion of window
                        pipelineList = getPipelines('+ndi/pipeline_storage');
						x = edge; y = top-row;
                        uicontrol(uid.txt,'position',[x y title_width title_height],'string','Select pipeline:','tag','PipelineTitleTxt');
						uicontrol(uid.popup,'position',[x y-title_height menu_width menu_height],...
							'string',pipelineList,'tag','PipelinePopup','callback',callbackstr);
						y = y - doc_height;
                        
						uicontrol(uid.edit,'style','listbox','position',[x y-2*title_height doc_width doc_height],...
							'string',{'Please select or create a pipeline.'},...
							'tag','PipelineContent','min',0,'max',2,'callback',callbackstr);
                        
                        uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(1) button_width button_height],...
							'string','Run','tag','RunBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(2) button_width button_height],...
							'string','Create New Pipeline','tag','NewPipelineBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(3) button_width button_height],...
							'string','Delete Current Pipeline','tag','DltPipelineBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(4) button_width button_height],...
							'string','Create New Calculator','tag','NewCalcBt','callback',callbackstr);
                        uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(5) button_width button_height],...
							'string','Delete Current Calculator','tag','DltCalcBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(6) button_width button_height],...
							'string','Edit Current Calculator','tag','EditBt','callback',callbackstr);


					case 'PipelinePopup',
						% Step 1: search for the objects you need to work with
						pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value')
                        str = get(pipelinePopupObj, 'string')
						% Step 2, take action
						switch val,
							case 1, 
                                msgbox("Please select or create a pipeline.");							
                            otherwise,
                                pipeline_name = str{val};
                                from_dir = '+ndi/pipeline_storage/';
                                calcs = getCalcFromPipeline(from_dir, pipeline_name);
                                pipelineContentObj = findobj(fig,'tag','PipelineContent');
                                set(pipelineContentObj, 'string', calcs);
						end;    
                        
                        
					case 'NewPipelineBt',
                        read_dir = '+ndi/pipeline_storage/';
                        defaultfilename = {['untitled']};
                        prompt = {'Pipeline name:'};
                        dlgtitle = 'Save new pipeline';
                        extension_list = {['.mat']};
                        [success,filename,replaces] = choosefile(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
                        if success
                            prompt = {'Calculator name:'};
                            dlgtitle = 'Create new calculator';
                            dimentions = [1 50];
                            defaultfilename = {['untitled']};
                            calcname = char(inputdlg(prompt,dlgtitle,dimentions,defaultfilename));
                            calcs = {calcname};
                            save(strcat(read_dir, '/', filename,'.mat'),'calcs');
                            pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                            set(pipelinePopupObj, 'string',getPipelines('+ndi/pipeline_storage'),'Value',length(getPipelines('+ndi/pipeline_storage')));
                            pipelineContentObj = findobj(fig,'tag','PipelineContent');
                            set(pipelineContentObj, 'string',char(calcs),'Value',length(calcs));
                        end
					
                    case 'DltPipelineBt',
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value');
                        str = get(pipelinePopupObj, 'string');
                        read_dir = '+ndi/pipeline_storage/';
                        filename = str{val};
                        msgBox = sprintf('Do you want to delete this pipeline?');
                        title = 'Delete file';
                        b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
                        if strcmpi(b, 'Yes');
                            delete(strcat(read_dir, filename,'.mat'));
                        end
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                        set(pipelinePopupObj, 'string',getPipelines('+ndi/pipeline_storage'),'Value',length(getPipelines('+ndi/pipeline_storage')));
                        pipelineContentObj = findobj(fig,'tag','PipelineContent');
                        set(pipelineContentObj, 'string','Please select or create a pipeline.','Value',1);
                    
                    case 'NewCalcBt',
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value');
                        str = get(pipelinePopupObj, 'string');
						% Step 2, take action
						switch val,
							case 1, 
                                msgbox("Please select or create a pipeline.");							
                            otherwise,
                                pipeline_name = str{val};
                                prompt = {'Calculator name:'};
                                dlgtitle = 'Create new calculator';
                                dimentions = [1 50];
                                defaultfilename = {['untitled']};
                                filename = inputdlg(prompt,dlgtitle,dimentions,defaultfilename);
                                from_dir = '+ndi/pipeline_storage/';
                                calcs = getCalcFromPipeline(from_dir, pipeline_name);
                                calcs{end+1} = char(filename);
                                save(strcat(from_dir, '/', pipeline_name,'.mat'),'calcs');
                                pipelineContentObj = findobj(fig,'tag','PipelineContent');
                                set(pipelineContentObj, 'string',char(calcs),'Value',length(calcs));
						end;    
                        
                    case 'DltCalcBt',
                        msgBox = sprintf('Do you want to delete this calculator?');
                        title = 'Delete calculator';
                        b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
                        if strcmpi(b, 'Yes');
                            pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                            val = get(pipelinePopupObj, 'value');
                            str = get(pipelinePopupObj, 'string');
                            pipeline_name = str{val};
                            piplineContentObj = findobj(fig,'tag','PipelineContent');
                            val = get(piplineContentObj, 'value');
                            str = get(piplineContentObj, 'string');
                            calc_name = str{val};
                            read_dir = '+ndi/pipeline_storage/';
                            calcs = getCalcFromPipeline(read_dir, pipeline_name);
                            calcs(ismember(calcs,calc_name)) = [];
                            pipelineContentObj = findobj(fig,'tag','PipelineContent');
                            set(pipelineContentObj, 'string',char(calcs),'Value',length(calcs));
                            save(strcat(read_dir, '/', pipeline_name,'.mat'),'calcs');
                        end
                        
                    case 'RunBt'
					otherwise,
						disp(['Unknown command ' command '.']);

				end; % switch(command)
            
            function [success,filename,replaces] = choosefile(dir, prompt, defaultfilename, dlgtitle, extension_list)
            % CHOOSEFILE - ask user to choose a file graphically
            %
            % [SUCCESS, FILENAME, REPLACES] = CHOOSEFILE(PROMPT, DEFAULTFILENAME, DLGTITLE, EXTENSION_LIST)
            %
            success = 0;
            replaces = 0;
            
            % ask for file name
            dims = [1 50];
            filename = inputdlg(prompt,dlgtitle,dims,defaultfilename);
            
            if isempty(filename)
                % user selects cancel, return
                success = 0;
                replaces = 0;
                return;
            else
                filename = char(filename);
            end
            
            % check for existence
            exist = 0;
            for s = extension_list
                if isfile(strcat(dir,filename,char(s)))
                    exist = 1;
                end;
            end
            
            while exist
                % while file exists
                promptMessage = sprintf('File exists, do you want to cover?');
                titleBarCaption = 'File existed';
                button = questdlg(promptMessage, titleBarCaption, 'Yes', 'No', 'Yes');
                if strcmpi(button, 'No')
                    % user doesn't want to cover, keep asking
                    filename = inputdlg(prompt,dlgtitle,dims,defaultfilename);
                    if isempty(filename)
                        % user selects cancel, return
                        success = 0;
                        replaces = 0;
                        return;
                    else
                        filename = char(filename);
                    end
                else % user chooses to cover, return
                    success = 1;
                    replaces = 1;
                    return;
                end
                % check for existence again, because we got a new filename
                exist = 0;
                for s = extension_list
                    if isfile(strcat(dir,filename,char(s)))
                        exist = 1;
                    end;
                end
            end
            
            % gets out from the while loop, which means file does not exist
            % no need to replace
            success = 1;
            replaces = 0;
        end % choosefile		
            
            function pipelineList = getPipelines(from_dir)
                fileList = dir(fullfile(from_dir, '*.mat'));
                pipelineList = {fileList.name};
                for i = 1:length(pipelineList)
                    [p,f,e]=fileparts(pipelineList{i});
                    pipelineList{i} = fullfile(p,f);
                end
                pipelineList = ['---',pipelineList];
            end % getPipeline end
            
            function calcList = getCalcFromPipeline(from_dir, pipeline_name)
                calcList = load(strcat(from_dir,pipeline_name,'.mat'));
                calcList = struct2cell(calcList);
                calcList = calcList{:};
            end
            
		end; % pipeline_edit instance
    end % static methods
end