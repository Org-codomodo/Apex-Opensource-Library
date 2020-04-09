/**
* MIT License
*
* Copyright (c) 2019 Piotr Kożuchowski
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
 * Base class for selectors. Contains query builder and common query methods.
 */
public inherited sharing abstract class QueryObject {
    private final static Map<SObjectType, SelectorQueryMock> mocks = new Map<SObjectType, SelectorQueryMock>();
    private final static Set<SObjectType> firstInitialization = new Set<SObjectType>();
    private final static QueryCache cache = new QueryCache();

    protected final QueryBuilder query;
    protected final DatabaseService databaseService;

    protected Map<String, SObjectField> allFields;
    private Boolean useCache = true;
    private List<SObjectField> queryFields;
    private Set<SObjectField> cacheFields;
    private SObjectType sObjectType;


    /**
     * Mocks query result for given selector type
     */
    public static void setMock(SObjectType sObjectType, SelectorQueryMock mock) {
        if (Test.isRunningTest()) {
            mocks.put(sObjectType, mock);

        } else {
            throw new QueryException('.setMock() can only be called from test methods');
        }
    }


    protected QueryObject(List<SObjectField> queryFields, SObjectType sObjectType) {
        this.databaseService = new DatabaseService();
        this.query = new QueryBuilder();
        this.query.selectFields(queryFields).fromObject(sObjectType);

        this.allFields = sObjectType.getDescribe().fields.getMap();
        this.queryFields = queryFields;
        this.cacheFields = getFieldsToCacheBy();
        this.sObjectType = sObjectType;

        if (!firstInitialization.contains(sObjectType)) {
            firstInitialization.add(sObjectType);

            cache.put(getFieldsToCacheBy(), getRecordsToCache());
        }
    }


    /*Extenders*/

    /**
     * Query will be executed in "without sharing" context, returning records
     * users does not usually have access to.
     *
     * Since there is no proper way to handle builder pattern with inheritance in Apex,
     * this method should be implemented where it's needed as public XXXSelector withoutCache();
     */
    protected QueryObject withoutSharingImpl() {
        databaseService.setSharing(Sharing.WITHOUT_SHARING);
        return this;
    }


    /**
    * Selector will not use cached records to limit SOQLs query limit.
    *
    * Since there is no proper way to handle builder pattern with inheritance in Apex,
    * this method should be implemented where it's needed as public XXXSelector withoutCache();
    */
    protected QueryObject withoutCacheImpl() {
        this.useCache = false;
        return this;
    }


    /**
    * Selects all fields on the record
    */
    public QueryObject withAllFields() {
        this.query.selectFields(allFields.values());
        return this;
    }


    /*Reductors*/

    /**
     * @return The most recently created record or null if there isn't any.
     */
    public virtual SObject newest() {
        query.setOrderBy('CreatedDate DESC');
        query.setLimit(1);
        return firstOrNull(executeQuery());
    }

    /**
     * @return All records in database
     */
    public virtual SObject[] all() {
        return executeQuery();
    }


    /**
    * @return Record by given Salesforce Id
    */
    public virtual SObject byId(Id recordId) {
        return firstOrNull(byId(new List<Id>{recordId}));
    }

    /**
     * @param recordIds [List<Id>] or [(Iterable<Id>) Set<Id>] or [(Iterable<Id>) List<SObject>]
     * @return Records by given Salesforce Ids
     */
    public virtual SObject[] byId(Iterable<Id> recordIds) {
        return byField('Id', 'IN', recordIds);
    }


    /**
     * @example
     * <pre>
     * List<Account> accounts = Query.Accounts.relatedToChildren(contacts, Contact.AccountId);
     * </pre>
     *
     * @param childRecords List of children records for which oarent records are queried
     * @param relationShipField Parent field on records (ex. Contact.AccountId for Contacts children of Accounts)
     * @return List of parent records related to given child records by given field ex. Accounts related to given contacts
     */
    public virtual SObject[] relatedToChildren(SObject[] childRecords, SObjectField relationShipField) {
        Set<Id> parentIds = new Set<Id>();

        for (SObject record : childRecords) {
            parentIds.add((Id) record.get(relationShipField));
        }

        return byId((Iterable<Id>) parentIds);
    }

    /**
     * @example
     * <pre>
     * List<Contact> contacts = Query.Contacts.relatedToParent(accounts, Contact.AccountId);
     * </pre>
     *
     * @param parentRecords List of child records in relationship
     * @param relationShipField Parent field on records (ex. Contact.AccountId for list of Contacts)
     * @return List of child records related to given parent records by given field
     */
    public virtual SObject[] relatedToParent(SObject[] parentRecords, SObjectField relationShipField) {
        return byField(relationShipField, 'IN', parentRecords);
    }

    /**
     * @return SObject with field equals given value or null
     */
    public virtual SObject oneRecordByField(SObjectField field, String operator, Object value) {
        return firstOrNull(byField(field, operator, value));
    }

    /**
     * @value Expected value or values (may be Set or List) of the field
     * @return SObjects with field values in given value set.
     */
    public virtual SObject[] byField(SObjectField field, String operator, Object value) {
        return byField('' + field, operator, value);
    }

    /**
     * @value Expected value or values (may be Set or List) of the field
     * @return SObjects with field values in given value set.
     */
    public virtual SObject[] byField(String fieldAPIName, String operator, Object value) {
        SObjectField field = allFields.get(fieldAPIName);

        if (canUseCache(operator, field)) {
            return getCachedRecords(field, operator, value);

        } else {
            this.query.setWhere(fieldAPIName + ' ' + operator + ' :value');
            this.query.bindVariable('value', value);
            return executeQuery();
        }
    }

    /**
    * @return True, if selector can use cached records:
    * - Cache is not explicitly forbidden
    * - Operator is either equals or IN
    * - Field is explicitly allowed for caching or Field is unique to use it for upsert (isIdLookup)
    */
    private Boolean canUseCache(String operator, SObjectField field) {
        return useCache
                && (operator == '=' || operator == 'IN')
                && cacheFields.contains(field);
    }

    /**
    * @return All records that are in cache and queries these which are not.
    */
    private SObject[] getCachedRecords(SObjectField field, String operator, Object value) {
        Map<Id, SObject> result = new Map<Id, SObject>();
        Iterable<Object> iterable = getIterable(field, value);

        String runtimeValueName = Runtime.getRunningTypeName(iterable).substringBetween('<', '>');
        List<Object> remainingValues = Runtime.newListOfItemType(Type.forName(runtimeValueName));


        Iterator<Object> valueIt = iterable.iterator();
        while (valueIt.hasNext()) {
            Object val = valueIt.next();

            if (cache.containsKey(field, val)) {
                SObject record = cache.get(field, val);
                result.put(record.Id, record);

            } else {
                remainingValues.add(val);
            }
        }


        if (!remainingValues.isEmpty()) {
            this.query.setWhere('' + field + ' ' + operator + ' :value');
            this.query.bindVariable('value', remainingValues);
            result.putAll(executeQuery());
        }

        return result.values();
    }

    /**
    * Transforms value into uniform iterable:
    * - primitive V is transformed into new List<T>{V}
    * - List or Sets are casted into Iterable<Object>
    * - SObject[] is changed into Iterable<Id>
    */
    private Iterable<Object> getIterable(SObjectField field, Object value) {
        if (value == null) {
            List<Object> values = Runtime.newListOfFieldType(field);
            values.add(value);
            return values;

        } else {
            String typeName = Runtime.getRunningTypeName(value);

            if (value instanceof SObject[]) {
                return (Iterable<Object>) new Map<Id, SObject>((SObject[]) value).keySet();

            } else if (typeName.contains('List') || typeName.contains('Set')) {
                return ((Iterable<Object>) value);

            } else {
                List<Object> values = Runtime.newListOfFieldType(field);
                values.add(value);
                return values;
            }
        }
    }


    /**
    * Fields returned by this method will be used to cache records.
    * Whenever possible, selector will use cached fields to
    */
    protected virtual Set<SObjectField> getFieldsToCacheBy() {
        return new Set<SObjectField>();
    }

    /**
    * These records will be cached at first initialization of the selector:
    * Example use-cases:
    * - caching all Profiles / UserRoles / Permission Sets to reduce soql limits against these
    * setup objects to 1 during whole transaction
    */
    protected virtual List<SObject> getRecordsToCache() {
        return new List<SObject>();
    }


    /**
     * @return First record in list or null if list is empty
     */
    protected SObject firstOrNull(SObject[] records) {
        return records.isEmpty() ? null : records.get(0);
    }


    /**
    * Executes query and caches results
    */
    protected SObject[] executeQuery() {
        if (mocks.containsKey(this.sObjectType)) {
            return mockResponse();

        } else {
            SObject[] records = this.databaseService.query(query.toSOQL(), query.getVariables());
            cache.put(cacheFields, records);

            return records;
        }
    }


    /**
    * This method checks context of execution (which class called selector, in which method,
    * what method on which selector etc.) and mocks the response.
    */
    private SObject[] mockResponse() {
        String selectorName = Runtime.getRunningTypeName(this);
        String selectorMethod, caller, callerMethod;

        for (Runtime.StackTraceLine line : Runtime.getStackTrace()) {
            if (line.apexClass == selectorName || line.apexClass == QueryObject.class.getName()) {
                selectorMethod = line.method;

            } else if (String.isNotBlank(selectorMethod)) {
                caller = line.apexClass;
                callerMethod = line.method;
            }
        }

        SelectorQueryMock mock = mocks.get(this.sObjectType);
        return mock.handleQuery(
                caller,
                callerMethod,
                selectorName,
                selectorMethod,
                query.getVariables(),
                databaseService.query(query.toSOQL(), query.getVariables())
        );
    }

    /**
    * @return selector cache for protected records.
    */
    protected QueryCache getCache() {
        return cache;
    }
}