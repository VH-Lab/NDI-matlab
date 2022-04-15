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
						button_width = 100;
                        button_height = 25;
						button_y = [400-4*row 400-7*row 400-10*row];
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
							'string','New','tag','NewBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(2) button_width button_height],...
							'string','Edit','tag','EditBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(3) button_width button_height],...
							'string','Run','tag','RunBt','callback',callbackstr);

					case 'PipelinePopup',
						% Step 1: search for the objects you need to work with
						piplinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(piplinePopupObj, 'value');
                        str = get(piplinePopupObj, 'string');
						% Step 2, take action
						switch val,
							case 1, 
                                msgbox("Please select or create a pipeline.");
							case length(str), 
                                disp('New pipeline');
                                read_dir = '+ndi/pipeline_storage/';
                                defaultfilename = {['untitled']};
                                prompt = {'File name:'};
                                dlgtitle = 'Save As';
                                extension_list = {['.mat']};
                                content = {''};
                                [success,filename,replaces] = choosefile(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
                                if success
                                    save(strcat(read_dir, '/', filename,'.mat'),'content');
                                end
                                piplinePopupObj = findobj(fig,'tag','PipelinePopup');
                                set(piplinePopupObj, 'string',getPipelines('+ndi/pipeline_storage'));
                            otherwise,
                                pipeline_name = str{val};
                                from_dir = '+ndi/pipeline_storage/';
                                calcs = getCalcFromPipeline(from_dir, pipeline_name);
                                pipelineContentObj = findobj(fig,'tag','PipelineContent');
                                set(pipelineContentObj, 'string', calcs);
						end;    
                        
                    case 'PipelineContent',
						% Step 1: search for the objects you need to work with
						piplineContentObj = findobj(fig,'tag','PipelineContent');
						val = get(piplineContentObj, 'value');
                        str = get(piplineContentObj, 'string');
                        return;
						% Step 2, take action
						switch val,
							case 1, 
                                disp(['Popup is ' str{val} '.']);
							case 2, 
                                disp(['Popup is ' str{val} '.']);
							case 3,
                                disp(['Popup is ' str{val} '.']);
                            otherwise,
                                disp(['Popup ' val ' is out of bound.']);
						end;
                        
					case 'NewBt',
					case 'EditBt',
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
                pipelineList = ['---',pipelineList,'Create new pipeline'];
            end % getPipeline end
            
            function calcList = getCalcFromPipeline(from_dir, pipeline_name)
                calcList = load(strcat(from_dir,pipeline_name,'.mat'));
                calcList = struct2cell(calcList);
                calcList = calcList{:};
            end
            
		end; % pipeline_edit instance
    end % static methods
end