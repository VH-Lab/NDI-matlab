# 2 Analyzing your first electrophysiology experiment with NDI

(This tutorial is being built. Right now. Feel free to look around but it is under construction.)

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
  %   1×4 cell array
  %    {1×1 ndi.document}    {1×1 ndi.document}    {1×1 ndi.document}    {1×1 ndi.document}

stim_pres_doc{1}
  % should see:
  %   ans = 
  %     document with properties:
  %       document_properties: [1×1 struct]

stim_pres_doc{1}.document_properties
  % should see:
  %   ans = 
  %   struct with fields:
  %                        app: [1×1 struct]
  %                 depends_on: [1×1 struct]
  %             document_class: [1×1 struct]
  %                    epochid: 't00001'
  %                epochid_fix: [1×1 struct]
  %               ndi_document: [1×1 struct]
  %      stimulus_presentation: [1×1 struct]
```

We have used an [ndi.query](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/query.m/) object to conduct our search, and we will describe those objects a little later.

Here we see that [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) objects have a property called `document_properties` that contains all of the text information that is stored in the document. We will look through all of these properties here, and we also direct you to the documentation page for the ndi.document class [stimulus_presentation](https://vh-lab.github.io/NDI-matlab/documents/stimulus/stimulus_presentation/).

## 2.5.2 All [ndi.document](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/document.m/) objects have the fields `document_class` and `ndi_document`.

The `document_class` fields contain critical information about the class, such as the file that contains its definition, its full class name and its short class name. In addition, document types can be composed of multiple document types. The [stimulus presentation]((https://vh-lab.github.io/NDI-matlab/documents/stimulus/stimulus_presentation/) class has two superclasses: [ndi.document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) and [ndi.document_epochid](https://vh-lab.github.io/NDI-matlab/documents/ndi_document_epochid/). This means that a [stimulus_presentation](https://vh-lab.github.io/NDI-matlab/documents/stimulus/stimulus_presentation/) document has its own fields, plus all of the fields from [ndi.document](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) documents and and [ndi.document_epochid](https://vh-lab.github.io/NDI-matlab/documents/ndi_document_epochid/) documents. 

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
%          superclasses: [3×1 struct]

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

## 2.5.3 The `depends_on` field:

## 2.5.4 Searching for [ndi_documents](https://vh-lab.github.io/NDI-matlab/documents/ndi_document/) with [ndi.query](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/query.m/)


## 2.5.5 Structure of an [ndi.database](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/database.m/)

```matlab
docs=S.database_search(ndi.query('ndi_document.id','regexp','(.*)','')); % this finds ALL documents
[g,nodes,mdigraph] = ndi.database.fun.docs2graph(docs);
ndi.database.fun.plotinteractivedocgraph(docs,g,mdigraph,nodes,'layered');
```

You may find it odd that we haven't told you how to add items to the database here in this tutorial. Instead, we've only told you how to inspect the database. The process of creating and testing a document schema and adding and removing documents are described in a Planned Tutorial. The link will be here when it is created.

