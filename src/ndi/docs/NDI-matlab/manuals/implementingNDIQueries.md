# Implementing NDI Queries for Coding Agents

This manual provides instructions for implementing `ndi.query` support in the NDI Cloud API.
The goal is to translate NDI query objects into database queries (e.g., MongoDB, SQL) or to execute them directly against NDI documents stored as JSON.

## 1. NDI Document Structure (JSON)

In the NDI Cloud API, `ndi.document` objects are stored as JSON documents.
Unlike the MATLAB environment where properties are often nested under `document_properties`, the Cloud API stores the document properties at the **root** of the JSON object.

**Example NDI Document (JSON):**

```json
{
  "document_class": {
    "definition": "$NDIDOCUMENTPATH/base.json",
    "validation": "$NDISCHEMAPATH/base_schema.json",
    "class_name": "base",
    "property_list_name": "base",
    "class_version": 1,
    "superclasses": []
  },
  "base": {
    "id": "12345678",
    "session_id": "abcdefgh",
    "name": "my_document",
    "datestamp": "2023-10-27T10:00:00.000Z"
  },
  "depends_on": [
    {
      "name": "subject_id",
      "value": "87654321"
    }
  ]
}
```

## 2. The NDI Query Object

An `ndi.query` object defines search criteria. When serialized or inspected, it contains a structure with four fields:

*   **`field`**: The name of the field to examine (e.g., `'base.name'`).
*   **`operation`**: The comparison operation to perform (e.g., `'exact_string'`).
*   **`param1`**: The first parameter for the operation.
*   **`param2`**: The second parameter for the operation (optional, depends on operation).

### Dotted Fields
Fields with dots (e.g., `'base.id'`) represent nested properties in the JSON object.
*   `'base.id'` -> `doc['base']['id']`
*   `'document_class.class_name'` -> `doc['document_class']['class_name']`

## 3. Primitive Operations

These operations map directly to field comparisons.

| Operation | JSON Implementation |
| :--- | :--- |
| **`regexp`** | Field value matches regular expression in `param1`. |
| **`exact_string`** | Field value equals `param1` (string comparison). |
| **`exact_string_anycase`** | Field value equals `param1` (case-insensitive). |
| **`contains_string`** | Field value contains substring `param1`. |
| **`exact_number`** | Field value equals numerical `param1`. |
| **`lessthan`** | Field value < `param1`. |
| **`lessthaneq`** | Field value <= `param1`. |
| **`greaterthan`** | Field value > `param1`. |
| **`greaterthaneq`** | Field value >= `param1`. |
| **`hasfield`** | Field exists in the JSON document (value is not null/undefined). |
| **`hasmember`** | Field value (array) contains `param1`. |

### Logic Operations
| Operation | JSON Implementation |
| :--- | :--- |
| **`or`** | Matches if query in `param1` OR query in `param2` matches. `param1` and `param2` are themselves query structures (or arrays of them). |

*Note: There is no explicit `and` operation field. A list/array of query structures implies an AND operation between all of them.*

## 4. Macro Operations (Special Handling)

Two operations, `isa` and `depends_on`, are high-level "macros" that must be expanded into primitive operations or implemented with specific logic.

### 4.1. `isa` (Is a Class or Subclass)

Checks if the document is an instance of a specific class or inherits from it.

**Parameters:**
*   `field`: (Empty or ignored)
*   `param1`: The class name (string), e.g., `'ndi.document.base'`.
*   `param2`: (Empty)

**Implementation:**
The `isa` operation is equivalent to an **OR** of two checks:

1.  **Direct Class Match:**
    *   Check if `document_class.definition` **contains** the class name (`param1`).
    *   *Implementation:* `contains_string` on field `'document_class.definition'`.

2.  **Inheritance Match:**
    *   Check if the `document_class.superclasses` array contains an entry where `definition` **contains** the class name (`param1`).
    *   *Implementation:* `hasanysubfield_contains_string` on field `'document_class.superclasses'` with subfield `'definition'`.

**Expansion Logic (Pseudocode):**
```
(
  doc['document_class']['definition'].contains(param1)
  OR
  ANY(item['definition'].contains(param1) for item in doc['document_class']['superclasses'])
)
```

### 4.2. `depends_on` (Dependency Check)

Checks if the document declares a dependency on another document.

**Parameters:**
*   `field`: (Empty or ignored)
*   `param1`: The dependency name (e.g., `'subject_id'`) OR `'*'` (wildcard).
*   `param2`: The dependency value (the ID string).

**Implementation:**
The `depends_on` operation checks the `depends_on` field, which is an array of objects `{ "name": "...", "value": "..." }`.

It is effectively a `hasanysubfield_exact_string` operation on the `depends_on` field.

1.  **If `param1` is NOT `'*'`:**
    *   Check if the `depends_on` array contains an item where:
        *   `item.name` == `param1`
        *   **AND**
        *   `item.value` == `param2`

2.  **If `param1` IS `'*'`:**
    *   Check if the `depends_on` array contains an item where:
        *   `item.value` == `param2`
    *   (Ignore `item.name`)

**Expansion Logic (Pseudocode):**
```
IF param1 != '*':
    ANY(item['name'] == param1 AND item['value'] == param2 for item in doc['depends_on'])
ELSE:
    ANY(item['value'] == param2 for item in doc['depends_on'])
```

## 5. Complex Array Operations

These operations handle searching within arrays of objects.

| Operation | Description |
| :--- | :--- |
| **`hasanysubfield_contains_string`** | `field` must be an array of objects. Checks if ANY object has a subfield `param1` containing string `param2`. |
| **`hasanysubfield_exact_string`** | `field` must be an array of objects. Checks if ANY object has a subfield `param1` exactly matching string `param2`. |

**Note on Arrays in Params:**
If `param1` and `param2` are arrays (lists), then **all** conditions must be met for a single item in the array.
*   Example: `param1=['name', 'value']`, `param2=['ref', '123']`
*   Means: Find an item where (`item.name` contains 'ref' AND `item.value` contains '123').

## 6. Implementation Checklist for Agents

1.  **Parsing:** Ensure the `ndi.query` object is correctly parsed into `field`, `operation`, `param1`, `param2`.
2.  **Field Navigation:** Implement a function to traverse dotted field strings (e.g., `'base.id'`) into the nested JSON structure.
3.  **Macro Expansion:** Detect `isa` and `depends_on` operations and transform them into their composite checks (OR logic for `isa`, array search for `depends_on`).
4.  **Array Handling:** Ensure `hasanysubfield_*` operations correctly iterate over arrays of objects in the JSON.
5.  **Boolean Logic:** Implement `OR` (explicit operator) and `AND` (implicit when combining multiple query criteria).
