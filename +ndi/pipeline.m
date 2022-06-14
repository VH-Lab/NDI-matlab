% TODO
% 1. Get a calculation type list
% 2. Pipeline editor & run button

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
                    % new window, set userdata
                    ud.pipelineList = getPipelines(['+ndi' filesep 'my_pipelines']);
                    ud.pipelineListChar = pipelineListToChar(ud.pipelineList);
                    set(fig,'userdata',ud);
                else 
                    fig = gcf;
                    % not new window, get userdata
                    ud = get(fig,'userdata');
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
                        x = edge; y = top-row;
                        uicontrol(uid.txt,'position',[x y title_width title_height],'string','Select pipeline:','tag','PipelineTitleTxt');
						uicontrol(uid.popup,'position',[x y-title_height menu_width menu_height],...
							'string',ud.pipelineListChar,'tag','PipelinePopup','callback',callbackstr);
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
						val = get(pipelinePopupObj, 'value');
                        str = get(pipelinePopupObj, 'string');
						% Step 2, check not the "---" one and display
                        if val == 1
                            msgbox('Please select or create a pipeline.');
                        end
                        pipeline_name = str{val};
                        calcList = getCalcFromPipeline(ud.pipelineList, pipeline_name);
                        calcListChar = calculationsToChar(calcList);
                        pipelineContentObj = findobj(fig,'tag','PipelineContent');
                        set(pipelineContentObj, 'string', calcListChar, 'Value', 1);
                       
                        
					case 'NewPipelineBt',
                        % get dir
                        read_dir = ['+ndi' filesep 'my_pipelines' filesep];
                        % create dialog box
                        defaultfilename = {['untitled']};
                        prompt = {'Pipeline name:'};
                        dlgtitle = 'Save new pipeline';
                        extension_list = {['']};
                        % check if the user want to create/replace
                        [success,filename,replaces] = choosefile(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
                        if success % if success, add pipeline
                            if replaces
                                rmdir([read_dir filesep filename], 's');
                            end
                            mkdir(read_dir,filename);
                            % update userdata
                            ud.pipelineList = getPipelines(['+ndi' filesep 'my_pipelines']);
                            ud.pipelineListChar = pipelineListToChar(ud.pipelineList);
                            pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                            set(pipelinePopupObj, 'string',ud.pipelineListChar,'Value',length(ud.pipelineListChar));
                            pipelineContentObj = findobj(fig,'tag','PipelineContent');
                            set(pipelineContentObj, 'string', [], 'Value', 0);
                        end
					
                    case 'DltPipelineBt',
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value');
                        % check not the "---" 
                        if val == 1
                            msgbox('Please select a pipeline to delete.');
                            return;
                        end
                        str = get(pipelinePopupObj, 'string');
                        % get dir
                        read_dir = ['+ndi' filesep 'my_pipelines' filesep];
                        filename = str{val};
                        % ask and delete
                        msgBox = sprintf('Do you want to delete this pipeline?');
                        title = 'Delete file';
                        b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
                        if strcmpi(b, 'Yes');
                            rmdir([read_dir filesep filename], 's');
                        end
                        % update userdata
                        ud.pipelineList = getPipelines(['+ndi' filesep 'my_pipelines']);
                        ud.pipelineListChar = pipelineListToChar(ud.pipelineList);
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                        set(pipelinePopupObj, 'string',ud.pipelineListChar,'Value',1);                        
                        pipelineContentObj = findobj(fig,'tag','PipelineContent');
                        set(pipelineContentObj, 'string','Please select or create a pipeline.','Value',1);
                    
                    case 'NewCalcBt',
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value');
                        % check not the "---" 
                        if val == 1
                            msgbox('Please select or create a pipeline.');
                            return;
                        end
                        str = get(pipelinePopupObj, 'string');
                        pipeline_name = str{val};
                        
                        % get calculator type
                        calcTypeList = {'ndi.calc.not_finished_yet','ndi.calc.need_calculator_types','ndi.calc.this_is_a_placeholder'};
                        [calcTypeStr,calcTypeVal] = listdlg('PromptString','Choose a calculator type:',...
                                      'SelectionMode','single',...
                                      'ListString',calcTypeList);
                        calculator = calcTypeList{calcTypeStr};
                        
                        % ask for file name
                        read_dir = ['+ndi' filesep 'my_pipelines' filesep pipeline_name filesep];
                        prompt = {'Calculator name:'};
                        dlgtitle = 'Create new calculator';
                        defaultfilename = {['untitled']};
                        extension_list = {['.json']};
                        [success,calcname,replaces] = choosefile(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
                        if success % if success, create and save newCalc
                            if replaces
                                delete([read_dir filesep calcname '.json']);
                            end
                            newCalc = setDefaultCalc(calculator, calcname);
                            json_filename = char(strcat(read_dir,calcname,'.json'));
                            fid = fopen(json_filename,'w');
                            fprintf(fid,jsonencode(newCalc));
                            fclose(fid);
                            % update userdata
                            ud.pipelineList = getPipelines(['+ndi' filesep 'my_pipelines']);
                            ud.pipelineListChar = pipelineListToChar(ud.pipelineList);
                            calcList = getCalcFromPipeline(ud.pipelineList, pipeline_name);
                            calcListChar = calculationsToChar(calcList);
                            pipelineContentObj = findobj(fig,'tag','PipelineContent');
                            set(pipelineContentObj, 'string', calcListChar, 'Value', length(calcListChar)); 
                        end
                                              
                    case 'DltCalcBt',
                        pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                            pip_val = get(pipelinePopupObj, 'value');
                            % check not the "---" 
                            if pip_val == 1
                                msgbox('Please select or create a pipeline.');
                                return;
                            end
                            pip_str = get(pipelinePopupObj, 'string');
                        msgBox = sprintf('Do you want to delete this calculator?');
                        title = 'Delete calculator';
                        b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
                        if strcmpi(b, 'Yes');
                            pipeline_name = pip_str{pip_val};
                            piplineContentObj = findobj(fig,'tag','PipelineContent');
                            calc_val = get(piplineContentObj, 'value');
                            calc_str = get(piplineContentObj, 'string');
                            calc_name = calc_str{calc_val};
                            filename = ['+ndi' filesep 'my_pipelines' filesep pipeline_name filesep calc_name '.json'];
                            delete(filename);
                            ud.pipelineList = getPipelines(['+ndi' filesep 'my_pipelines']);
                            ud.pipelineListChar = pipelineListToChar(ud.pipelineList);
                            calcList = getCalcFromPipeline(ud.pipelineList, pipeline_name);
                            calcListChar = calculationsToChar(calcList);
                            pipelineContentObj = findobj(fig,'tag','PipelineContent');
                            set(pipelineContentObj, 'string', calcListChar, 'Value', length(calcListChar));
                        end
                        
                    case 'EditBt'
                        disp([command 'is not implemented yet.']);
                    case 'RunBt'
                        disp([command 'is not implemented yet.']);
                    case 'PipelineContent'
                        disp([command 'is not supposed to do anything.'])
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
            
            % replace illegal chars to underscore
            filename = regexprep(filename,'[^a-zA-Z0-9]','_');
            
            % check for existence
            exist = 0;
            for s = extension_list
                if isfolder(strcat(dir,filename,char(s))) | isfile(strcat(dir,filename,char(s)))
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
            
            function pipelineList = getPipelines(read_dir)
                d = dir(read_dir);
                isub = [d(:).isdir]; 
                nameList = {d(isub).name}';
                nameList(ismember(nameList,{'.','..'})) = [];
                pipelineList{1}.pipeline_name = '---';
                pipelineList{1}.calculations = {};
                for i = 2:(length(nameList)+1)
                    pipelineList{i}.pipeline_name = nameList{i-1};
                    pipelineList{i}.calculations = {};
                    D = dir([read_dir filesep char(pipelineList{i}.pipeline_name) filesep '*.json']);
                    for d = 1:numel(D),
                        %D(d).name is the name of the nth calculator in the pipeline; you can use that to build your list of calculators
                        pipelineList{i}.calculations{d} = jsondecode(vlt.file.textfile2char([read_dir filesep char(pipelineList{i}.pipeline_name) filesep D(d).name]));
                    end
                end
            end % getPipeline end
            
            function pipelineListChar = pipelineListToChar(pipelineList)
                pipelineListChar = [];
                for i = 1:length(pipelineList)
                    pipelineListChar{i} = pipelineList{i}.pipeline_name;
                end
            end
                        
            function calcList = getCalcFromPipeline(pipelineList, pipeline_name)
                calcList = [];
                for i = 1:length(pipelineList)
                    if strcmp(pipelineList{i}.pipeline_name, pipeline_name)
                        calcList = pipelineList{i}.calculations;
                    end
                end
            end
            
            function calcListChar = calculationsToChar(calcList)
                calcListChar = [];
                for i = 1:length(calcList)
                    calcListChar{i} = calcList{i}.ndi_pipeline_element.name;
                end
            end
            
            function newCalc = setDefaultCalc(calculator, name)
                newCalc.ndi_pipeline_element.calculator = calculator;
                newCalc.ndi_pipeline_element.name = name;
                newCalc.ndi_pipeline_element.parameter_code = '';
                newCalc.ndi_pipeline_element.default_options = 'NoAction';
            end
            
		end; % pipeline_edit instance
    end % static methods
end