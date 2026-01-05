# **NDI Pipeline Manager & Calculator GUI: User Manual**

## **1\. Introduction**

The **NDI Pipeline Manager** is a graphical interface designed to streamline the creation, editing, and execution of data analysis pipelines. It allows users to chain together multiple **Calculator Instances**, customize their parameters using MATLAB code, and automatically generate paper-ready figures from NDI sessions.

## **2\. Getting Started**

### **2.1 Prepare NDI Session Data**

Before using the NDI Pipeline GUI, your data must be prepared for utilization with NDI. This may include performing spike detection and sorting if you are working with extracellular recording data. Once your data has been processed and organized, you can write the output to NDI (follow NDI tutorial?). In order for the Calculators to run, you will need to have previously run the decode\_stimuli and calculate\_stimulus\_responses. After this initial processing, you will be ready to run Calculators and create Pipelines of customized Calculator instances. 

Prepare an NDI Data Session to be operated on by your created pipeline by running:   
S \= ndi.session.dir(my\_session\_path);

You can open as many NDI Data Sessions as you wish to work with (just make sure they are stored under different names). Any Data Session that exists in the Workspace will be accessible by the Pipeline GUI.   

### **2.2 Opening the Interface**

To launch the Pipeline Manager, run the following command in the MATLAB Command Window: 

ndi.cpipeline.edit

This will open the main **Pipeline Manager** window.

---

## **3\. The Pipeline Manager Interface**

The main window is divided into three primary sections:

1. **Top Controls (Pipeline & Data Selection)**  
   * **Select Pipeline:** A dropdown menu to switch between different saved pipelines.  
   * **NDI Data:** A dropdown to link a specific NDI Session variable (currently in your MATLAB workspace) to the pipeline. You must have an `ndi.session` object loaded in your workspace for it to appear here.  
2. **Calculator List (The Center Panel)** This area displays the sequence of calculators in the current pipeline.  
   * **Calculator Instance:** The name of the specific calculator (e.g., `MyContrastCalc`).  
   * **Parameter Setup Code:** A dropdown to select which parameter file to use (e.g., `Default`, `Example`, or a custom saved parameter set).  
   * **Order:** Shows the execution order. You can change these numbers to reorder steps.  
   * **Figure Output:** If checked, the pipeline will display figures for this calculator after running.  
3. **Action Buttons (Bottom)**  
   * **Pipeline Controls:** `New Pipeline`, `Delete Pipeline`.  
   * **Calculator Instance Controls:** `New Calculator`, `Delete Calculator`, `Edit Calculator`.  
   * **Run Button:** A large green button to execute the full pipeline of ordered Calculator Instances with customized Parameter Setup Code.

---

## **4\. Creating a New Pipeline**

1. Click the **New Pipeline** button.  
2. A file dialog will appear. Enter a name for your new Pipeline. Click ‘OK’ to save your new Pipeline. The default saving location for your Pipelines will be \~/Documents/MATLAB/Documents/NDI/My Pipelines  
3. Within My Pipelines , there will be two directories.   
   1. Calculator\_Parameters , which contains subdirectories associated with each Calculator class once that Calculator has been added to any of your Pipelines. These Calculator class subdirectories contain .json files which correspond to the Parameter Setup Code created for each Calculator class. This will automatically include Default Parameter Setup Code, and Example Parameter Setup Code for each Calculator class. Any user-created Parameter Setup Code will be saved here.  
   2. Pipelines , which contains subdirectories associated with each created Pipeline. Each Pipeline subdirectory will contain a pipeline.json file that stores the Calculator instances and most recently used Parameter Setup Code for the user to load and share their created and customized Pipelines.   
4. The new pipeline will be created and available to select in the "Select Pipeline" dropdown. You can now add Calculator instances to your Pipeline.

---

## **5\. Adding and Configuring Calculator Instances** 

### **5.1 Adding a Calculator**

1. Click **New Calculator**.  
2. A list of available NDI Calculator classes will appear. Select the desired class (e.g., `ndi.calc.vis.contrast_tuning`).  
3. Enter a unique **Name** for this instance (e.g., `V1_Contrast_Tuning`).  
4. The calculator will appear in the list.

