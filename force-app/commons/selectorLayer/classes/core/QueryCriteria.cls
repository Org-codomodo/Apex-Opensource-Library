/**
* MIT License
*
* Copyright (c) 2020 Piotr Kożuchowski
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

/**
 * Encapsulation for SOQL condition - field, operator and value
 * ex. Account.Name IN (values)
 */
public with sharing class QueryCriteria {
    public String field { get; private set; }
    public String operator { get; private set; }
    public Object value { get; private set; }

    public QueryCriteria(SObjectField field, String operator, Object value) {
        this('' + field, operator, value);
    }

    public QueryCriteria(String field, String operator, Object value) {
        this.field = field;
        this.operator = operator;
        this.value = value;
    }

    public String toString(String valueBinding) {
        return field + ' ' + operator + ' :' + valueBinding;
    }

    public override String toString() {
        return field + ' ' + operator + ' :value';
    }

    public override Integer hashCode() {
        return toString().hashCode();
    }

    public Boolean equals(Object obj) {
        if (obj instanceof QueryCriteria) {
            QueryCriteria other = (QueryCriteria) obj;
            return this.field == other.field
                    && this.operator == other.operator
                    && this.value == other.value;

        } else {
            return false;
        }
    }
}