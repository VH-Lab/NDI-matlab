# NDI Document Design Manual

## Background

NDI documents serve as the fundamental units for storing data within the NDI system. They are structured as JSON objects and follow an object-oriented approach, allowing for inheritance through superclasses.

## How documents are described, saved, and then validated as they are added to a database

NDI documents are currently specified as two parts: a **definition JSON file** (located in ndi_common/database_documents that includes the outline of a blank document, and a **schema JSON file** (located in ndi_common/schema_documents) that describes what the fields and structure of a document must have before it is added to a database.

When one loads a document in NDI (say, running in Matlab), then one creates an **NDI document object** that is stored in memory.

Currently, when one creates a new document of a given type, NDI reads the **definition JSON file** to build a blank document object in memory. It reads in the definitions of superclasses as necessary. At the building stage, there is no checking to see if the fields have appropriate values, they are simply given the values in the blank document definition.

When one attempts to add the document object to a database, then NDI reads the **schema JSON file** and does a comparison to make sure that all fields have the necessary restricted values (is something that is supposed to be a string really a string? Is a variable that is supposed to be a positive integer really a positive integer?) etc.

## Key components

Key components of an NDI document include:

1. document_class **Structure:** Every NDI document contains this structure. It holds meta-information about the document type itself:

   *
   * definition: A reference (like a file path or URL) to the file that defines the specific object structure.
   * validation: A reference to the JSON schema file used to validate the structure and content of documents of this class.
   * class_name: A string specifying the name of the particular document class (e.g., 'base', 'element', 'probe_location').
   * property_list_name: Indicates the name of the field within the document that contains the main properties specific to this class. For the base class, this is 'base'.
   * class_version: The version number of the document class definition.
   * superclasses: An array listing the parent classes from which this document type inherits properties. NDI document types can have superclasses and subclasses, forming a hierarchy. The base class is a universal superclass for all NDI documents. Superclasses enable subclasses to inherit characteristics, promoting code/structure reuse and organization. For example, an element document is a subclass of base, inheriting fields like id and session_id.
2. depends_on **Structure:** This optional structure defines dependencies between documents, creating a directed graph relationship.

   * It's an array of smaller structures, each having a name and a value field.
   * name: A string describing the *role* or *purpose* of the document being depended upon (e.g., 'subject_id', 'probe_id').
   * value: The unique base.id of the antecedent document upon which the current document depends.
   * A single document can depend on multiple other documents.
3. **Property Fields:** Specific document types will have additional fields containing their data. For example, the base document type (which all others inherit from) has a base field containing id, session_id, name, and datestamp. An element document would have an element field with its specific properties.

4. **Associated Files:** NDI documents can be associated with external files, often containing binary data.

   * The ndi.document object provides methods like add_file, current_file_list, and remove_file to manage these associations.
   * Files can either be ingested (copied) into the NDI database structure or referenced by their original location (like a URL).
   * Binary data streams linked to a document can be accessed using database methods like openbinarydoc and closebinarydoc.

## Examples

### Base Document Type Definition

The following is an example of an NDI document of the base type, represented in JSON format:

JSON

```

{
         "document_class": {
                 "definition": "$NDIDOCUMENTPATH/base.json",
                 "validation": "$NDISCHEMAPATH/base_schema.json",
                 "class_name": "base",
                 "property_list_name": "base",
                 "class_version": 1,
                 "superclasses": [ ]
         },
         "base": {
                 "id": "4126919195e6b5af_40d651024919a2e4",
                 "session_id": "4126919195e8839b_40c6d9f78d173ae7",
                 "name": "my_Object_Name",
                 "datestamp": "2018-12-05T18:36:47.241Z"
         }
 }

```

#### Correspondence to General Structure:

* document_class **Structure**: This top-level field directly corresponds to the document_class structure described earlier.
  * definition and validation: These fields point to the files defining the base object structure and its validation schema, respectively.
  * class_name: This is explicitly set to "base", identifying the document's type.
  * property_list_name: This is set to "base", indicating that the specific properties for this class are found within the base field of the document.
  * class_version: Shows the version of this base class definition (version 1 in this example).
  * superclasses: This is an empty array [] because base is the foundational class and does not inherit from any other NDI document types.
* base **Field**: This field corresponds to the specific properties defined for the base class, as indicated by property_list_name. It contains:
  * id: The unique identifier for this specific document instance.
  * session_id: The unique identifier for the NDI session this document belongs to.
  * name: A user-defined name for this document instance.
  * datestamp: The timestamp indicating when this document was created.
* depends_on **Structure**: This example of a base document does not include a depends_on structure, as it is the most fundamental type and typically doesn't depend on other NDI documents. However, other document types inheriting from base (like element or probe_location) often include this structure to link to their antecedents.

### probe_location Document Type Definition

#### probe_location Document Type Definition

The following is the JSON definition for the probe_location document type:

JSON

```

{
	"document_class": {
		"definition":						"$NDIDOCUMENTPATH/probe/probe_location.json",
		"validation":						"$NDISCHEMAPATH/probe/probe_location_schema.json",
		"class_name":						"probe_location",
        "property_list_name":             "probe_location",
		"class_version":					1,
		"superclasses": [
			{ "definition":                   "$NDIDOCUMENTPATH/base.json"}
		]
	},
	"depends_on": [
		{	"name": "probe_id",
			"value": ""
		}
	],
	"probe_location": {
		"ontology_name":							[],
		"name":									[]
	}
 }

```

#### Correspondence to General Structure:

* document_class **Structure**: This aligns with the general structure described previously.
  * definition and validation: Point to the files defining the probe_location object structure and its validation schema.
  * class_name: Set to "probe_location", identifying this document's type.
  * property_list_name: Set to "probe_location", indicating the specific properties are found within the probe_location field.
  * class_version: Shows the version of the probe_location class definition (version 1).
  * superclasses: Contains an object with definition: "$NDIDOCUMENTPATH/base.json", indicating that probe_location inherits from base. This means any probe_location document will also include the base fields (id, session_id, name, datestamp).
* depends_on **Structure**: This probe_location document depends on another document.
  * The dependency is named "probe_id".
  * The value field is empty ("") in this blank definition template. When an actual probe_location instance is created, this value would be filled with the unique id of a specific probe document that this location information applies to.
* probe_location **Field**: This field holds the specific properties unique to probe_location:
  * ontology_name: Intended to store the formal ontology identifier for the location (e.g., a Uberon ID). It's an empty array [] in this blank definition.
  * name: Intended to store the human-readable name of the location. It's also an empty array [] in this blank definition.
  * *(Note: While the definition shows empty arrays [], the schema indicates these should be single string values in an actual document instance. The definition represents the blank template, and the schema enforces the structure.)*

## NDI Document Schema JSON Files

An NDI document schema JSON file describes the structure and requirements of a specific document type for validation purposes. The schema defines all the allowed fields, their data types, valid value ranges, and dependencies, ensuring data integrity when documents are added to a database. The structure and rules described apply to these JSON schema files.

### Schema Structure Outline

A general schema file follows this format:

```

{
	"classname": "name_of_document_type",
	"superclasses": [
		{ "path": "path/to/superclass_schema.json" }
		// ... more superclasses if any
	],
	"depends_on": [
		{ "name": "dependency_name", "value":	"", "mustbenotempty":	0 }
		// ... more dependencies if any
	],
	"file": [
		{ "name": "file_record_name", "location": "path/reference" }
		// ... more file records if any
	],
	"property_list_name": [ // This name should match the name for this class
		{ // Field definition 1 (e.g., a simple type)
			"name": "field_name",
			"type": "data_type",
			"default_value": "default_val",
			"parameters": "",
			"queryable": 1,
			"documentation": "Description of field_name"
		},
		{ // Field definition 2 (e.g., a structure)
			"name": "structure_field",
			"type": "structure",
			"default_value": {},
			"parameters": "",
			"queryable": 0,
			"documentation": "Description of structure_field",
			"subfield": { // Nested fields within the structure
				"name": "subfield_container",
				"field": [ {
					"name": "nested_field_1",
					"type": "nested_data_type",
					"default_value":	"",
					"parameters":		"",
					"queryable":		1,
					"documentation":	"Description of nested_field_1"
				} ]
			}
		}
		// ... more field definitions
	]
 }

```

*(Note: The field name containing the array of property definitions, like "base": [...] or "probe_location": [...], should match the property_list_name specified in the document definition file, such as the one shown for base previously).*

### Key Schema Fields and Rules

* classname: (String) The unique name identifying this document type.
* superclasses: (Array of Objects) Lists the schema files (by path) of parent classes from which this class inherits properties. Allows for object-oriented structure.
* depends_on: (Array of Objects) Defines dependencies on other NDI documents. Each object specifies a dependency name (e.g., "probe_id") and can include flags like mustbenotempty: 1 to indicate if the dependency is mandatory. If a document listed in a dependency is deleted, any document that depends on it will also be deleted.
* file: (Array of Objects) Lists associated binary data files. Each object provides a name for the file record and its location (path or reference). These files are managed via specific database functions (like did.database.openbinaryfile) and not accessed directly by users.
* property_list_name: (Array of Objects, where the array's field name matches the intended property list name) Defines the specific data fields for this document type. Each field object has:
  * name: (String) The name of the data field. Rules: Must start with a letter, can contain alphanumeric characters and underscores (_), but no more than two consecutive underscores.
  * type: (String) Specifies the data type. Valid types include:
    * structure: Defines a nested structure.
    * integer: A single integer value. Parameters: "MINVALUE, MAXVALUE, NANOKAY" (1 if NaN allowed). MINVALUE and MAXVALUE must be specified; use large negative and positive values if you don't intend to put constraints.
    * double: A single double-precision floating-point value. Parameters: "MINVALUE, MAXVALUE, NANOKAY". MINVALUE and MAXVALUE must be specified; use large negative and positive values if you don't intend to put constraints.
    * matrix: A double-precision matrix. Parameters: "ROWS, COLUMNS" (expected dimensions).
    * timestamp: A UTC timestamp string. No parameters.
    * char: A character array (string). Parameters: "length" (expected maximum length).
    * string: A character array (string). Parameters: "" (no specific length). *(Note: 'string' was used in the probe_location schema, 'char' in the rules).*
    * did_uid: An NDI unique identifier string. No parameters.
  * default_value: The value the field takes if not explicitly provided when a document instance is created.
  * parameters: (String) Contains type-specific parameters as described above.
  * queryable: (Integer) Set to 1 if this field should be searchable in the database, 0 otherwise.
  * documentation: (String) A description of the field's purpose.
  * subfield: (Object, only within type: structure) Defines nested fields within a structure, containing its own name and field array.
* **Comments**: Lines beginning with # are treated as comments and ignored.

### Schema Examples

Here are the base and probe_location schemas you provided, explained according to the rules:

#### 1. base Schema

```javascript

{
	"classname":	"base",
	"superclasses": [ ],
	"depends_on": [ ],
	"file": [ ],
	"base": [
		{
			"name": "session_id",
			"type": "did_uid",
			"default_value": "",
			"parameters": 33,
			"queryable": 1,
			"documentation": "Session ID for base document class."
		},
		{
			"name": "id",
			"type": "did_uid",
			"default_value": "",
			"parameters": 33,
			"queryable": 1,
			"documentation": "Unique ID for base document class."
		},
		{
			"name": "name",
			"type": "char",
			"default_value": "",
			"parameters": "",
			"queryable": 1,
			"documentation": "Name of document for base document class."
		},
		{
			"name": "datestamp",
			"type": "timestamp",
			"default_value": "2018-12-05T18:36:47.241Z",
			"parameters": "",
			"queryable": 1,
			"documentation": "Datestamp of document creation in UTC."
		}
	]
 }

```

* classname: Set to "base".
* superclasses**,** depends_on**,** file: All are empty arrays [], indicating base has no parents, dependencies, or associated binary files defined at this level.
* base **(Property List)**: This array defines the core fields for the base document type.
  * session_id and id: Defined as type did_uid (NDI unique identifiers), are queryable (1), and have documentation. The parameters: 33 might refer to a specific length or format check for UIDs.
  * name: Defined as type char, queryable (1), with an empty default and no specific length parameter.
  * datestamp: Defined as type timestamp, queryable (1), with a specified default timestamp value and documentation.

#### 2. probe_location Schema

JSON

```

{
	"classname": "probe_location",
	"superclasses":  [ "base" ],
	"depends_on": [
		{ "name": "probe_id", "mustbenotempty": 1}
	],
	"probe_location": [
		{
			"name": "ontology_name",
			"type": "string",
			"default_value": "",
			"parameters": "",
			"queryable": 1,
			"documentation": "The name of the parameter in an ontology (e.g., uberon:0002436)"
		},
		{
			"name": "name",
			"type": "string",
			"default_value": "",
			"parameters": "",
			"queryable": 1,
			"documentation": "Name of the location (e.g., primary visual cortex)"
		}
	]
 }

```

* classname: Set to "probe_location".
* superclasses: Contains "base", indicating it inherits fields (id, session_id, etc.) from the base schema. Note: The format [ "base" ] differs slightly from the rule's example { "path": "path/to/base.json" }, but conveys the same inheritance.
* depends_on: Defines a mandatory dependency (mustbenotempty: 1) named "probe_id". This links a probe_location instance to a specific probe element instance via its ID.
* file: This optional top-level field is omitted, meaning probe_location documents don't inherently define associated binary files.
* probe_location **(Property List)**: This array defines the specific fields for the probe_location document type.
  * ontology_name: Defined as type string, queryable (1), storing the formal ontology identifier for the location.
  * name: Defined as type string, queryable (1), storing the human-readable name of the location.
* **(Implied** base **fields)**: Because it inherits from base, an actual probe_location document instance will also contain the id, session_id, name, and datestamp fields defined in the base schema.
