# Manual: Writing ndi.calculator Objects

## Overview

An `ndi.calculator` is a mini-app in the NDI (Neuroscience Data Interface) system that performs computations on data and stores the results as NDI documents in a database. Calculators enable reproducible, traceable analysis by:

- Defining clear input parameters and dependencies
- Storing computational results with full provenance
- Allowing queries to find and reuse existing calculations
- Supporting both simple and complex multi-step analyses

## Repository Structure

External calculators (those not in the core NDI-matlab repository) are typically organized in repositories following the naming convention **`NDIcalc-REPONAME-matlab`**, where `REPONAME` describes the domain or purpose of the calculators. For example:

- `NDIcalc-vis-matlab` - Calculators for vision research
- `NDIcalc-extracellular-matlab` - Calculators for extracellular recordings (future)

### Standard Folder Structure

Each calculator repository contains three main folders:

```
NDIcalc-REPONAME-matlab/
├── +ndi/
│   └── +calc/
│       └── +category/
│           ├── docs/
│           │   ├── calculator1.docs.general.txt
│           │   ├── calculator1.docs.output.txt
│           │   ├── calculator1.docs.searching.txt
│           │   ├── calculator2.docs.general.txt
│           │   ├── calculator2.docs.output.txt
│           │   ├── calculator2.docs.searching.txt
│           │   └── ...
│           ├── calculator1.m
│           ├── calculator2.m
│           └── ...
├── ndi_common/
│   ├── database_documents/
│   │   └── calc/
│   │       ├── calculator1_calc.json
│   │       ├── calculator2_calc.json
│   │       └── ...
│   └── schema_documents/
│       └── calc/
│           ├── calculator1_calc_schema.json
│           ├── calculator2_calc_schema.json
│           └── ...
└── docs/
```

**Key directories**:

- **`+ndi/+calc/`** - Contains the MATLAB calculator class files organized by category (e.g., `+vis`, `+extracellular`)
- **`ndi_common/database_documents/calc/`** - Contains JSON files that define the structure of blank calculator output documents
- **`ndi_common/schema_documents/calc/`** - Contains JSON schema files for validating calculator documents

This structure ensures consistency across calculator packages and allows NDI to automatically discover and validate calculator document types.

## Architecture

Each calculator consists of two main components:

1. **MATLAB Class File** - The code that performs calculations (`.m` file)
2. **JSON Document Definition** - The database schema for storing results (`.json` file)

## Required Components

### 1. Class File Structure

Your calculator class must:
- Inherit from `ndi.calculator`
- Implement required methods:
  - `constructor(session)` - Initialize the calculator
  - `calculate(parameters)` - Perform the computation
  - `default_search_for_input_parameters()` OR `default_parameters_query()` - Define default search logic

**Location**: `+ndi/+calc/+[category]/[calculator_name].m`

Example categories: `+vis`, `+extracellular`, `+example`

### 2. JSON Document Definition

Defines the structure of the output document, including:
- Document metadata (class name, version, superclasses)
- Dependencies (what documents this calculator depends on)
- Input parameters (configuration values)
- Output fields (results to be stored)

**Location**: `ndi_common/database_documents/calc/[calculator_name]_calc.json`

### 3. JSON Schema Definition (Optional)

A JSON schema file validates the structure of calculator documents, ensuring they conform to the expected format. While optional, schemas are recommended for production calculators.

**Location**: `ndi_common/schema_documents/calc/[calculator_name]_calc_schema.json`

The schema defines validation rules for all fields in your calculator document. Refer to existing schema files in the repository for examples.

### 4. Calculator Documentation Files

This section describes the structure and content of the documentation files required for each calculator class in the `ndi.calc.X` package, where X is any namespace.

#### File Structure

For each calculator class `ndi.calc.X.CALCULATOR_NAME.m`, there must be a corresponding `docs` directory at `+ndi/+calc/+X/docs/`. Inside this directory, three text files are required for each calculator:

1.  `CALCULATOR_NAME.docs.general.txt`
2.  `CALCULATOR_NAME.docs.output.txt`
3.  `CALCULATOR_NAME.docs.searching.txt`

#### 1. General Documentation (`*.docs.general.txt`)

This file should provide a high-level overview of what the calculator computes.

**Content Instructions:**
*   **Description:** Briefly explain the purpose of the calculator. What scientific or data analysis problem does it solve?
*   **Methodology:** Mention the algorithms or mathematical models used.
*   **References:** Cite relevant scientific papers or standard methods (e.g., "Naka and Rushton 1966", "Mazurek et al. 2014").
*   **Formulas:** Include the key mathematical formulas for any fits performed.
    *   Define the equation (e.g., `R(c) = Rm*c/(C50+c)`).
    *   List and define the parameters used in the equation.

