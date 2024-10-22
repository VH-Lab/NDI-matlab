function edit()
% ndi.test.pipeline.edit - test the pipeline editor GUI
%
% Calls 
%
%    ndi.pipeline.edit('command','new','pipelinePath',...
%      fullfile(userpath,'tools','NDI-matlab','+ndi','+test','+pipeline',...
%     'test_pipeline'))
%
% to test the pipeline graphical editor.
%

S = []; % empty session

ndi.pipeline.edit('command','new','pipelinePath',...
    fullfile(userpath,'tools','NDI-matlab','+ndi','+test','+pipeline',...
    'test_pipeline'),'session',S);

