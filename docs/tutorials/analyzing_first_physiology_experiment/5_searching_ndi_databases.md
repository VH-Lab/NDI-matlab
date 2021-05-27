# 2 Analyzing your first electrophysiology experiment with NDI

## 2.5 Understanding and searching the NDI database

### 2.5.1 The [ndi.database](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/database.m/) and [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) objects

Each [ndi.session](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/session.m/) object has an [ndi.database](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/database.m/) object as one of its properties. This database holds the [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) objects 
that contain the metadata and data results of calculations that apps and programs have performed on the original data.

First, let's open the [ndi.session](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/session.m/) that we've been working with.

#### Code block 2.5.1.1. Type this into Matlab.

```matlab
dirname = [userpath filesep 'Documents' filesep 'NDI' filesep 'ts_exper2']; % change this if you put the example somewhere else
ref = 'ts_exper2';
S = ndi.session.dir(ref,dirname);
```

We find documents by searching for them with the [ndi.session](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/session.m/) method `database_search()`. For example, we can examine all documents that contain stimulus presentation data:

#### Code block 2.5.1.2. Type this into Matlab.

```matlab
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
```

We have used an [ndi.query](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/query.m/) object to conduct our search, and we will describe those objects a little later.

Here we see that [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) objects have a property called `document_properties` that contains all of the text information that is stored in the document. We will look through all of these properties here, and we also direct you to the documentation page for the ndi.document class [stimulus_presentation](https://vh-lab.github.io/NDI-matlab/documents/stimulus/stimulus_presentation/).

## 2.5.2 All [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) objects have the fields `document_class` and `ndi_document`.

The `document_class` fields contain critical information about the class, such as the file that contains its definition, its full class name and its short class name. In addition, document types can be composed of multiple document types. The [stimulus presentation](https://vh-lab.github.io/NDI-matlab/documents/stimulus/stimulus_presentation/) class has two superclasses: [ndi.document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) and [ndi.document_epochid](https://vh-lab.github.io/NDI-matlab/documents/ndi_document_epochid/). This means that a [stimulus_presentation](https://vh-lab.github.io/NDI-matlab/documents/stimulus/stimulus_presentation/) document has its own fields, plus all of the fields from [ndi.document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) documents and and [ndi.document_epochid](https://vh-lab.github.io/NDI-matlab/documents/ndi_document_epochid/) documents. 

Let's look at the data that specifies the superclasses:

#### Code block 2.5.1.3. Type this into Matlab.

```matlab
stim_pres_doc{1}.document_properties.document_class
% 
% ans = 
%  struct with fields:
%            definition: '$NDIDOCUMENTPATH/stimulus/stimulus_presentation.json'
%            validation: '$NDISCHEMAPATH/stimulus/stimulus_presentation_schema.json'
%            class_name: 'ndi_document_stimulus_stimulus_presentation'
%    property_list_name: 'stimulus_presentation'
%         class_version: 1
%          superclasses: [3x1 struct]

stim_pres_doc{1}.document_properties.document_class.superclasses(1)
% ans = 
%   struct with fields:
%    definition: '$NDIDOCUMENTPATH/ndi_document.json'

stim_pres_doc{1}.document_properties.document_class.superclasses(2)
% ans = 
%  struct with fields:
%    definition: '$NDIDOCUMENTPATH/ndi_document_epochid.json'

stim_pres_doc{1}.document_properties.document_class.superclasses(3)
%ans = 
%  struct with fields:
%    definition: '$NDIDOCUMENTPATH/ndi_document.json'
```

All documents have [ndi_document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) as a superclass. Note that [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) is the name of the software object in Matlab (and Python), whereas [ndi_document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) is the name of the database object type that has the following fields:

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **session_id** | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| **id** | - | NDI ID string | The globally unique identifier of this document |
| **name** |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| **type** |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| **datestamp** | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| **database_version** | - | character array (ASCII) | Version of this document in the database |

The most useful item in each [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) is its unique identifier `id`. This is a globally unique identifier, which means that no other [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) or corresponding [ndi_document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) anywhere in the universe has the same identifier. It is constructed of two hexidecimal strings: the first is based on the time of creation in Universal Controlled Time (UTC), and the second is created by a random number generator. This constructions means that `ndi.document` ids are not only unique, but also that sorting them alphabetically will give you the creation order of the documents. This can come in handy from time to time.

## 2.5.3 Searching for [ndi_documents](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) with [ndi.query](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/query.m/)

Performing analyses or analyses of analyses in NDI involves searching for previous entries in the database, building upon them, and writing the
results back to the database. The object [ndi.query](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/query.m/) allows one to express database searches. Let's learn about [ndi.query](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/query.m/) with a few examples.

```matlab
% search for document classes that contain the string 'stim'
q_stim = ndi.query('document_class.class_name','contains_string','stim',''); 
stim_docs = S.database_search(q_stim)
  % returns 35 matches for me

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
 %      presentation_time: [85x1 struct]
 %                stimuli: [17x1 struct]

```

The different possible search terms for ndi.query objects is shown below:

```matlab
NDI_QUERY_OBJ = ndi.query(FIELD, OPERATION, PARAM1, PARAM2)
```

| Operation | Description |
| ---- | ---- |
|`'regexp'`| are there any regular expression matches between the field value and `'param1'`? |
|`'exact_string'`| is the field value an exact string match for `'param1'`? |
|`'contains_string'`| is the field value a char array that contains `'param1'`? |
|`'exact_number'`| is the field value exactly `'param1'` (same size and values)? |
|`'lessthan'`| is the field value less than `'param1'` (and comparable size) |
|`'lessthaneq'`| is the field value less than or equal to `'param1'` (and comparable size) |
|`'greaterthan'`| is the field value greater than `'param1'` (and comparable size) |
|`'greaterthaneq'`| is the field value greater than or equal to `'param1'` (and comparable size) |
|`'hasfield'`| is the field present? (no role for `'param1'` or `'param2'`) |
|`'hasanysubfield_contains_string'` | Is the field value an array of structs or cell array of structs such that any has a field named `'param1'` with a string that contains the string in `'param2'`? |
|`'or'`| are any of the searchstruct elements specified in '`param1`' true? |
|`'isa'`| is `'param1'` either a superclass or the document class itself of the ndi_document? |
|`'depends_on'`| does the document depend on an item with name `'param1'` and value `'param2'`? |




## 2.5.4 The `depends_on` field and database structure

Many analysis procedures or creation procedures are dependent on the results from previous calculations. These dependencies are denoted in a field called `depends_on`. Let's look at the dependencies for our example stimulus presentation:

#### Code block 2.5.4.1. Type this into Matlab.

```matlab
stim_pres_doc{1}.document_properties.depends_on
% should see:
%   ans = 
%     struct with fields:
%        name: 'stimulus_element_id'
%       value: '412687d3ae63489a_40d1d65fa08bb81a'

 % what is this node at 412687d3ae63489a_40d1d65fa08bb81a ?

mydoc = S.database_search(ndi.query('ndi_document.id','exact_string', ...
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
```

Some documents have a lot of depends_on items. Let's examine our ctx_1 neuron that we created in [Tutorial 2.3](https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/3_spikesorting/).

#### Code block 2.5.4.2. Type this into Matlab.
```matlab
e = S.getelements('element.type','spikes');

spikes_doc = S.database_search(ndi.query('ndi_document.id','exact_string',e{1}.id(),''))
spikes_doc = spikes_doc{1}

for i=1:numel(spikes_doc.document_properties.depends_on),
	disp(['Depends on ' spikes_doc.document_properties.depends_on(i).name ': ' spikes_doc.document_properties.depends_on(i).value]);
end;

% Should see 3 entries, with your own unique IDs:
%   Depends on underlying_element_id: 412687d3ad57c851_40860c116cfc64c2
%   Depends on subject_id: 412687d3ad571d87_c0dac60e10c0f2a5
%   Depends on spike_clusters_id: 412687f62d1057b8_40c28348e09e5e9b
```

### 2.5.5 Structure of an [ndi.database](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/database.m/)

NDI databases (and any analysis project) has a beautiful underlying structure that one can visualize, to get a sense of how the calculations and inferred objects (like neurons that spike) are derived from one another.

#### Code block 2.5.5.1. Type this into Matlab.

```matlab
interactive = 1; % set it to zero if you have Matlab 2020a or later for DataTip navigation! Try it!
docs=S.database_search(ndi.query('ndi_document.id','regexp','(.*)','')); % this finds ALL documents
[g,nodes,mdigraph] = ndi.database.fun.docs2graph(docs);
ndi.database.fun.plotinteractivedocgraph(docs,g,mdigraph,nodes,'layered',interactive);
```

For this session, the graph should look something like this:

![Image of a graph of NDI documents in an NDI database](tutorial_02_05_databasestructure.png)

You can explore the nodes by clicking next to them. On the command line, a summary of the document will appear. Here is a [short video demonstration](https://photos.app.goo.gl/Qmb3W6hyYBjFVS818).


### 2.5.6 Discussion/Feedback

Post [comments, bugs, questions, or discuss](https://github.com/VH-Lab/NDI-matlab/issues/180).

You may find it odd that we haven't told you how to add items to the database here in this tutorial. Instead, we've only told you how to inspect the database. The process of creating and testing a document schema and adding and removing documents are described in a Planned Tutorial. The link will be here when it is created.


