# CLASS ndi.documentservice

```
  ndi.documentservice - a class of methods that allows objects to interact with ndi.document objects


```
## Superclasses
*none*

## Properties

*none*


## Methods 

| Method | Description |
| --- | --- |
| *documentservice* | create an ndi.documentservice object, which is just an abstract class |
| *newdocument* | create a new ndi.document based on information in this object |
| *searchquery* | create a search query to find this object as an ndi.document |


### Methods help 

**documentservice** - *create an ndi.documentservice object, which is just an abstract class*

```
NDI_DOCUMENTSERVICE_OBJ = ndi.documentservice();
```

---

**newdocument** - *create a new ndi.document based on information in this object*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_DOCUMENTSERVICE_OBJ)
 
  Create a new ndi.document based on information in this class.
 
  The base ndi.documentservice class returns empty.
```

---

**searchquery** - *create a search query to find this object as an ndi.document*

```
SQ = SEARCHQUERY(NDI_DOCUMENTSERVICE_OBJ)
 
  Return a search query that can be used to find this object's representation as an
  ndi.document.
 
  The base class ndi.documentservice just returns empty.
```

---

