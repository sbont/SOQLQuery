public interface AcceptsFilter {
    RequiresOperator filter(List<SObjectField> fieldPath);
    RequiresOperator filter(SObjectField field);
}