#### 2. Output Documentation (`*.docs.output.txt`)

This file details the structure of the output document generated by the calculator.

**Content Instructions:**
*   **Document Type:** State the specific NDI document type produced (e.g., `'ndi_calculation_contrasttuning'`).
*   **Superclasses:** List any superclasses the output document inherits from (e.g., `ndi_document`, `ndi_document_app`).
*   **Fields Description:** Systematically list and describe the fields in the output document structure. Organize them by top-level categories such as:
    *   `properties`: Basic metadata like units or response type.
    *   `tuning_curve`: The core data vectors (independent variable, mean response, error bars, etc.).
    *   `significance`: Statistical test results (p-values).
    *   `fitless`: Metrics calculated without a model fit (e.g., interpolated values, circular variance).
    *   `fit`: Parameters and quality metrics for any model fits performed.
*   **Field Details:** For each field, provide a clear description of what it represents, including units or dimensions where applicable (e.g., "The set of contrast values (vector, 1 x number of contrasts shown)").

#### 3. Searching Documentation (`*.docs.searching.txt`)

This file explains how the calculator identifies the input documents it needs to process.

**Content Instructions:**
*   **Default Search Criteria:** Describe the default query parameters.
    *   What input document type is it looking for (e.g., `stimulus_tuningcurve`)?
    *   What specific fields or labels identify the correct input (e.g., `independent_variable_label` must be 'contrast')?
*   **Modifying the Search:** Explain how a user can customize the search query.
*   **Example:** Provide a code snippet showing how to restrict the search, for example, to a specific element ID.

```matlab
% Example: Only perform the operation on the element called myelement
DQ = c.default_search_for_input_parameters();
DQ.query = DQ.query & ndi.query('','depends_on','element_id',myelement);
c.run('Replace',DQ);
```

## Step-by-Step Guide

### Step 1: Plan Your Calculator

Before coding, determine:

1. **Input**: What documents/elements does your calculator need?
   - Examples: spike times, stimulus information, element epochs

2. **Parameters**: What configuration values are needed?
   - Examples: time windows, thresholds, filter settings

3. **Output**: What results will be stored?
   - Examples: tuning curves, statistics, waveforms

4. **Binary Data**: Will you store large data files?
   - Examples: spike waveforms, images, time series

5. **Granularity**: One document per analysis, or multiple documents?
   - Important: NDI documents cannot be updated, only deleted and recreated
   - If you'll add more data later, create separate documents (e.g., one per epoch)

### Step 2: Create the JSON Document Definition

Start from the simple template (`simple_calc.json`) and customize:

```json
{
    "document_class": {
        "definition": "$NDICALCDOCUMENTPATH/calc/my_calculator_calc.json",
        "validation": "$NDICALCSCHEMAPATH/calc/my_calculator_calc_schema.json",
        "class_name": "my_calculator_calc",
        "property_list_name": "my_calculator_calc",
        "class_version": 1,
        "superclasses": [
            { "definition": "$NDIDOCUMENTPATH/base.json" },
            { "definition": "$NDIDOCUMENTPATH/app.json" }
        ]
    },
    "depends_on": [
        { "name": "element_id", "value": 0 }
    ],
    "my_calculator_calc": {
        "input_parameters": {
            "param1": 0.001,
            "param2": 100
        },
        "output_field1": [],
        "output_field2": []
    }
}
```

**Key fields**:
- `depends_on` - Documents this calculator requires (by their IDs)
- `input_parameters` - Configuration values with defaults
- Additional fields - Your output results (initialize with appropriate defaults)

**Optional**: Add `"files"` section if storing binary data:
```json
"files": {
    "file_list": [ "mydata.bin" ]
}
```

### Step 3: Create the MATLAB Class

#### 3.1 Constructor

```matlab
classdef my_calculator < ndi.calculator

    methods
        function obj = my_calculator(session)
            % MY_CALCULATOR - calculator that does [description]
            %
            % OBJ = MY_CALCULATOR(SESSION)
            %
            % Creates a MY_CALCULATOR ndi.calculator object
            %

            % Call superclass constructor with document type info
            obj = obj@ndi.calculator(session, 'my_calculator_calc');
        end
```

**Key points**:
- First argument to superclass: document type name (without `.json`)
- The calculator automatically locates the JSON definition file based on the document type name (ensure the JSON file is in the standard `ndi_common/database_documents/calc/` location).

#### 3.2 Calculate Method

The `calculate()` method receives a `parameters` object with two key fields:

