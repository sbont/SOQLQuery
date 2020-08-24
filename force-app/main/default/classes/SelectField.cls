public class SelectField implements QueryItem, Comparable {

    private SObjectField field;
    protected SelectField relatedTarget;

    public SelectField(SObjectField field) {
        this.field = field;
    }

    public static SelectField createFromFieldPath(List<SObjectField> fieldPath) {
        SelectField selectField;
        for(SObjectField field : fieldPath) {
            if(selectField == null) {
                selectField = new SelectField(field);
            } else {
                selectField.pointToRelatedField(field);
            }
        }
        return selectField;
    }

    public SObjectField getSObjectField() {
        if(isRelatedField()) {
            return relatedTarget.getSObjectField();
        } else {
            return field;
        }
    }

    // Use as follows: assuming this SelectField's field is a relationship field, provide the field on the related object here
    public SelectField pointToRelatedField(SObjectField field) {
        if(relatedTarget == null) {
            relatedTarget = new SelectField(field);
        } else {
            relatedTarget.pointToRelatedField(field);
        }
        return this;
    }

    public Boolean isRelatedField() {
        return relatedTarget != null;
    }

    public Integer getDepth() {
        if(isRelatedField()) {
            return 1 + relatedTarget.getDepth();
        } else {
            return 0;
        }
    }

    public override String toString() {
        if(isRelatedField()) {
            return field.getDescribe().getRelationshipName() + '.' + relatedTarget.toString();
        } else {
            return String.valueOf(field);
        }
    }

    public Integer compareTo(Object other) {
        if(other instanceof SelectField) {
            SelectField otherTarget = (SelectField) other;
            if(this.getDepth() == otherTarget.getDepth()) {
                if(String.valueOf(this.field) == String.valueOf(otherTarget.field)) {
                    if(getDepth() == 0) {
                        return 0;
                    } else {
                        return this.relatedTarget.compareTo(otherTarget.relatedTarget);
                    }
                } else {
                    return String.valueOf(this.field).compareTo(String.valueOf(otherTarget.field));
                }
            } else {
                return this.getDepth() > otherTarget.getDepth() ? 1 : -1;
            }
        } else {
            return 0;
        }
    }

    public Boolean equals(Object other) {
        if(other instanceof SelectField) {
            SelectField otherField = (SelectField) other;
            return this.compareTo(otherField) == 0;
        } else {
            return false;
        }
    }

    public Integer hashCode() {
        return 31 * String.valueOf(field).hashCode() + (relatedTarget == null ? 0 : relatedTarget.hashCode());
    }

    public SelectField copy() {
        SelectField copy = new SelectField(field);
        if(relatedTarget != null) {
            copy.relatedTarget = relatedTarget.copy();
        }
        return copy;
    }
}