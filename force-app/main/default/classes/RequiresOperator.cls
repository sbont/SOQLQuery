public interface RequiresOperator {
    SOQLQueryBuilder equals(Object value);
    SOQLQueryBuilder notEquals(Object value);
    SOQLQueryBuilder lessThan(Object value);
    SOQLQueryBuilder greaterThan(Object value);
    SOQLQueryBuilder equalsOrLess(Object value);
    SOQLQueryBuilder equalsOrMore(Object value);
    SOQLQueryBuilder isLike(Object value);
    SOQLQueryBuilder isIn(Object value);
    SOQLQueryBuilder isNotIn(Object value);
    SOQLQueryBuilder includes(Object value);
    SOQLQueryBuilder excludes(Object value);
}