**Parameters Structure**:
- **`input_parameters`** - A structure containing parameters that modify the calculation (e.g., time windows, thresholds, filter settings). These are configuration values that don't depend on other documents.

- **`depends_on`** - A structure array with `name` and `value` fields containing the document IDs that this calculation depends on. Each entry represents a matched document from the database query (e.g., element_id, stimulus_id, epoch_id). The `value` field contains the document's base ID.

**Accessing Dependencies**:

To extract a specific dependency ID from the `depends_on` array, use `did.db.struct_name_value_search()`:

```matlab
% Extract element_id from depends_on
element_id = did.db.struct_name_value_search(parameters.depends_on, 'element_id');

% Extract stimulus_tuningcurve_id from depends_on
tuning_id = did.db.struct_name_value_search(parameters.depends_on, 'stimulus_tuningcurve_id');
```

This function searches the structure array for the matching `name` and returns the corresponding `value`.

**Example Implementation**:

```matlab
        function doc = calculate(ndi_calculator_obj, parameters)
            % CALCULATE - perform the calculation
            %
            % DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
            %
            % Creates a my_calculator_calc document given input parameters.
            %

            % Validate inputs
            if ~isfield(parameters, 'input_parameters')
                error('parameters structure lacks ''input_parameters''.');
            end
            if ~isfield(parameters, 'depends_on')
                error('parameters structure lacks ''depends_on''.');
            end

            % Step 1: Extract dependencies
            element_id = did.db.struct_name_value_search(...
                parameters.depends_on, 'element_id');
            % now do something with the dependency,
            %maybe create an object or load some information
            element = ndi.database.fun.ndi_document2ndi_object(...
                element_id, ndi_calculator_obj.session);

            % Step 2: Perform your calculation
            result = your_analysis_function(element, ...
                parameters.input_parameters);

            % Step 3: Build output structure
            output = parameters;  % Start with input parameters
            output.output_field1 = result.data1;
            output.output_field2 = result.data2;

            % Step 4: Create NDI document
            doc = ndi.document(...
                ndi_calculator_obj.doc_document_types{1}, ...
                'my_calculator_calc', ...
                output);

            % Step 5: Set dependencies if your document needs them
            %  most will, to store the provenance of the calculation
            for i = 1:numel(parameters.depends_on)
                doc = doc.set_dependency_value(...
                    parameters.depends_on(i).name, ...
                    parameters.depends_on(i).value);
            end

            % Optional: Add binary files
            % doc = doc.add_file('mydata.bin', full_path_to_file);
        end
```

**Key points**:
- Always validate that `input_parameters` and `depends_on` exist
- Use `did.db.struct_name_value_search()` to extract dependency values
- Start output structure with `parameters` to preserve input info
- Use `ndi_calculator_obj.doc_document_types{1}` for document type
- Document property name (3rd arg) must match JSON definition

#### 3.3 Default Search Parameters

Either or both of `default_search_for_input_parameters` or `default_parameters_query` must be overridden in order for the calculator to have a default method to find documents to operate on.

```matlab
        function parameters = default_search_for_input_parameters(...
                ndi_calculator_obj)
            % DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default search parameters
            %
            % PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
            %
            % Returns default search parameters for finding inputs.
            %

            % Set default input parameters
            parameters.input_parameters = struct(...
                'param1', 0.001, ...
                'param2', 100);

            % Initialize empty depends_on structure
            parameters.depends_on = did.datastructures.emptystruct(...
                'name', 'value');

            % Define query to find appropriate input documents
            parameters.query = struct('name', 'element_id', ...
                'query', ndi.query('element.type', 'exact_string', ...
                'spikes', ''));
        end
```

**Key points**:
- `input_parameters` - Default values for your parameters
- `depends_on` - Use `emptystruct()` to create proper structure
- `query` - Defines how to search for input documents
  - `name` - Which dependency to search for
  - `query` - `ndi.query` object specifying search criteria

### Step 4: Optional Methods

#### 4.1 Custom Query Logic

If you need more complex queries:

```matlab
        function query = default_parameters_query(...
                ndi_calculator_obj, parameters_specification)
            % DEFAULT_PARAMETERS_QUERY - custom query logic
            %
            % Allows combining multiple queries with AND/OR logic
            %

            q1 = ndi.query('', 'isa', 'stimulus_tuningcurve', '');
            q2 = ndi.query('stimulus_tuningcurve.independent_variable_label', ...
                'contains_string', 'contrast', '');
            q3 = ndi.query('stimulus_tuningcurve.independent_variable_label', ...
                'contains_string', 'Contrast', '');

            % Combine queries: | for OR, & for AND
            q_combined = q1 & (q2 | q3);

            query = struct('name', 'stimulus_tuningcurve_id', ...
                'query', q_combined);
        end
```

