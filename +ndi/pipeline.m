% TODO
% 1. Get a calculation type list
% 2. Pipeline edit & run button (edit: ndi.calculator.graphical_edit_calculator, waiting for updates)

% TODO
% 1. (Done) Reduce the repetitiveness in the callback code
% 2. (Done) Put the filepath in userdata instead of hard coding
% 3. Write documentation for the helper functions and for the main functions

% To fix:
% 1. Should not always goes back to '---' after creating a new pipeline (not user friendly)

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
				vlt.data.assign(varargin{:});
                
				window_params.height = 500;
				window_params.width = 400;
				fig = []; % figure to use

				if strcmpi(command,'new'), 
					if isempty(fig),
						fig = figure;
					end;
					command = 'NewWindow';
					% new window, set userdata
					ud.pipelinePath = ['+ndi' filesep 'my_pipelines'];
					ud.pipelineList = []; % initially empty
					ud.pipelineListChar = []; % initally empty
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
							'tag','PipelineContentList','min',0,'max',2,'callback',callbackstr); % I like to include the type in the tag, helps me remember what it is months later
                        
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

						ndi.pipeline.pipeline_edit('command','LoadPipelines'); % load the pipelines from disk
                        
                    case 'UpdatePipelines', % invented command that is not a callback
                        ud.pipelineList = ndi.pipeline.getPipelines(ud.pipelinePath);
						ud.pipelineListChar = ndi.pipeline.pipelineListToChar(ud.pipelineList);
                        set(fig,'userdata',ud);
                        
					case 'LoadPipelines', % invented command that is not a callback
						% called on startup or if the user ever changes the file path through some future mechanism
						ud.pipelineList = ndi.pipeline.getPipelines(ud.pipelinePath);
						ud.pipelineListChar = ndi.pipeline.pipelineListToChar(ud.pipelineList);
						set(fig,'userdata',ud);
						pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						set(pipelinePopupObj, 'string',ud.pipelineListChar,'Value',1);
                        pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                        set(pipelineContentObj, 'string', [], 'Value', 1);
                        
					case 'UpdateCalculatorList', % invented command that is not a callback
						calcList = ndi.pipeline.getCalcFromPipeline(ud.pipelineList, pipeline_name);
						calcListChar = ndi.pipeline.calculationsToChar(calcList);
						pipelineContentObj = findobj(fig,'tag','PipelineContentList');
						set(pipelineContentObj, 'string', calcListChar, 'Value', min(numel(calcListChar),1));
                        
					case 'PipelinePopup',
						% Step 1: search for the objects you need to work with
						pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value');
						str = get(pipelinePopupObj, 'string');
						% Step 2, check not the "---" one and display
						if val == 1
							msgbox('Please select or create a pipeline.');
                            pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                            set(pipelineContentObj, 'string', [], 'Value', 1);
                            return
						end
						pipeline_name = str{val};
						ndi.pipeline.pipeline_edit('command','UpdateCalculatorList','pipeline_name',pipeline_name); 
                        
					case 'NewPipelineBt',
						% get dir
						read_dir = [ud.pipelinePath filesep];
						% create dialog box
						defaultfilename = {['untitled']};
						prompt = {'Pipeline name:'};
						dlgtitle = 'Save new pipeline';
						extension_list = {['']};
						% check if the user want to create/replace
						[success,filename,replaces] = ndi.util.choosefileordir(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
						if success % if success, add pipeline
							if replaces
								rmdir([read_dir filesep filename], 's');
							end
							mkdir(read_dir,filename);
							% update and load pipelines
                            ndi.pipeline.pipeline_edit('command','LoadPipelines');
						end
					
					case 'DltPipelineBt',
						pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
						val = get(pipelinePopupObj, 'value');
						% check not the "---" 
						if val == 1
							msgbox('Please select a pipeline to delete.');
                            return
						end
						str = get(pipelinePopupObj, 'string');
						% get dir
						read_dir = [ud.pipelinePath filesep];  % TODO: use userdata
						filename = str{val};
						% ask and delete
						msgBox = sprintf('Do you want to delete this pipeline?');
						title = 'Delete file';
						b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
						if strcmpi(b, 'Yes');
							rmdir([read_dir filesep filename], 's');
                        end
                        % update and load pipelines
						ndi.pipeline.pipeline_edit('command','LoadPipelines');
                        
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
							'SelectionMode','single','ListString',calcTypeList);
						calculator = calcTypeList{calcTypeStr};
						
						% ask for file name
						read_dir = [ud.pipelinePath filesep pipeline_name filesep];
						prompt = {'Calculator name:'};
						dlgtitle = 'Create new calculator';
						defaultfilename = {['untitled']};
						extension_list = {['.json']};
						[success,calcname,replaces] = ndi.util.choosefileordir(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
						if success % if success, create and save newCalc
							if replaces
								delete([read_dir filesep calcname '.json']);
							end
							newCalc = ndi.pipeline.setDefaultCalc(calculator, calcname);
							json_filename = char(strcat(read_dir,calcname,'.json'));
							fid = fopen(json_filename,'w');
							fprintf(fid,jsonencode(newCalc));
							fclose(fid);
							% update and load calculator
                            ndi.pipeline.pipeline_edit('command','UpdatePipelines');
							ndi.pipeline.pipeline_edit('command','UpdateCalculatorList','pipeline_name',pipeline_name); % here we invent a command that's not a callback
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
							piplineContentObj = findobj(fig,'tag','PipelineContentList')
							calc_val = get(piplineContentObj, 'value')
							calc_str = get(piplineContentObj, 'string')
							calc_name = calc_str{calc_val};
							filename = [ud.pipelinePath filesep pipeline_name filesep calc_name '.json'];  
							delete(filename);
                            % update and load pipelines
                            ndi.pipeline.pipeline_edit('command','UpdatePipelines');
							ndi.pipeline.pipeline_edit('command','UpdateCalculatorList','pipeline_name',pipeline_name); % here we invent a command that's not a callback						
                        end
                        
					case 'EditBt'
						ndi.calculator.graphical_edit_calculator('command','NEW'); % need more inputs here, can you figure them out?
						disp([command 'is not implemented yet.']);
                        
					case 'RunBt'
						disp([command 'is not implemented yet.']);
                        
					case 'PipelineContentList'
						disp([command 'is not supposed to do anything.'])
                        
					otherwise,
						disp(['Unknown command ' command '.']);
				end; % switch(command)

		end % pipeline_edit()
        
        
		function calcList = getCalcFromPipeline(pipelineList, pipeline_name)
			% ndi.pipeline.getCalcFromPipeline - DOCS HERE
			%
			% CALCLIST = ndi.pipeline.getCalcFromPipeline(PIPELINE_LIST, PIPELINE_NAME)
			%
			%  TODO: add docs
			%
				calcList = [];
				for i = 1:length(pipelineList)
					if strcmp(pipelineList{i}.pipeline_name, pipeline_name)
						calcList = pipelineList{i}.calculations;
					end
				end
		end
            
		function calcListChar = calculationsToChar(calcList)
			% TODO: DOCS HERE
			%

				calcListChar = [];
				for i = 1:length(calcList)
					calcListChar{i} = calcList{i}.ndi_pipeline_element.name;
				end
		end % calculationsToChar
            
		function newCalc = setDefaultCalc(calculator, name)
			% TODO: DOCS HERE
				newCalc.ndi_pipeline_element.calculator = calculator;
				newCalc.ndi_pipeline_element.name = name;
				newCalc.ndi_pipeline_element.parameter_code = '';
				newCalc.ndi_pipeline_element.default_options = 'NoAction';
		end
            
		function pipelineList = getPipelines(read_dir)
			% TODO: DOCS HERE
			%
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
		end % getPipeline

		function pipelineListChar = pipelineListToChar(pipelineList)
			% TODO: DOCS
			pipelineListChar = [];
			for i = 1:length(pipelineList)
			    pipelineListChar{i} = pipelineList{i}.pipeline_name;
			end
		end % pipelineListToChar
        
        %}
 
	end % static methods
end % class
