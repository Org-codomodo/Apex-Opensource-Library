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
@IsTest(IsParallel=true)
public class QueryObjectTest {

    private class TestUserQuery extends QueryObject {
        public override List<String> getFields() {
            return new List<String>{
                    'Id',
                    'Name',
                    'Email',
                    'Username'
            };
        }

        public override SObjectType getSObjectType() {
            return User.SObjectType;
        }

        protected override Set<String> getFieldsToCacheBy() {
            return new Set<String>{
                'Id'
            };
        }
    }

    @IsTest
    static void testSelectById() {
        User user = (User) new TestUserQuery().byId(UserInfo.getUserId()).getFirstOrNull();

        System.assertEquals(UserInfo.getUserId(), user.Id);
        System.assertEquals(UserInfo.getName(), user.Name);
        System.assertEquals(UserInfo.getUserEmail(), user.Email);
    }

    @IsTest
    static void testSelectByIdSObject() {
        User user = (User) new TestUserQuery().byId(new List<User>{
                new User(Id = UserInfo.getUserId())
        }).getFirstOrNull();

        System.assertEquals(UserInfo.getUserId(), user.Id);
        System.assertEquals(UserInfo.getName(), user.Name);
        System.assertEquals(UserInfo.getUserEmail(), user.Email);
    }

    @IsTest
    static void testSelectByField() {
        User user = (User) new TestUserQuery().byField(User.Username, '=', UserInfo.getUserName()).getFirstOrNull();

        System.assertEquals(UserInfo.getUserId(), user.Id);
        System.assertEquals(UserInfo.getName(), user.Name);
        System.assertEquals(UserInfo.getUserEmail(), user.Email);
    }

    @IsTest
    static void testSelectAll() {
        assertEquals(
                ([SELECT Id FROM User]),
                new TestUserQuery().getList()
        );
    }

    @IsTest
    static void testSelectByChild() {
        List<LoginHistory> loginHistories = [SELECT Id, UserId FROM LoginHistory LIMIT 100];
        List<User> users = new TestUserQuery().relatedToChildren(loginHistories, LoginHistory.UserId).getList();

        assertEquals(
                ([SELECT Id FROM User WHERE Id IN (SELECT UserId FROM LoginHistory WHERE Id IN :loginHistories)]),
                users
        );
    }

    @IsTest
    static void testSelectByParent() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<User> users = new TestUserQuery().relatedToParent(profiles, User.ProfileId).getList();

        assertEquals(
                ([SELECT Id FROM User WHERE ProfileId IN :profiles]),
                users
        );
    }

    @IsTest
    static void testSelectOne() {
        User usr = (User) new TestUserQuery().getFirstOrEmpty();
        System.assertNotEquals(null, usr);
    }

    public static void assertEquals(SObject[] expected, SObject[] actual) {
        System.assertEquals(
                new Map<Id, SObject>(expected).keySet(),
                new Map<Id, SObject>(actual).keySet()
        );
    }

    @IsTest
    static void testSelectByCondition() {
        assertEquals(
                ([SELECT Id FROM User WHERE Name = :UserInfo.getUserName()]),
                new TestUserQuery().byCriterion(new QueryCriteria(User.Name, '=', UserInfo.getUserName())).getList()
        );
        assertEquals(
                ([SELECT Id FROM User WHERE Name = :UserInfo.getUserName() AND ProfileId = :UserInfo.getProfileId()]),
                new TestUserQuery().byCriteria(new List<QueryCriteria>{
                        new QueryCriteria(User.Name, '=', UserInfo.getUserName()),
                        new QueryCriteria(User.ProfileId, '=', UserInfo.getProfileId())
                })
                        .getList()
        );
    }

    @IsTest
    static void testCountBy() {
        Integer cnt = (Integer) [SELECT COUNT(Id) cnt FROM User].get(0).get('cnt');
        System.assertEquals(
                cnt,
                new TestUserQuery().getCount()
        );
    }

    @IsTest
    static void coverage() {
        new TestUserQuery()
                .withoutSharing()
                .withoutCache()
                .withEnforcedSecurity()
                .withAllFields()
                .byId(UserInfo.getUserId())
                .getFirstOrNull();

        new TestUserQuery().byId(UserInfo.getUserId()).getCount();
        new TestUserQuery().byId(UserInfo.getUserId()).getCountBy(new List<String>{'' + User.Name});
        new TestUserQuery().byId(UserInfo.getUserId()).getMapById();
        new TestUserQuery().byId(UserInfo.getUserId()).getFirstOrNull();
        new TestUserQuery().byId(UserInfo.getUserId()).getFirstOrEmpty();
        new TestUserQuery().byId(UserInfo.getUserId()).getFirstIdOrNull();
        new TestUserQuery().byId(UserInfo.getUserId()).getQueryLocator();
        new TestUserQuery().byId(UserInfo.getUserId()).getFirstFieldOrNull(User.Name);
        new TestUserQuery().byId(UserInfo.getUserId()).getFirstFieldOrFallback(User.Name, 'fallback value');
    }


    @IsTest
    static void queryBuilderCoverage() {
        new QueryBuilder()
                .addField(Account.Id)
                .addField('Name')
                .addFields(new List<SObjectField>{Account.Id})
                .addFields(new List<String>{'Id'})
                .addChildFields(new List<SObjectField>{Contact.Id}, 'Contacts')
                .fromObject(Account.SObjectType)
                .setWhere('Name != NULL')
                .setGroupBy('Name')
                .setHaving('')
                .setOrderBy('Name')
                .setOffset(0)
                .setLimit(100);
    }
}