#### 4.2 Input Validation

For additional validation beyond queries:

```matlab
        function b = is_valid_dependency_input(...
                ndi_calculator_obj, name, value)
            % IS_VALID_DEPENDENCY_INPUT - validate potential inputs
            %
            % B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATOR_OBJ, NAME, VALUE)
            %
            % Returns true if the document with id VALUE is valid for
            % dependency NAME.
            %

            b = 1;  % Default to true

            switch lower(name)
                case 'stimulus_tuningcurve_id'
                    % Custom validation logic
                    q = ndi.query('base.id', 'exact_string', value, '');
                    d = ndi_calculator_obj.session.database_search(q);
                    if ~isempty(d)
                        d = d{1};
                        % Check specific conditions
                        b = numel(d.document_properties...
                            .independent_variable_label) == 1;
                    end
                otherwise
                    b = 1;
            end
        end
```

#### 4.3 Binary Data Loading

If your calculator stores binary files:

```matlab
        function [data1, data2] = load(ndi_calculator_obj, doc)
            % LOAD - load binary data from document
            %
            % [DATA1, DATA2] = LOAD(NDI_CALCULATOR_OBJ, DOC)
            %
            % Loads binary data associated with document DOC.
            %

            % Convert doc_id to document if needed
            if ~isa(doc, 'ndi.document')
                doc = ndi_calculator_obj.session.database_search(...
                    ndi.query('base.id', 'exact_string', doc));
            end

            % Open binary file
            myfile = ndi_calculator_obj.session.database_openbinarydoc(...
                doc, 'mydata.bin');

            % Read data using appropriate format
            [data1, data2] = your_read_function(myfile);

            % Close file
            ndi_calculator_obj.session.database_closebinarydoc(myfile);
        end
```

#### 4.4 Plotting Results

For visualizing calculator output:

```matlab
        function h = plot(ndi_calculator_obj, doc_or_parameters, varargin)
            % PLOT - visualize calculator results
            %
            % H = PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
            %
            % Produces a diagnostic plot of the results.
            %

            % Call superclass to set up axes
            h = plot@ndi.calculator(ndi_calculator_obj, ...
                doc_or_parameters, varargin{:});

            if isa(doc_or_parameters, 'ndi.document')
                doc = doc_or_parameters;
            else
                error('Plotting requires an ndi.document.');
            end

            % Extract data
            data = doc.document_properties.my_calculator_calc;

            % Create plots
            hold on;
            plot(data.x, data.y, 'b-', 'linewidth', 2);

            % Add labels if not suppressed
            if ~h.params.suppress_x_label
                h.xlabel = xlabel('X Label');
            end
            if ~h.params.suppress_y_label
                h.ylabel = ylabel('Y Label');
            end
            if ~h.params.suppress_title
                h.title = title('My Calculator Results');
            end

            box off;
        end
```

## Usage Examples

### Running a Calculator

```matlab
% Create session
session = ndi.session('my_experiment');

% Create calculator
calc = ndi.calc.category.my_calculator(session);

% Option 1: Use default parameters
docs = calc.run('Replace');

% Option 2: Custom parameters
params = calc.default_search_for_input_parameters();
params.input_parameters.param1 = 0.002;
docs = calc.run('Replace', params);

% Option 3: Search for specific inputs
params.query.query = params.query.query & ...
    ndi.query('element.reference', 'exact_number', 1, '');
docs = calc.run('Replace', params);
```

### Querying Calculator Results

```matlab
% Find all calculator documents
q = ndi.query('', 'isa', 'my_calculator_calc', '');
docs = session.database_search(q);

% Find for specific element
q1 = ndi.query('', 'isa', 'my_calculator_calc', '');
q2 = ndi.query('', 'depends_on', 'element_id', element_doc_id);
docs = session.database_search(q1 & q2);

% Access results
doc = docs{1};
results = doc.document_properties.my_calculator_calc;
value1 = results.output_field1;
```

## Best Practices

### 1. Naming Conventions
- **Class file**: lowercase with underscores (e.g., `spike_shape.m`)
- **Document type**: class name + `_calc` (e.g., `spike_shape_calc`)
- **JSON file**: same as document type (e.g., `spike_shape_calc.json`)

### 2. Design Decisions
- **Granularity**: Create separate documents per epoch/trial if data may be added later
- **Dependencies**: Include all documents needed to reproduce the calculation
- **Parameters**: Store all configuration values in `input_parameters`
- **Output**: Store both raw results and derived statistics

