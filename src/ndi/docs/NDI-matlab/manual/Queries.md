# Queries

NDI has a query language that allows you to find NDI documents within an NDI dataset or NDI session.

## Documents:

NDI documents, of type ndi.document, are documents of information within an NDI database. Sometimes we refer to NDI documents casually as just "documents".

An ndi.document is the basic unit of data storage in NDI. The "ndi document types" are the specific types of data that can be expressed as an ndi.document.  Each ndi document type corresponds to a JSON schema definition that is stored on disk. These ndi document types are object-oriented, in that they can have superclasses and subclasses. The ndi.document object is a Matlab object that can represent any type of ndi document type.

## Queries:

Queries are made by building query objects. An *ndi.query* object creator requires 4 input arguments: field, operation, param1, param2.

The meaning of param1 and param2 change with the operation. If param2 is not required, then it may be left off.

The field input contains a character string of the field of each document to examine.

The operations can be any in the following table:

| Operation | Description |
| ---- | ---- |
| regexp    | Matches documents that have a regular expression match between the field value and 'param1'. 'param1' must be a single regular expression, not an array of regular expressions. |
| exact_string | Is the field value an exact string match for 'param1'? Wildcards are not allowed. 'param1' must be a single string, not an array of strings.|
| contains_string | is the field value a char array that contains 'param1'? Wildcards are not allowed. (Use operation 'regexp' if a wildcard is desired.) param1 must be a single string, not an array of strings. |
| exact_number |  is the field value exactly 'param1' (same size and values)? 'param1' must be a single number. |
| lessthan | is the field value less than 'param1' (and of comparable size). 'param1' must be a single number. |
| lessthaneq | is the field value less than or equal to 'param1' (and of comparable size). 'param1' must be a single number, not an array.|
| greaterthan | is the field value greater than 'param1' (and of comparable size). 'param1' must be a single number, not an array. |
| greaterthaneq | is the field value greater than or equal to 'param1' (and of comparable size). 'param1' must be a single number, not an array. |
| hasfield  | is the field present? (no role for 'param1' or 'param2')
| or | matches document where either of the queries passed in param1 and param2 true. param1 and param2 must be ndi.query objects.
| isa | is 'param1' either a superclass or in the document class itself? 'param1' must be a single string, not an array.
| depends_on  | - does the document depend on an item with name 'param1' and the string value 'param2'? If 'param1' is * then only the depenency value is matched. '*' is the only wildcard allowed, and it will match anything. It cannot be combined with other information (for example, "mymatch*" is invalid.) param2 must be the base.id of the object to be found.

A ndi.query object is created with the following creator:

q = ndi.query(field, operation, param1, param2)

The AND of two query objects may be constructed with the & operator.
The OR of any two query objects may be constructed with the | operator.

Examples:

```[matlab]
q_and = q1 & q2;
q_or = q1 | q2;
```

Searches are performed on datasets. For example, if a dataset is named D, then

```[matlab]
documents = D.database_search(q)
```

returns a cell array of all documents that match query q in the dataset D. If there are no matches, the empty cell array {} is returned.

If someone asks you to "find documents", they mean to design a combination of queries and code that produces the answer.

The input arguments 'param1' and 'param2' cannot be arrays of strings or arrays of numbers. If one wants to perform a query on multiple items, considering using the or operator.

Example: Find all element documents that depend on a subject object with local_identifier field 'mylab.net'.

```[matlab]
subject_docs = S.database_search(ndi.query('subject.local_identifier', 'contains_string', 'mylab.net'));
if ~isempty(subject_docs),
   q_e = ndi.query('','isa','element');
   q_s = ndi.query('','depends_on','subject_id',subject_docs{i}.id());
   for i=1:numel(subject_docs),
     q_s=q_s | ndi.query('','depends_on','subject_id',subject_docs{i}.id());
   end
end
```


## Documents

NDI documents are object structures that can be expressed in JSON.

All NDI documents have a structure called "document_class" that contains the following fields:

```[json]

{
  "definition":     "A file that defines the object",
  "validation":     "A file that defines the object class schema"
  "class_name":     "The name of the document class"
  "property_list_name":  "The name of the object field structure that contains the properties for the class",
  "class_version":    "The version of the class"
  "superclasses":     "An array of name/definition pairs that describe the superclasses of this object"
}
```

