function tutorial_02_05(prefix, testing)
% ndi.example.tutorials.tutorial_02_05 - runs the code in Tutorial 2.5
%
% out = ndi.example.tutorials.tutorial_02_05(PREFIX, [TESTING])
%
% Runs (and tests) the code for 
%
% NDI Tutorial 2: Analzying your first electrophysiology experiment with NDI
%    Tutorial 2.5: Understanding and searching the NDI database
% The tutorial is available at 
%     https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/5_searching_ndi_databases/
%
% PREFIX should be the directory that contains the directory 'ts_exper2'. If it is not
% provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
%
% If TESTING is 1, then the files are examined in the temporary directory ndi_globals.path.temppath (use
% ndi.globals() to make this variable available for inspection). It is assumed that
% ndi.example.tutorial.tutorial_t02_04([],1) has been run (with TESTING set to 1).
%
%

if nargin<1 | isempty(prefix),
	prefix = [userpath filesep 'Documents' filesep 'NDI']; % or '/Users/yourusername/Desktop/' if you put it on the desktop perhaps
end;

if nargin<2,
	testing = 0;
end;

tutorial_dir = 'ts_exper2';

if testing, % copy the files to the temp directory
	ndi.globals() 
	prefix = ndi_globals.path.temppath;
	disp(['Assuming data files ts_exper2 are in ' prefix '.']);
end

 % Code block 2.5.1.1
disp(['Code block 2.5.1.1:']);

dirname = [prefix filesep 'ts_exper2']; % differs from manual tutorial
ref = 'ts_exper2';
S = ndi.setup.vhlab(ref,dirname);  

 % Code block 2.5.1.2
disp(['Code block 2.5.1.2:']);

stim_pres_doc = S.database_search(ndi.query('','isa','stimulus_presentation',''))
  % should see:
  %   stim_pres_doc =
  %   1x4 cell array
  %    {1x1 ndi.document}    {1x1 ndi.document}    {1x1 ndi.document}    {1x1 ndi.document}

stim_pres_doc{1}
  % should see:
  %   ans = 
  %     document with properties:
  %       document_properties: [1x1 struct]

stim_pres_doc{1}.document_properties
  % should see:
  %   ans = 
  %   struct with fields:
  %                        app: [1x1 struct]
  %                 depends_on: [1x1 struct]
  %             document_class: [1x1 struct]
  %                    epochid: 't00001'
  %                epochid_fix: [1x1 struct]
  %               ndi_document: [1x1 struct]
  %      stimulus_presentation: [1x1 struct]
  %                      files: [1x1 struct]

  
 % Code block 2.5.2.1
disp(['Code block 2.5.2.1:']);

stim_pres_doc{1}.document_properties.document_class
% 
% ans = 
%  struct with fields:
%            definition: '$NDIDOCUMENTPATH/stimulus/stimulus_presentation.json'
%            validation: '$NDISCHEMAPATH/stimulus/stimulus_presentation_schema.json'
%            class_name: 'stimulus_presentation'
%    property_list_name: 'stimulus_presentation'
%         class_version: 1
%          superclasses: [3x1 struct]

stim_pres_doc{1}.document_properties.document_class.superclasses(1)
% ans = 
%   struct with fields:
%    definition: '$NDIDOCUMENTPATH/base.json'

stim_pres_doc{1}.document_properties.document_class.superclasses(2)
% ans = 
%  struct with fields:
%    definition: '$NDIDOCUMENTPATH/ndi_document_epochid.json'

stim_pres_doc{1}.document_properties.document_class.superclasses(3)
%ans = 
%  struct with fields:
%    definition: '$NDIDOCUMENTPATH/base.json'

  
 % Code block 2.5.3.1
disp(['Code block 2.5.3.1:']);

% search for document classes that contain the string 'stim'
q_stim = ndi.query('base.id','hasfield','',''); 
stim_docs = S.database_search(q_stim)
  % returns 113 matches for me

% now suppose we also want to search for documents that were made by 
% our app ndi_app_stimulus_decoder:

q_stim_decoder = ndi.query('app.name','exact_string','ndi_app_stimulus_decoder','');

