package com.ndi;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

public class Rules {
    final List<String> correct = new ArrayList<>();
    final List<String> suggestions = new ArrayList<>();
    final Map<String, Integer> col2indexCorrect = new HashMap<>();
    final Map<String, Integer> col2indexSuggestions = new HashMap<>();

    public Rules addExpectedColumn(String colName){
        this.col2indexCorrect.put(colName, correct.size());
        correct.add(colName);
        return this;
    }

    public Rules addExpectedColumns(List<String> colName){
        for (String eachColName : colName){
            this.addExpectedColumn(eachColName);
        }
        return this;
    }

    public Rules addSuggestedColumn(String colName){
        this.col2indexSuggestions.put(colName, suggestions.size());
        suggestions.add(colName);
        return this;
    }

    public Rules addSuggestedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addSuggestedColumn(eachColName);
        }
        return this;
    }

    int convert2ExpectedIndex(String colName){
        return this.col2indexCorrect.get(colName);
    }

    int convert2SuggestedIndex(String colName){
        return this.col2indexSuggestions.get(colName);
    }
}
