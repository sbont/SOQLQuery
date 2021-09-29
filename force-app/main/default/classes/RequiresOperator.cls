public interface RequiresOperator {
    QueryBuilder equals(Object value);
    QueryBuilder notEquals(Object value);
    QueryBuilder lessThan(Object value);
    QueryBuilder greaterThan(Object value);
    QueryBuilder equalsOrLess(Object value);
    QueryBuilder equalsOrMore(Object value);
    QueryBuilder isLike(Object value);
    QueryBuilder isIn(Object value);
    QueryBuilder isNotIn(Object value);
    QueryBuilder includes(Object value);
    QueryBuilder excludes(Object value);
}