Many documents also have a structure called 'depends_on', indicating that the contents of the document depend on an antecedent
document. This structure is an array of structures with fields "name" and "value". The "name" describes the purpose of the antecedent document, and the "value" describes the base.id of the antecedent document. A document can have many "depends_on" documents.

In other words, the "depends_on" fields describe a directed graph relationship among the documents.

All NDI documents have the 'base' class as a superclass. The base object has 4 fields under the "base" field

```[json]
"base": {
  "id":                           "The unique identifier of the document",
  "session_id":                   "The unique identifier of the session that the document is associated with",
  "name":                         "The name of the document"
  "datestamp":                    "The time that the document was created"
}
```

An example base object is

```[json]
{
        "document_class": {
                "definition":                                           "$NDIDOCUMENTPATH\/base.json",
                "validation":                                           "$NDISCHEMAPATH\/base_schema.json",
                "class_name":                                           "base",
                "property_list_name":                                   "base",
                "class_version":                                        1,
                "superclasses": [ ]
        },
        "base": {
                "id":                           "4126919195e6b5af_40d651024919a2e4",
                "session_id":                           "4126919195e8839b_40c6d9f78d173ae7",
                "name":                                                 "my_Object_Name",
                "datestamp":                                            "2018-12-05T18:36:47.241Z"
        }
}
```

In an older version of NDI, the 'base' type or class was called 'ndi_document'. Use the 'base' version instead of 'ndi_document'.


Some examples of expressing queries in Matlab are

```[matlab]
    q = ndi.query('base.id','exact_string','12345678')
    q = ndi.query('base.name','exact_string','myname')
    q = ndi.query('base.name','regexp','(.*)') % match any base.name
    q = ndi.query('base.id','regexp','(.*)') % match any base.id
    q = ndi.query('','isa','base') % match any document that is member of class 'base'
```

More examples:

To find documents of a specific class or type use the 'isa' operator of ndi.query:

```matlab
% Search for documents of type stimulus_bath
stimulus_bath_docs = D.database_search(ndi.query('','isa','stimulus_bath'));
```

To find all documents with a specific session_id, you can use the following search:

```matlab
session_id = 'your_session_id_here';
q = ndi.query('base.session_id', 'exact_string', session_id);
docs = D.database_search(q);
```

To find all documents that match a set of session_ids specified in a cell array session_ids, one can build an ndi.query using the or operator:
```matlab
% session_ids: a cell array of session_id character array or strings
q = ndi.query('base.session_id','exact_string',session_ids{1});
for i=2:numel(session_ids),
   q = q | ndi.query('base.session_id','exact_string',session_ids{i});
end
docs = D.database_search(q);
```

Note that probe_location ndi.documents are not the same thing as an element ndi.document that describes a probe. A probe_location document describes the anatomical location of a probe, but it's a separate document linked to a probe document via the depends_on field. They are not the same thing. If a user asks you to find probes that are at a given location, you need to first find the probe_location documents that match and then find the probe documents (that is, the element documents that have element.type=='probe') that those probe_location documents are describing.  If one has a probe_location document probe_loc_doc, then one can find the probe document with the following example.

To find the probe objects associated with a probe_location ndi.document, you can do the following:
```matlab
% probe_loc_doc is probe_location document of type ndi.document
% D is the ndi.dataset or ndi.session object
probe_doc = D.database_search('base.id','exact_string',probe_loc_doc.dependency_value('probe_id'));
% now probe_doc is a cell array of ndi.documents that match
probe_obj = ndi.database.fun.ndi_document2ndi_object(probe_doc{1},D);
```


Recall that the dataset or session commands database_search always returns a set of ndi.document objects (or empty {}). It never returns other object types, such as ndi.session objects or ndi.database objects.

Remember that in Matlab code, comments need a % character. If you include citations in a code segment, be sure they are commented out with a %.


## Mistakes:

Remember that 'in' is not an operator for ndi.query. The only operators are 'regexp', 'exact_string', 'contains_string', 'exact_number', 'lessthan', 'lessthaneq', 'greaterthan','greaterthaneq','hasfield','or','isa', and 'depends_on'.

There is no `probe` document type. When the user writes of a probe document, they mean the ndi document class `element`.

