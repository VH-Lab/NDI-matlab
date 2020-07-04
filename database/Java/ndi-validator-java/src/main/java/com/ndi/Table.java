package com.ndi;

import java.io.Serializable;
import java.util.Map;
import java.util.Set;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.ArrayList;

/**
 * Implementation of a table-like object using Hash Table, thus providing effective
 * look-up of entries. The Table class implements the Serializable interface, which allows
 * us to save the Table class into a binary file, thus allowing the Validator to load the
 * needed data more efficiently
 */
public class Table implements Serializable {
    private final Map<String, Map<String, String>> table;
    private final Map<Integer, String> index2colKeys;
    private final Map<Integer, String> index2rowKeys;
    private final Set<String> rowKeys;
    private final Set<String> colKeys;
    private final HashMap<String, Map<String, String>> additionalRowKeysMapping;
    private int primaryIndexColNum;

    /**
     * Initialize a table. It takes the following two arguments
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
     * TODO: Need to take into account adding entries to the non-primary keys
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
            if (entry == null || index == this.primaryIndexColNum){
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
     * check if the provided rowKey is a primary key
     *
     * @param rowKey    the row Key
     * @return          if the provided rowKey is indeed a primary key
     */
    public boolean isRowKey(String rowKey){
        return this.rowKeys.contains(rowKey);
    }

    /**
     *  check if the provided colKey is indeed a colKey
     *
     * @param colKey    the col Key
     * @return          whether this is a column key
     */
    public boolean isColKey(String colKey){
        return this.colKeys.contains(colKey);
    }

    /**
     *
     * @param colKey    thee column name
     * @param rowKey    the primary row key
     * @return          querying the entry at column == colKey and row == rowKey
     */
    public String getEntry(String colKey, String rowKey){
        if (!this.colKeys.contains(colKey) || !this.rowKeys.contains(rowKey))
            throw new IllegalArgumentException("Key does not exist");
        if (colKey.equals(index2colKeys.get(primaryIndexColNum))){
            return rowKey;
        }
        return this.table.get(colKey).get(rowKey);
    }

    /**
     *
     * @param colKey            a column key
     * @param secondaryRowKey   a secondary row key
     * @param RowKeyCol         the column this secondary row key is in
     * @return                  querying the entry at column == colKey, row == secondaryRowKey
     */
    public String getEntry(String colKey, String secondaryRowKey, String RowKeyCol){
        return getEntry(colKey, this.convert2primaryKey(secondaryRowKey, RowKeyCol));
    }

    /**
     *
     * @param colIndex  the column number (starting from 0)
     * @param rowIndex  the row number (starting from 0)
     * @return          the entry in the (colIndex)th column and (rowIndex)th row
     */
    public String getEntry(int colIndex, int rowIndex){
        return this.getEntry(this.index2colKeys.get(colIndex), this.index2rowKeys.get(rowIndex));
    }

    /**
     * Construct index on a particular column for fast search of an entry based on that column.
     * The column must contains unique entries, or an IllegalArgumentException would be thrown.
     *
     * @param colName   the name of the column that we want to create an index for
     */
    public void createIndex(String colName){
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

    /**
     * When looking up for a particular entry by its column key and a row key that is not a primary
     * row key, it is required to convert the non-primary row key first. This method does the appropriate
     * conversion. If the column is not a primary index, this method will call createIndex() on that column
     * However, if the row key does not exist in the provided column, an IllegalArgument Exception will be thrown
     *
     * @param row       the non-primary row key
     * @param column    the column this row key appears in
     * @return          the primary row key that match with the non-primary row key
     */
    private String convert2primaryKey(String row, String column){
        if (additionalRowKeysMapping.containsKey(column)){
            if (additionalRowKeysMapping.get(column).containsKey(row)){
                return this.additionalRowKeysMapping.get(column).get(row);
            }
            else{
                throw new IllegalArgumentException("the rowKey you are trying to query does not exist");
            }
        }
        else {
            this.createIndex(column);
            return convert2primaryKey(row, column);
        }
    }

    /**
     * Some very basic sample usage of this class
     *
     * @param args  console-based argument (not really used)
     */
    public static void main(String[] args){
        ArrayList<String> cols = new ArrayList<>();
        cols.add("name");
        cols.add("id");
        cols.add("year");
        Table tb = new Table(cols, "id");
        ArrayList<String> row1 = new ArrayList<>();
        row1.add("Joe");
        row1.add("36");
        row1.add("2021");
        tb.addRow(row1);
        System.out.println(tb.getEntry(0,0)); //expect Joe
        System.out.println(tb.getEntry("year", "36")); //expect 2021;
    }

}
