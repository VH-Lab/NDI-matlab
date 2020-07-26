package com.ndi;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * The Rules class represents the set of validation rules that we want our validators
 * to include. Given a tabular data, the Rules class specify which column we want out
 * validator to recognize, and which column we want our validator to give hints to its
 * corresponding entry in the correct column
 */
public class Rules {
    final List<String> correct = new ArrayList<>();
    final List<String> suggestions = new ArrayList<>();
    private final Set<String> correctSet = new HashSet<>();
    private final Set<String> suggestionsSet = new HashSet<>();

    /**
     * Constructor an instance of Rules class from the JSON document. The constructor
     * does not check the JSON document. It is assumed that the EnumFormatValidator
     * constructor will do the document validation before calling this constructor
     *
     * @param input the JSON Object representing the desired fields of the Rules object
     * @return  an instance of Rule class
     */
    static Rules buildFromJSON(JSONObject input){
        Rules output = new Rules();
        JSONArray correctColumns = input.getJSONArray("correct");
        for (int i = 0; i < correctColumns.length(); i++){
            output = output.addExpectedColumn(correctColumns.getString(i));
        }
        if (input.has("suggestions")){
            JSONArray suggestedColumns = input.getJSONArray("suggestions");
            for (int i = 0; i < suggestedColumns.length(); i++){
                output = output.addSuggestedColumn(suggestedColumns.getString(i));
            }
        }
        return output;
    }

    /**
     * Add a column to the list of column that the validators will accept.
     *
     * @param colName   the column our validators will accept
     * @return  an instance of Rules object with a new expected column added
     * @throws IllegalArgumentException if the column has already been added to
     * the suggested list of column, or the expected list of column
     */
    public Rules addExpectedColumn(String colName){
        if (correctSet.contains(colName) || suggestionsSet.contains(colName)){
            throw new IllegalArgumentException("Rules Initialization Error: cannot have duplicate correct columns or overlapping suggestions columns and correct columns");
        }
        correct.add(colName);
        correctSet.add(colName);
        return this;
    }

    /**
     * Add a list columns to the list of column that the validators will accept.
     *
     * @param colName   the column our validators will accept
     * @return  an instance of Rules object with the suggested list of columns added
     * @throws IllegalArgumentException if the any of the column has already
     * been added to the suggested list of column, or the expected list of column
     */
    public Rules addExpectedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addExpectedColumn(eachColName);
        }
        return this;
    }

    /**
     * Add a column to the list of column that the validators will give hints to the
     * corresponding entry in the expected column.
     *
     * @param colName   the column our validators will accept
     * @return  an instance of Rules object with a new suggested column added
     * @throws IllegalArgumentException if the column has already been added to
     * the suggested list of column, or the expected list of column
     */
    public Rules addSuggestedColumn(String colName){
        if (correctSet.contains(colName) || suggestionsSet.contains(colName)){
            throw new IllegalArgumentException("Rules Initialization Error: cannot have duplicate suggested columns or overlapping suggestions columns and correct columns");
        }
        suggestions.add(colName);
        suggestionsSet.add(colName);
        return this;
    }

    /**
     * Add a column to the list of column that the validators will give hints to
     * the corresponding entry in the expected column.
     *
     * @param colName   the list of columns our validators will accept
     * @return  an instance of Rules object with a new suggested column added
     * @throws IllegalArgumentException if the column has already been added to
     * the suggested list of column, or the expected list of column
     */
    public Rules addSuggestedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addSuggestedColumn(eachColName);
        }
        return this;
    }

    /**
     * getter for the correct columns
     *
     * @return  the list of columns that the validators will accept
     */
    public List<String> getCorrectColumns(){
        return this.correct;
    }

    /**
     * getter for the correct columns
     *
     * @return  the list of columns that the validators will suggest
     */
    public List<String> getSuggestedColumns(){
        return this.suggestions;
    }
}