% we can find based on this criteria alone...
stim_decoder_docs = S.database_search(q_stim_decoder)
  % returns 4 matches for me

% ...or we can put the search terms together in an AND to demand both queries are satisfied
q_stim_and_stim_decoder_docs = S.database_search(q_stim_decoder & q_stim);
  % returns 4 matches for me, because all q_stim_decoder docs have 'stimulus' in the class_name

% we can also put queries together into a single variable:

q_or = q_stim_decoder | q_stim;
q_and = q_stim_decoder & q_stim;
q_stim_and_stim_decoder_docs = S.database_search(q_and)  % produces the same as above

% now we can inspect these documents:

q_stim_and_stim_decoder_docs{1}.document_properties
 % ans = 
 %   struct with fields:
 %                       app: [1x1 struct]
 %                depends_on: [1x1 struct]
 %            document_class: [1x1 struct]
 %                   epochid: 't00001'
 %               epochid_fix: [1x1 struct]
 %              ndi_document: [1x1 struct]
 %     stimulus_presentation: [1x1 struct]

q_stim_and_stim_decoder_docs{1}.document_properties.app
 % for me:
 % ans = 
 %   struct with fields:
 %                     name: 'ndi_app_stimulus_decoder'
 %                  version: 'fa1fa7818b215975c43f68ece523b065852ef891'
 %                      url: 'https://github.com/VH-Lab/NDI-matlab'
 %                       os: 'MACI64'
 %               os_version: '10.14.6'
 %              interpreter: 'MATLAB'
 %      interpreter_version: '9.8'

q_stim_and_stim_decoder_docs{1}.document_properties.stimulus_presentation
 % ans = 
 %   struct with fields:
 %     presentation_order: [85x1 double]
 %                stimuli: [17x1 struct]
 
 
 % Code block 2.5.4.1
disp(['Code block 2.5.4.1:'])
 
stim_pres_doc{1}.document_properties.depends_on
% should see:
%   ans = 
%     struct with fields:
%        name: 'stimulus_element_id'
%       value: '412687d3ae63489a_40d1d65fa08bb81a'

 % what is this node at 412687d3ae63489a_40d1d65fa08bb81a ?

mydoc = S.database_search(ndi.query('base.id','exact_string', ...
    stim_pres_doc{1}.document_properties.depends_on(1).value,''));

mydoc{1}.document_properties
% ans = 
%    struct with fields:
%           depends_on: [2x1 struct]
%       document_class: [1x1 struct]
%              element: [1x1 struct]
%         ndi_document: [1x1 struct]

mydoc{1}.document_properties.element
% ans = 
%   struct with fields:
%      ndi_element_class: 'ndi.probe.timeseries.stimulator'
%                   name: 'vhvis_spike2'
%              reference: 1
%                   type: 'stimulator'
%                 direct: 1

% We see it is our visual stimulation system

 % Code block 2.5.4.2
disp('Clode block 2.5.4.2:')
  
e = S.getelements('element.type','spikes');

spikes_doc = S.database_search(ndi.query('base.id','exact_string',e{1}.id(),''))
spikes_doc = spikes_doc{1}

for i=1:numel(spikes_doc.document_properties.depends_on),
    disp(['Depends on ' spikes_doc.document_properties.depends_on(i).name ': ' spikes_doc.document_properties.depends_on(i).value]);
end;

% Should see 3 entries, with your own unique IDs:
%   Depends on underlying_element_id: 412687d3ad57c851_40860c116cfc64c2
%   Depends on subject_id: 412687d3ad571d87_c0dac60e10c0f2a5
%   Depends on spike_clusters_id: 412687f62d1057b8_40c28348e09e5e9b

 % Code block 2.5.5.1
disp(['Code block 2.5.5.1:']);

interactive = 1; % set it to zero if you have Matlab 2020a or later for DataTip navigation! Try it!
docs=S.database_search(ndi.query('base.id','regexp','(.*)','')); % this finds ALL documents
[g,nodes,mdigraph] = ndi.database.fun.docs2graph(docs);
ndi.database.fun.plotinteractivedocgraph(docs,g,mdigraph,nodes,'layered',interactive);



