package com.ndi;

import java.io.Serializable;
import java.util.Map;
import java.util.Set;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.ArrayList;

public class Table implements Serializable {
    private final Map<String, Map<String, String>> table;
    private final Map<Integer, String> index2colKeys;
    private final Map<Integer, String> index2rowKeys;
    private final Set<String> rowKeys;
    private final Set<String> colKeys;
    private final HashMap<String, Map<String, String>> additionalRowKeysMapping;
    private int primaryIndexColNum;

    /**
     *
     * @param cols          the list of columns for this table
     * @param primaryIndex  the column that will be the primary index for this table
     */
    public Table(List<String> cols, String primaryIndex){
        this.primaryIndexColNum = -1;
        this.additionalRowKeysMapping = new HashMap<>();
        this.table = new HashMap<>();
        this.index2colKeys = new HashMap<>();
        this.index2rowKeys = new HashMap<>();
        this.rowKeys = new HashSet<>();
        this.colKeys = new HashSet<>();
        int index = 0;
        index = 0;
        for (String col : cols){
            if (col.equals(primaryIndex)){
                this.primaryIndexColNum = index;
            }
            index2colKeys.put(index++, col);
            colKeys.add(col);
        }
        if (this.primaryIndexColNum == -1){
            throw new IllegalArgumentException("Your primary index must be one of the columns");
        }
    }

    /**
     *
     * @param tuple
     */
    public void addRow(ArrayList<String> tuple){
        if (tuple.size() != index2colKeys.size()){
            throw new IllegalArgumentException("tuple size must match with the size of the column");
        }
        String rowKey = tuple.get(this.primaryIndexColNum);
        if (rowKey == null){
            throw new IllegalArgumentException("the primary index cannot be null");
        }
        if (rowKeys.contains(rowKey)){
            throw new IllegalArgumentException("the primary index has to be unique");
        }
        int index = 0;
        for (String entry : tuple){
            if (entry == null){
                index ++;
                continue;
            }
            String col = index2colKeys.get(index++);
            Map<String, String> data = new HashMap<>();
            data.put(rowKey, entry);
            this.table.put(col, data);
        }
        this.rowKeys.add(rowKey);
        this.index2rowKeys.put(index2rowKeys.size(), rowKey);
    }

    /**
     *
     * @param rowKey
     * @return
     */
    public boolean isRowKey(String rowKey){
        return this.rowKeys.contains(rowKey);
    }

    /**
     *
     * @param colKey
     * @return
     */
    public boolean isColKey(String colKey){
        return this.colKeys.contains(colKey);
    }

    /**
     *
     * @param colKey
     * @param rowKey
     * @return
     */
    public String getEntry(String colKey, String rowKey){
        return this.table.get(colKey).get(rowKey);
    }

    /**
     *
     * @param colIndex
     * @param rowIndex
     * @return
     */
    public String getEntry(int colIndex, int rowIndex){
        return this.getEntry(this.index2colKeys.get(colIndex), this.index2rowKeys.get(rowIndex));
    }

    /**
     *
     * @param colName
     */
    public void addNewRowKey(String colName){
        Map<String, String> rowKeys = new HashMap<>();
        Map<String, String> column = this.table.get(colName);
        for (String key : column.keySet()){
            if (rowKeys.keySet().contains(column.get(key))){
                throw new IllegalArgumentException("Cannot create index on column that is not unique");
            }
            rowKeys.put(key, column.get(key));
        }
        this.additionalRowKeysMapping.put(colName, rowKeys);
    }

}
