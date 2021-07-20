# Tutorial 7: Writing your own apps

## 7.2: Writing a simple calculation

Usually, end user scientists do not want to develop an app, but instead want to develop a consistent and tested
method for performing a calculation. We have developed an NDI mini-app class called ndi.calculation for that purpose.

ndi.calculation objects require very little in the way of construction:

1. A single document type that they produce
2. A function that creates the document type from input parameters
3. A function that searches for all possible inputs to the function
4. A short documentation for the document type

Once we have these ingredients, we have an ndi.calculation that can be run as simply as

```
c = ndi.calc.example.simple;
c.run('NoAction'); % will run but will not replace existing calculations with the same parameters
```

We will cover the develop of a very simple calculation: ndi.calc.example.simple

### 7.2.1 Designing the database document









OLD TEXT:


The first step in designing an app is to have a clear picture of what the app will do. 

Tagger was developed because there is a need to be able to specify metadata for ndi documents that is not
part of their intrinsic parameters. For example, if you put a drug on your preparation, you might want to
label certain epochs as belonging to that condition. The label would ideally conform to an ontology, which is
a regulated vocabulary.

In developing Tagger, we decided there were 2 types of documents that we would like to store. We would like
to be able to put a "tag", or a label that also potentially has a value, onto any database document.  It has
the same properties as a tag, but the name implies that the tag refers to a particular type of information,
which is an experimental condition.

That is, we want a single document type:

1.  A *tag* document that allows one to specify a name and value of a tag, the ontology that it comes from, and to have it "depend on" an NDI document id, so it is associated with a particular document.

We want our app to be able to 

1. Add a tag to the database
2. Find tags that match certain criteria


### 7.1.2 Discussing the design of the app to ensure it is a very good way of solving the problem

It is important to discuss the design of any new app to make sure that it is, at least, a very good way of
solving the problem. I usually write out a few alternatives and a written "debate" among them.

| Alternative idea | Discussion | 
| ---              |   ----     |
| Why not add the tags to database documents directly? | NDI documents are not editable once created; they are designed to be made once, with a time stamp. Other calculations depend on these documents remaining in their original state. If we made NDI documents editable, then, potentially, all calculations based on that document would need to be updated. Instead, you can only delete documents entirely (which removes all dependent documents). |
| Why not allow multiple tags to be added in a single database document? Won't limiting to 1 tag per document mean that there could be a lot of documents? | The argument against is the same as the above. We can't edit NDI documents. If someone wants to modify or delete one of the entries, they would have to delete the whole document. |
| Why not just have the user search for tags using the normal database querying? Why write a function to find the documents? | This is not necessary but it is a helpful addition; the user could use normal database querying to discover the same things. We offer the function here in the app as a shortcut. | 

### 7.1.3

Now we need to add a new document type. There are 2 steps. First, we have to add a blank document that
indicates the structure of the document. Second, we have to add a schema document that describes how the
document is to be filled in.

Here is the document. Since this is part of NDI, we put it in the `ndi_common/database_documents/apps/tagger/` directory:

#### ndi_common/database_documents/apps/tagger/tag.json

```json
{
	"document_class": {
		"definition":			"$NDIDOCUMENTPATH\/apps\/tagger\/tag.json",
		"validation":			"$NDISCHEMAPATH\/apps\/tagger\/tag.json",
		"class_name":			"ndi_document_apps_tagger_tag",
		"property_list_name":	"tag",
		"class_version":		1,
		"superclasses": [
			{ "definition":		"$NDIDOCUMENTPATH\/ndi_document.json" }
		]
	},
	"depends_on": [
		{
			"name":         "document_id",
			"value":        ""
		}
	],
	"tag": {
                "ontology":             "",
                "ontology_name":        "",     
                "ontology_id":          "",
                "value":                ""
	}
}
```

INSERT DETAIL DESCRIBING DOCUMENT

And the schema:

#### ndi_common/schema_documents/apps/tagger/tag.json


```json
{
	"$schema": "http://json-schema.org/draft/2019-09/schema#",
	"id": "$NDISCHEMAPATH\/apps\/ndi_document_apps_tagger_tag.json",
	"title": "tag",
	"type": "object",
	"properties": {
		"ontology": {
			"type": "string",
			"doc_default_value": "none",
			"doc_data_type": "character array (ASCII)",
			"doc_description": "The name of the ontology to be used. At the present time it is okay to leave this blank and use a term that is outside an ontology."
		},
		"ontology_name": {
			"type": "string",
			"doc_default_value": "",
			"doc_data_type": "character array (ASCII)",
			"doc_description": "The name of tag in the ontology. If an ontology is specified, this `ontology_name` must match a word in the ontology."
		},
		"ontology_id": {
			"type": "string",
			"doc_default_value": "",
			"doc_data_type": "character array (ASCII)",
			"doc_description": "The ID of the word in the ontology. If an ontology is specified, the ID must match the ID of the word or element `ontology_name` in the ontology."
		},
		"value": {
			"type": "string",
			"doc_default_value": "",
			"doc_data_type": "character array (ASCII)",
			"doc_description": "A field that may be associated with the tag. May be blank."
		},
		"depends_on" : {
			"type" : "array",
			"items" : [
				{
					"type": "object", 
					"properties" : {
						"name" : {
							"const" : "document_id"
						},
						"value" : {
							"type" : "string"
						}
					}
				}
			]
		}
	}
}
```


INSERT DETAIL DESCRIBING SCHEMA





### 7.1.6 Discussion/Feedback

This concludes our tutorial on writing a simple app in NDI.

Post [comments, bugs, questions, or discuss](https://github.com/VH-Lab/NDI-matlab/issues/190).
