package com.ndi;

import java.util.ArrayList;
import java.util.List;

public class Rules {
    final List<String> correct = new ArrayList<>();
    final List<String> suggestions = new ArrayList<>();

    public Rules addExpectedColumn(String colName){
        correct.add(colName);
        return this;
    }

    public Rules addExpectedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addExpectedColumn(eachColName);
        }
        return this;
    }

    public Rules addSuggestedColumn(String colName){
        suggestions.add(colName);
        return this;
    }

    public Rules addSuggestedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addSuggestedColumn(eachColName);
        }
        return this;
    }
}