Do not try to access a field of an ndi document with 'depends_on' if the value is actually found in a field. For example, in the document type 'stimulus_parameter', there is no 'depends_on' entry for 'epoch_id'. If temperature_docs{1} is an ndi.document storing an ndi document of type 'stimulus_parameter', then this is wrong:
       epoch_id = temperature_docs{1}.dependency_value('epoch_id'); % wrong
This is correct (accessing the field):
    epoch_id = temperature_docs{1}.document_properties.epochid.epochid; % correct

When searching for NDI documents, you will virtually always want to use ndi.query and the 'database_search' method of an ndi.session or an ndi.dataset object. Never use vlt.data.fieldsearch.

When searching for a probe_location, the ontology_name field must always be a node in an ontology, not a label of the ontology node.


## Natural language and NDI documents:

When the user asks to write a Matlab code that searches for some sort of match, assume that the user means to search an ndi.dataset or ndi.session object that you can call D.

Users may speak of NDI documents by naming their type only. For example, a user might ask "Find all probe instances where the probe_location is X. What they mean formally is that they want you to write code that performs three steps. First, they want the code to produce a query that searches for NDI documents of type 'probe_location' where the field 'ontology_name' matches the formal node for X in an ontology, such as "uberon:12345". Second, given the matches, they want the code to find the probe document that the probe_location document describes. In a third step, they want the code to produce the probe objects using ndi.database.fun.ndi_document2ndi_object.

The user may ask to find a probe object in a certain location; it is important to remember that locations are controlled words that are part of an ontology, typically the Uberon ontology. If the user asks to find a probe at a certain location, be sure the actual search term is an ontology word like an Uberon label. You might need to resolve a casual reference to be an Uberon label.

For example, the user may ask to find probes that are in a certain structure using a casual word such as at the "pyloric nerve". What the user means is to use the formal Uberon label "pyloric nerve (sensu Cancer borealis)" or the Uberon ontology node 'UBERON:8910015'.

When one asks to read an epoch of data it means to identify the epoch_id and then to also read the data from the probe object with readtimeseries.


## Reasoning:

It is useful to think about what types of ndi documents might be returned from a call to D.search_database, where D is an ndi.session or ndi.database object.

Example:

Prompt: If I search for a property 'ontology_name', what type of ndi document types might be returned from D.search_database?
Answer: There are 3 document types that have a field ontology_name: probe_location, stimulus_parameter, treatment

When writing code for the user, and when it is possible to know the type, it will be useful to give the ndi.document objects a name that reflects the type of documents that are expected. But sometimes we can't know the type we may receive.

Example:
```matlab
probe_loc_doc = D.database_search('','isa','probe_location'); % we know the type will be probe_location
docs = D.database_search('base.id','hasfield'); % we will receive a variety of ndi document types
```


Example:
Prompt: Write a code to create a table of all the unique ontologyName and names of all chemicals used in a stimulus_bath for a dataset or session D:
Answer:
```matlab
% Search for documents of type stimulus_bath
stimulus_bath_docs = D.database_search(ndi.query('','isa','stimulus_bath'));

if isempty(stimulus_bath_docs)
    disp('No documents of type stimulus_bath found')
else
    % Initialize an empty table to store all ontologyName and name pairs
    all_data = table();

    % Loop through the documents and collect ontologyName and name fields
    for i=1:numel(stimulus_bath_docs)
        % Access the mixture_table from the document
        mixtable_str = stimulus_bath_docs{i}.document_properties.stimulus_bath.mixture_table;

        % Convert the string representation of the table to a Matlab table object
        mixtable = ndi.database.fun.readtablechar(mixtable_str, 'txt');  % Use 'txt' as the file type

        % Keep only the 'ontologyName' and 'name' columns
        mixtable = mixtable(:, {'ontologyName', 'name'});

        % Append the filtered mixtable to the all_data table
        all_data = [all_data; mixtable];
    end

    % Find unique rows in the combined table
    unique_data = unique(all_data, 'rows');

    % Print the unique rows
    disp(unique_data)
end
```

If you want to find an ndi document with a particular property, you can directly call an ndi.query on that property. There is no need to first do an ndi.query for 'isa' for the type and then write a for loop to look at all the matches. Instead, call ndi.query(property,operation,param1,param2) to find all matches.
