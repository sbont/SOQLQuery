/**
 * Created by StevenBontenbal on 03/03/2021.
 */

public class SortOrder {
    private final SOQLQueryBuilder QueryBuilder;
    private final SObjectField Field;
    private SortDirection direction;
    private NullsOrder order;

    public SortOrder(SObjectField field, SOQLQueryBuilder queryBuilder) {
        this.QueryBuilder = queryBuilder;
        this.Field = field;
    }

    public SortOrder ascending() {
        this.direction = SortDirection.ASCENDING;
        return this;
    }

    public SortOrder descending() {
        this.direction = SortDirection.DESCENDING;
        return this;
    }

    public SortOrder nullsFirst() {
        this.order = NullsOrder.FIRST;
        return this;
    }

    public SortOrder nullsLast() {
        this.order = NullsOrder.LAST;
        return this;
    }

    public String build() {
        return Field
                + (direction == SortDirection.ASCENDING ? ' ASC' : '')
                + (direction == SortDirection.DESCENDING ? ' DESC' : '')
                + (order == NullsOrder.FIRST ? ' NULLS FIRST' : '')
                + (order == NullsOrder.LAST ? ' NULLS LAST' : '');
    }

    private enum SortDirection {
        ASCENDING,
        DESCENDING
    }

    private enum NullsOrder {
        FIRST,
        LAST
    }
}