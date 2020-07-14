package com.ndi;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

public class Rules {
    final List<String> correct = new ArrayList<>();
    final List<String> suggestions = new ArrayList<>();
    private final Set<String> correctSet = new HashSet<>();
    private final Set<String> suggestionsSet = new HashSet<>();

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

    public Rules addExpectedColumn(String colName){
        if (correctSet.contains(colName) || suggestionsSet.contains(colName)){
            throw new IllegalArgumentException("cannot have duplicate correct columns or overlapping suggestions columns and correct columns");
        }
        correct.add(colName);
        correctSet.add(colName);
        return this;
    }

    public Rules addExpectedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addExpectedColumn(eachColName);
        }
        return this;
    }

    public Rules addSuggestedColumn(String colName){
        if (correctSet.contains(colName) || suggestionsSet.contains(colName)){
            throw new IllegalArgumentException("cannot have duplicate correct columns or overlapping suggestions columns and correct columns");
        }
        suggestions.add(colName);
        suggestionsSet.add(colName);
        return this;
    }

    public Rules addSuggestedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addSuggestedColumn(eachColName);
        }
        return this;
    }
}