### 3. JSON File Location
Ensure your JSON document definition file is named identically to the document type (e.g., `my_calculator_calc.json`) and is placed in the `ndi_common/database_documents/calc/` directory so NDI can locate it automatically.

### 4. Query Construction
- Use `ndi.query()` for database searches
- Combine queries with `&` (AND) and `|` (OR)
- Common query types:
  - `'exact_string'` - Exact match
  - `'contains_string'` - Substring match
  - `'isa'` - Document type check
  - `'depends_on'` - Dependency check
  - `'exact_number'` - Numeric equality

### 5. Error Handling
- Always validate `input_parameters` and `depends_on` exist
- Check that queries return expected number of documents
- Provide informative error messages

### 6. Documentation
- Document all methods with clear help text
- Explain input parameters and their units
- Describe output fields and their meaning
- Include usage examples

## Testing

### Basic Test
```matlab
% Create test session
S = ndi.session.test('test_my_calculator');

% Create calculator and run
calc = ndi.calc.category.my_calculator(S);
docs = calc.run('Replace');

% Verify results
assert(~isempty(docs), 'No documents created');
assert(isfield(docs{1}.document_properties.my_calculator_calc, ...
    'output_field1'), 'Missing output field');
```

### Advanced Testing
For production calculators, implement:
- `generate_mock_docs()` - Create synthetic test data
- `compare_mock_docs()` - Validate results against expected output

When implementing `generate_mock_docs`, you should support two "scopes" for producing mock documents:

*   **`highSNR`**: This scope corresponds to a high signal-to-noise ratio condition (previously known as "standard"). In this scope, the test checks to make sure that the document produced is highly accurate and matches the output one expects.
*   **`lowSNR`**: This scope corresponds to a high noise condition (previously known as "high noise"). In this scope, the test makes sure that a document is produced successfully and that an error is not generated.

See `contrast_tuning.m` lines 281-393 for examples.

## Common Patterns

### Multiple Dependencies
```json
"depends_on": [
    { "name": "element_id", "value": 0 },
    { "name": "stimulus_id", "value": 0 },
    { "name": "element_epoch_id", "value": 0 }
]
```

### Array Outputs
```json
"output_field": []
```
Initialize as empty array, populate in `calculate()`.

### Nested Structures
```matlab
output.results.tuning_curve.mean = [...];
output.results.tuning_curve.stderr = [...];
output.results.statistics.p_value = 0.05;
```

### Binary File Handling
```matlab
% In calculate():
fname = [session.path filesep 'ndiobjects' filesep doc_id '.bin'];
% ... write data to fname ...
doc = doc.add_file('mydata.bin', fname);

% In load():
myfile = session.database_openbinarydoc(doc, 'mydata.bin');
data = fread(myfile, ...);
session.database_closebinarydoc(myfile);
```

## Troubleshooting

### Calculator doesn't find inputs
- Check your `query` in `default_search_for_input_parameters()`
- Verify input documents exist: `session.database_search(query)`
- Check dependency names match JSON definition

### Documents not created
- Verify `calculate()` returns valid `ndi.document` object
- Check all dependencies are set with `set_dependency_value()`
- Ensure JSON definition matches document structure

### Path errors
- Verify JSON file exists at `ndi_common/database_documents/calc/`
- Ensure the JSON filename matches the document type name exactly
- Check MATLAB path includes calculator directory

### Query syntax errors
- Use `ndi.query()` constructor, not raw strings
- Combine with `&` and `|`, not `&&` and `||`
- Field names are case-sensitive

## References

- **Examples**: See `+ndi/+calc/+vis/` in NDIcalc-vis-matlab
- **Base class**: `+ndi/calculator.m` in NDI-matlab
- **Tutorial**: `making_a_new_calculator.md` in NDIcalc-vis-matlab
- **Simple template**: `+ndi/+calc/+example/simple.m` in NDI-matlab

## Summary Checklist

When creating a new calculator:

- [ ] Plan inputs, parameters, outputs, and granularity
- [ ] Create JSON document definition in `ndi_common/database_documents/calc/`
- [ ] Create MATLAB class in `+ndi/+calc/+[category]/`
- [ ] Implement constructor passing the document type name
- [ ] Implement `calculate()` method
- [ ] Implement `default_search_for_input_parameters()` and/or `default_parameters_query` method
- [ ] Add optional methods as needed (plot, load, etc.)
- [ ] Test with real or mock data
- [ ] Create documentation files in `+ndi/+calc/+[category]/docs/`
- [ ] Document all methods and parameters
- [ ] Verify calculator can be run with default parameters
