package com.ndi;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

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
    private final Map<String, Map<String, List<String>>> additionalRowKeysMapping;
    private int primaryIndexColNum;

    /**
     * Initialize a table. It takes the following two arguments
     *
     * @param cols          the list of columns for this table
     * @param primaryIndex  the column that will be the primary index for this table
     */
    public Table(List<String> cols, String primaryIndex){
        if (cols.size() < 1){
            throw new IllegalArgumentException("Your table must have at least one column");
        }
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
     * Adding a row of entries into the Table.
     *
     * @param tuple  the list of row entries, which should be an instance of java.util.ArrayList.
     *               The size of it also needs to match with the number of columns provided when
     *               constructing the table. Also the ArrayList must ordered in the same way the
     *               original columns are ordered, corresponding to the column each row entry belongs
     *               to. Also the primary row key cannot be null or a IllegalArgumentException will be thrown.
     *               Secondary index is allowed to be null, however, this will mean that we won't be able to
     *               query certain entries using only the secondary row key. Note that secondary index
     *               can contains duplicate entries
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
            String correspondingColumn = index2colKeys.get(index);
            // updating the mapping between secondary indices and the primary index
            if (this.additionalRowKeysMapping.containsKey(correspondingColumn)){
                if (additionalRowKeysMapping.get(correspondingColumn).containsKey(entry)){
                    additionalRowKeysMapping.get(correspondingColumn).get(entry).add(rowKey);
                }
                else{
                    additionalRowKeysMapping.get(correspondingColumn)
                            .put(entry, new ArrayList<>(Collections.singletonList(rowKey)));
                }
            }
            String col = index2colKeys.get(index++);
            if (!this.table.containsKey(col)){
                Map<String, String> data = new HashMap<>();
                data.put(rowKey, entry);
                this.table.put(col,data);
            }
            else{
                this.table.get(col).put(rowKey,entry);
            }
        }
        this.rowKeys.add(rowKey);
        this.index2rowKeys.put(index2rowKeys.size(), rowKey);
    }

    /**
     * check if the provided rowKey is a primary key
     *
     * @param rowKey    the row key
     * @return          if the provided row key is indeed a primary key
     */
    public boolean isRowKey(String rowKey){
        return this.rowKeys.contains(rowKey);
    }

    /**
     * Check if the provided row key is indeed a secondary row key
     *
     * @param rowKey    the secondary row key
     * @param column    the column where the secondary row key is located
     * @return          whether this is a valid secondary row key
     */
    public boolean isSecondaryRowKey(String rowKey, String column){
        return this.additionalRowKeysMapping.containsKey(column)
                && this.additionalRowKeysMapping.get(column).containsKey(rowKey);
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
     * Get the table entry with the provided column key and the row key
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
     * Querying result given a single colKey and a list of rowKeys
     *
     * @param colKey    column key
     * @param rowKeys   a list of row keys
     * @return          a list of querying result
     */
    public List<String> getEntry(String colKey, List<String> rowKeys){
        List<String> result = new ArrayList<>();
        for (String rowKey : rowKeys){
            result.add(getEntry(colKey, rowKey));
        }
        return result;
    }

    /**
     * Get the table entry with the provided column key and row key that is not a
     * primary key, thus we need to specify which column this row key comes from
     *
     * @param colKey            a column key
     * @param secondaryRowKey   a secondary row key
     * @param RowKeyCol         the column this secondary row key is in
     * @return                  querying the entry at column == colKey, row == secondaryRowKey
     */
    public List<String> getEntry(String colKey, String secondaryRowKey, String RowKeyCol){
        if (!this.colKeys.contains(colKey) || !this.colKeys.contains(RowKeyCol))
            throw new IllegalArgumentException("Key does not exist");
        return getEntry(colKey, this.convert2primaryKey(secondaryRowKey, RowKeyCol));
    }

    /**
     * Get the table entry with column number and row number
     *
     * @param colIndex  the column number (starting from 0)
     * @param rowIndex  the row number (starting from 0)
     * @return          the entry in the (colIndex)th column and (rowIndex)th row
     */
    public String getEntry(int colIndex, int rowIndex){
        return this.getEntry(this.index2colKeys.get(colIndex), this.index2rowKeys.get(rowIndex));
    }

    /**
     * Construct index on a particular column for fast searching of an entry based on that column.
     * The column must be one of the column keys, or an IllegalArgumentException will be thrown.
     * Note that this method can only be called when we have at least one row, or an IllegalArgumentException
     * will be thrown.
     *
     * @param colName   the name of the column that we want to create an index for
     */
    public void createIndex(String colName){
        if (this.additionalRowKeysMapping.containsKey(colName)){
            return;
        }
        Map<String, List<String>> rowKeys = new HashMap<>();
        if (!this.table.containsKey(colName)){
            throw new IllegalArgumentException("Attempt to create on index that does not exist");
        }
        Map<String, String> column = this.table.get(colName);
        for (String key : column.keySet()){
            if (rowKeys.containsKey(column.get(key))){
                rowKeys.get(column.get(key)).add(key);
            }
            else{
                rowKeys.put(column.get(key), new ArrayList<>(Collections.singletonList(key)));
            }
        }
        this.additionalRowKeysMapping.put(colName, rowKeys);
    }

    /**
     * When looking up for a particular entry by its column key and a row key that is not a primary
     * row key, it is required to convert the non-primary row key into a primary row key. This method does
     * the appropriate conversion. If the column is not a primary index, this method will call createIndex()
     * on that column However, if the row key does not exist in the provided column, an IllegalArgument Exception
     * will be thrown. This is a private method used internally by the other methods
     *
     * @param row       the non-primary row key
     * @param column    the column this row key appears in
     * @return          the primary row key that match with the non-primary row key
     */
    private List<String> convert2primaryKey(String row, String column){
        if (additionalRowKeysMapping.containsKey(column)){
            if (additionalRowKeysMapping.get(column).containsKey(row)){
                return this.additionalRowKeysMapping.get(column).get(row);
            }
            else{
                throw new IllegalArgumentException("Key does not exist");
            }
        }
        else {
            this.createIndex(column);
            return convert2primaryKey(row, column);
        }
    }

    /**
     * Querying the current size of the table
     *
     * @return an array where the first entry is the number of row, and the
     *         second entry is the number of columns in the table
     */
    public int[] size(){
        return new int[]{this.rowKeys.size(), this.colKeys.size()};
    }
}