### **5.2 Configuring Parameters**

By default, a new calculator has two parameter options in the dropdown: 

* **Default:** Calls the Calculator class’ default\_search\_for\_input\_parameters() (Read-only).  
* **Example:** Based on the source code, often containing pre-filled queries derived from the Calculator class’ default\_parameters\_query (Editable).

To view Parameter Setup Code and create custom Parameter Setup Code, click **Edit Calculator**.

---

## **6\. Editing Calculator Parameters**

Clicking **Edit Calculator** opens the **Calculator Editor Window**. This window allows you to write the MATLAB code that defines how the calculator finds inputs.

### **6.1 Documentation**

The top window contains Documentation information, defined by each Calculator class. You can view General documentation on what operations the Calculator object performs, Calculator Input Options, and fields contained by Output Documents.

### **6.2 The Code Editor**

The large text box contains MATLAB code. You may choose to view and/or edit the Example Parameter Setup Code, or create your own user-defined Parameter Setup Code. You are primarily defining two variables:

1. `thecalc`: The calculator object.  
2. `parameters`: A structure defining inputs (usually via `ndi.query`).

Define your inputs based on the desired analysis you want the Calculator to perform. A Template Parameter Setup Code is provided for the user to create edits from. You may also edit the Example code directly.

Once you have edited the existing Parameter Setup Code to create your own, click ‘Save As’ and name your new Parameter Setup Code. This will be saved under the Calculator class subdirectory within Calculator\_Parameters. Hit ‘Refresh’ to make sure both the Edit Calculator window and Pipeline Manager window recognize the new Parameter Setup Code. It should appear in the dropdown menu for you to further customize, and implement with your Calculator instance. Any changes made to existing Parameter Setup Code should be saved by clicking ‘Save’. You can delete existing Parameter Setup Code by selecting that code name from the dropdown menu and clicking ‘Delete’. The ‘Exit’ button will close the window and return you to the Pipeline Manager window. 

### **6.3 Testing Your Code (The Commands Menu)**

Before running the full pipeline, you can use the **Commands** dropdown in the Editor window to verify your code works and test individual parts of the Calculator with the selected Parameter Setup Code.

* **Try searching for inputs:** Runs your code and checks if the `parameters.query` actually finds documents in the linked NDI session.  
* **Show existing outputs:** Checks if this calculator has *already* produced results in the database and opens them in the Variable Editor.  
* **Plot existing outputs:** Generates plots for results already in the database (useful for tweaking plot settings without re-calculating). If this command is run, you will be prompted to choose whether you would like outputs presented as individual figures, or generate subplots.   
* **Run but don't replace:** Performs a dry run of the calculation.  
* **Run and replace:** Runs the Calculator instance with selected Parameter Setup Code to generate and/or update documents in the NDI database.

---

## **7\. Running the Pipeline**

1. **Link Data:** Ensure an `ndi.session` object is loaded in your MATLAB workspace (e.g., named `S`). Select `S` from the **NDI Data** dropdown in the Pipeline Manager.  
2. **Check Figures:** Check the **Figure Output** box for any steps where you want to see visual results immediately.  
3. **Click RUN PIPELINE.**

### **The Execution Process**

* A progress bar will appear showing the current step.  
* The pipeline will sequentially load the parameters, find the input documents, and run the calculation.  
* **Plotting:** If "Figure Output" was checked, a popup will ask if you want **Individual Figures** (one window per document) or **Subplots** (batched figures).

---

## **8\. Tips and Troubleshooting**

* **"Parameters structure is empty":** This usually means there is a syntax error in your parameter code in the Edit Window, or you cleared the `parameters` variable by mistake.  
* **No Documents Found:** Use the **Try searching for inputs** command in the Edit Window to debug your `ndi.query`. Ensure your spelling matches the metadata in your NDI files.  
* **Saving Work:** The pipeline structure (order, selected parameters) saves automatically when you make changes in the Pipeline Manager. Parameter code must be saved manually using the **Save** buttons in the Edit Window.

