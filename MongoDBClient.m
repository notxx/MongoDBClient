//
//  MongoDBClient.m
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import "MongoDBClient.h"
#import "mongo.h"
#import "bson.h"

#pragma mark -
#pragma mark Special Mongo objects

@implementation MongoObjectId {
    bson_oid_t _value;
	NSString * _string;
}

+ (instancetype)oidWithString:(NSString*)string {
    const char* chars = [string UTF8String];
    bson_oid_t oid;
    
    bson_oid_from_string(&oid, chars);
    
    return [[MongoObjectId alloc] initWithOid: &oid];
}

- (id) init {
	if (self = [super init]) {
        bson_oid_gen(&_value);
	    char buffer[25];
    	bson_oid_to_string(&_value, buffer);
    	_string = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    }
    return self;
}

- (id) initWithString:(NSString *)string {
	if (self = [super init]) {
		_string = string;
		bson_oid_from_string(&_value, string.UTF8String);
	}
	return self;
}

- (id) initWithOid:(bson_oid_t *)oid {
	if (self = [super init]) {
        memcpy(&_value, oid, sizeof(bson_oid_t));
	    char buffer[25];
    	bson_oid_to_string(&_value, buffer);
    	_string = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    }
    return self;
}

- (id)copyWithZone:(NSZone*) zone {
    MongoObjectId* result = [[self class] allocWithZone:zone];
    memcpy(&result->_value, &_value, sizeof(bson_oid_t));
	result->_string = _string;
    
    return result;
}

- (NSString*) string {
	return _string;
}

- (NSString*) description {
    return [NSString stringWithFormat: @"ObjectId('%@')", _string];
}

- (bson_oid_t*) oid {
    return &_value;
}

- (BOOL) isEqual:(id)object {
    if(object == self) {
        return YES;
    } else if([object isKindOfClass: [MongoObjectId class]]) {
        return memcmp(&_value, [object oid], sizeof(bson_oid_t)) == 0;
    }
    
    return NO;
}

@end

@implementation MongoTimestamp

+(instancetype)timestamp {
	return [[self alloc] initWithDate:[NSDate new]];
}

+(instancetype)timestampWithDate:(NSDate *)date {
	return [[self alloc] initWithDate:date];
}

+(instancetype)timestampWithTimeIntervalSince1970:(NSTimeInterval)interval {
	NSDate * date = [NSDate dateWithTimeIntervalSince1970:interval];
	return [[self alloc] initWithDate:date];
}

-(id)initWithDate:(NSDate *)date {
	if (self = [super init]) {
		_date = date;
	}
	return self;
}

@end

@implementation MongoSymbol

+(instancetype)symbolWithCString:(const char *)s {
	return [self symbolWithString:[[NSString alloc] initWithCString:s encoding: NSUTF8StringEncoding]];
}

+(instancetype)symbolWithString:(NSString *)string {
	return [[self alloc] initWithString:string];
}

-(id)initWithString:(NSString *)string {
	if (self = [super init]) {
		_string = string;
	}
	return self;
}

@end

@implementation MongoUndefined
@end

@implementation MongoRegex {
    NSString* _pattern;
    NSString* _options;
}

@synthesize pattern = _pattern, options = _options;

- (id) initWithPattern:(NSString*)pattern andOptions:(NSString*)options {
    self = [super init];
    if(self) {
        self.pattern = pattern;
        self.options = options;
    }
    return self;
}

@end

#pragma mark -
#pragma mark MongoDBCursor private interface

@interface MongoDbCursor(Private)

//- (id) initWithClient:(MongoDBClient*)client query:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error;
-(id)initWithClient:(MongoDBClient*)client collection:(NSString*)collection withError:(NSError**)error;

@end

#pragma mark -
#pragma mark MongoDBClient private interface

@interface MongoDBClient(Private)

- (mongo*) mongoConnection;

@end

#pragma mark -
#pragma mark BSON stuff

static void add_object_to_bson(bson* b, NSString* key, id obj) {
    const char* key_name = key.UTF8String;
    
    if([obj isKindOfClass: [NSNumber class]]) {
        const char *objCType = [obj objCType];
        switch (*objCType) {
            case 'd':
            case 'f':
                bson_append_double(b, key_name, [obj doubleValue]);
                break;
            case 'l':
            case 'L':
                bson_append_long(b, key_name, [obj longValue]);
                break;
            case 'q':
            case 'Q':
                bson_append_long(b, key_name, [obj longLongValue]);
                break;
            case 'B':
                bson_append_bool(b, key_name, [obj boolValue]);
                break;
            default:
                bson_append_int(b, key_name, [obj intValue]);
                break;
        }
    } else if([obj isKindOfClass: [NSDictionary class]]) {
        bson_append_start_object(b, key_name);
        for(NSString* k in obj) {
            id val = [obj objectForKey: k];
            add_object_to_bson(b, k, val);
        }
        bson_append_finish_object(b);
    } else if([obj isKindOfClass: [NSArray class]]) {
        bson_append_start_array(b, key_name);
        int C = (int)[obj count];
        for(int i=0; i<C; i++) {
            add_object_to_bson(b, [NSString stringWithFormat: @"%d", i], [obj objectAtIndex: i]);
        }
        bson_append_finish_array(b);
    } else if([obj isKindOfClass: [NSDate class]]) {
        bson_date_t millis = (bson_date_t) ([obj timeIntervalSince1970] * 1000.0);
        bson_append_date(b, key_name, millis);
    } else if([obj isKindOfClass: [NSData class]]) {
        bson_append_binary(b, key_name, 0, [obj bytes], (int)[obj length]);
    } else if([obj isKindOfClass: [NSNull class]]) {
        bson_append_null(b, key_name);
    } else if([obj isKindOfClass: [MongoObjectId class]]) {
        bson_append_oid(b, key_name, [obj oid]);
    } else if([obj isKindOfClass: [MongoTimestamp class]]) {
        bson_append_timestamp2(b, key_name, [obj timeIntervalSince1970], 0);
    } else if([obj isKindOfClass: [MongoSymbol class]]) {
        bson_append_symbol(b, key_name, [obj UTF8String]);
    } else if([obj isKindOfClass: [MongoUndefined class]]) {
        bson_append_undefined(b, key_name);
    } else if([obj isKindOfClass: [MongoRegex class]]) {
        MongoRegex* regex = obj;
        bson_append_regex(b, key_name, [regex.pattern UTF8String], [regex.options UTF8String]);
    } else if([obj respondsToSelector: @selector(cStringUsingEncoding:)]) {
        bson_append_string(b, key_name, [obj cStringUsingEncoding: NSUTF8StringEncoding]);
    } else if([obj respondsToSelector: @selector(UTF8String)]) {
        bson_append_string(b, key_name, [obj UTF8String]);
    } else {
        @throw [NSException exceptionWithName: @"CRASH" reason: @"Unhandled object type in BSON serialization" userInfo: [NSDictionary dictionaryWithObject: obj forKey: @"object"]];
    }
}

static void bsonFromDictionary(bson* b, NSDictionary*dict) {
    bson_init(b);
    for (NSString* key in dict) {
        id obj = [dict objectForKey: key];
        add_object_to_bson(b, key, obj);
    }
    bson_finish(b);
}

static void fill_object_from_bson(id object, bson_iterator* it);

static id object_from_bson(bson_iterator* it) {
    id value = nil;
    bson_iterator it2;
    bson subobject;
    bson_timestamp_t timestamp;
    const char* pattern;
    const char* options;
    bson_type type = bson_iterator_type(it);
    
    switch(type) {
        case BSON_EOO:
            value = [NSError errorWithDomain: @"Unhandled object type: EOO" code: 0 userInfo: nil];
            break;
        case BSON_DOUBLE:
            value = [NSNumber numberWithDouble: bson_iterator_double(it)];
            break;
        case BSON_STRING:
            value = [[NSString alloc] initWithCString: bson_iterator_string(it)
                                             encoding: NSUTF8StringEncoding];
            break;
        case BSON_OBJECT:
            value = [OrderedDictionary new];
            bson_iterator_subobject_init(it, &subobject, 0);
            bson_iterator_init(&it2, &subobject);
            fill_object_from_bson(value, &it2);
            break;
        case BSON_ARRAY:
            value = [NSMutableArray array];
            bson_iterator_subobject_init(it, &subobject, 0);
            bson_iterator_init(&it2, &subobject);
            fill_object_from_bson(value, &it2);
            break;
        case BSON_BINDATA:
            value = [NSData dataWithBytes:bson_iterator_bin_data(it)
                                   length:bson_iterator_bin_len(it)];
            break;
        case BSON_UNDEFINED:
            value = [MongoUndefined new];
            break;
        case BSON_OID:
            value = [[MongoObjectId alloc] initWithOid: bson_iterator_oid(it)];
            break;
        case BSON_BOOL:
            value = [NSNumber numberWithBool:bson_iterator_bool(it)];
            break;
        case BSON_DATE:
            value = [NSDate dateWithTimeIntervalSince1970:(0.001 * bson_iterator_date(it))];
            break;
        case BSON_NULL:
            value = [NSNull null];
            break;
        case BSON_REGEX:
            pattern = bson_iterator_regex(it);
            options = bson_iterator_regex_opts(it);
            
            value = [[MongoRegex alloc] initWithPattern: [NSString stringWithCString: pattern encoding: NSUTF8StringEncoding]
                                             andOptions: [NSString stringWithCString: options encoding: NSUTF8StringEncoding]];
            break;
        case BSON_CODE:
            value = [NSError errorWithDomain: @"Unhandled object type: CODE" code: 0 userInfo: nil];
            break;
        case BSON_SYMBOL:
            value = [MongoSymbol symbolWithCString: bson_iterator_string(it)];
            break;
        case BSON_CODEWSCOPE:
            value = [NSError errorWithDomain: @"Unhandled object type: CODEWSCOPE" code: 0 userInfo: nil];
            break;
        case BSON_INT:
            value = [NSNumber numberWithInt: bson_iterator_int(it)];
            break;
        case BSON_TIMESTAMP:
            timestamp = bson_iterator_timestamp(it);
            value = [MongoTimestamp timestampWithTimeIntervalSince1970: timestamp.t];
            break;
        case BSON_LONG:
            value = [NSNumber numberWithLong: bson_iterator_long(it)];
            break;
        default:
            value = [NSError errorWithDomain: @"Unhandled value type" code: type userInfo: nil];
            break;
    }
    
    return value;
}

static void fill_object_from_bson_ext(id object, bson_iterator* it) {
    if([object isKindOfClass: [OrderedDictionary class]]) {
        while(bson_iterator_next(it)) {
            NSString* key = [NSString stringWithUTF8String: bson_iterator_key(it)];
            
            id val = object_from_bson(it);
            [object setObject: val forKey: key];
        }
    } else if([object isKindOfClass: [NSArray class]]) {
        while(bson_iterator_next(it)) {
            id val = object_from_bson(it);
            [object addObject: val];
        }
    } else {
        @throw [NSException exceptionWithName: @"CRASH" reason: @"Attempt to deserialize BSON into unhandled object type" userInfo: [NSDictionary dictionaryWithObject: object forKey: @"object"]];
    }
}

static void fill_object_from_bson(id object, bson_iterator* it) {
    fill_object_from_bson_ext(object, it);
}

#pragma mark -
#pragma mark client code

@implementation MongoDBClient {
    mongo conn;
}

#pragma mark -
#pragma mark Initialization and destruction

static void build_error(MongoDBClient* client, NSError** error) {
    mongo* conn = [client mongoConnection];

    if(error) {
        switch ( conn->err ) {
            case MONGO_CONN_SUCCESS:
                *error = nil;
                break;
            case MONGO_CONN_NO_SOCKET:
                *error = [NSError errorWithDomain: @"No socket" code: conn->err userInfo: nil];
                break;
            case MONGO_CONN_FAIL:
                *error = [NSError errorWithDomain: @"Connection failed" code: conn->err userInfo: nil];
                break;
            case MONGO_CONN_ADDR_FAIL:
                *error = [NSError errorWithDomain: @"Could not resolve host name" code: conn->err userInfo: nil];
                break;
            case MONGO_CONN_NOT_MASTER:
                *error = [NSError errorWithDomain: @"Database is not a master" code: conn->err userInfo: nil];
                break;
            default:
                mongo_cmd_get_last_error(conn, [client.database UTF8String], NULL);
                *error = [NSError errorWithDomain: [NSString stringWithCString: conn->lasterrstr encoding: NSUTF8StringEncoding] code: conn->err userInfo: nil];
        }
    }
    
    mongo_clear_errors(conn);
}
                  
+ (instancetype) clientWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error {
    return [[MongoDBClient alloc] initWithHost: host port: port andError: error];
}

- (id) initWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error {
    self = [super init];
    if(self) {
        int status;
        
        mongo_init(&conn);
        
        status = mongo_client(&conn, [host UTF8String], (int)port);
        if(status != MONGO_OK) {
            build_error(self, error);
            
            return nil;
        }
        
        self.database = @"test";
    }
    return self;
}

- (void)dealloc
{
    mongo_destroy(&conn);
}

#pragma mark -
#pragma mark Query Stuff

+ (NSDictionary*)buildQuery:(id)query {
    if (!query) {
        return [NSDictionary dictionary];
    } else if([query isKindOfClass: [MongoObjectId class]]) {
        return [NSDictionary dictionaryWithObject: query forKey: @"_id"];
    } else if([query isKindOfClass: [NSDictionary class]]) {
        return query;
    }
    
    @throw [NSException exceptionWithName: @"CRASH" reason: @"Illegal query object type" userInfo: [NSDictionary dictionaryWithObject: query forKey: @"query"]];
}


#pragma mark -
#pragma mark Database commands

- (BOOL) authenticateForDatabase:(NSString*)database withUsername:(NSString*)username password:(NSString*)password andError:(NSError**)error {
    if(mongo_cmd_authenticate(&conn, [database UTF8String], [username UTF8String], [password UTF8String])) {
        self.database = database;
        
        return YES;
    }
    
    build_error(self, error);
    return NO;
}

#pragma mark -
#pragma mark Object manipulation

- (BOOL) insert:(NSDictionary*) object intoCollection:(NSString*)collection withError:(NSError**)error {
    bson doc;
    bsonFromDictionary(&doc, object);
    int result = mongo_insert(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] UTF8String], &doc, NULL);
    bson_destroy(&doc);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(self, error);
    return NO;
}

- (BOOL) insertBatch:(NSArray*) objects intoCollection:(NSString*)collection withError:(NSError**)error {
    const bson * doc, ** docs;
    NSUInteger n = objects.count, i = 0;
    docs = (const bson **)malloc(sizeof(bson *) * n);
    for (NSDictionary* object in objects) {
        doc = (bson *)malloc(sizeof(bson));
        bsonFromDictionary((bson *)doc, object);
        docs[i++] = doc;
    }
    int result = mongo_insert_batch(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] UTF8String], docs, n, NULL, 0);
    
    for (i = 0; i < n; i++) {
        bson_destroy((bson *)docs[i]);
        free((void *)docs[i]);
    }
    free(docs);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(self, error);
    return NO;
}

-(NSArray*) find:(id)query inCollection:(NSString*)collection withError:(NSError**)error {
    return [self find:query columns:nil fromCollection:collection withError:error];
}

-(NSArray *) find:(id)query columns:(NSDictionary *)columns fromCollection:(NSString*)collection withError:(NSError**)error {
    return [self find:query columns:columns skip:0 limit:0 collection:collection withError:error];
}

-(NSArray*) find:(id)query
		 columns:(NSDictionary *)columns
			skip:(NSInteger)skip
		   limit:(NSInteger)limit
	  collection:(NSString*)collection
	   withError:(NSError**)error {
//    MongoDbCursor * cursor = [self cursorWithFind:query columns:columns skip:skip returningNoMoreThan:limit fromCollection:collection withError:error];
    MongoDbCursor * cursor = [self cursorOnCollection:collection withError:error];
    if (cursor) {
        [cursor setQuery:query];
        [cursor setColumns:columns];
        [cursor setSkip:skip];
        [cursor setLimit:limit];
        
        return [cursor toArray:error];
    }
    
    return nil;
}

-(OrderedDictionary *)findOne:(id)query inCollection:(NSString *)collection withError:(NSError **)error {
	return [self findOne:query columns:nil fromCollection:collection withError:error];
}

-(OrderedDictionary *)findOne:(id)query columns:(NSDictionary *)columns fromCollection:(NSString *)collection withError:(NSError **)error {
    MongoDbCursor * cursor = [self cursorOnCollection:collection withError:error];
    [cursor setQuery:query];
    [cursor setColumns:columns];
    [cursor setLimit:1];
    OrderedDictionary * doc = [OrderedDictionary new];
    if ([cursor next:doc withError:error]) { return doc; }
    return nil;
}

- (BOOL) update:(id) query flag:(int)flag withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    bson mongo_query;
    bson mongo_op;
    NSDictionary* to_update = [MongoDBClient buildQuery: query];

    bsonFromDictionary(&mongo_query, to_update);
    bsonFromDictionary(&mongo_op, operation);
    
    int result = mongo_update(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] UTF8String], &mongo_query, &mongo_op, flag, NULL);
    
    bson_destroy(&mongo_op);
    bson_destroy(&mongo_query);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(self, error);
    return NO;
}

- (BOOL) update:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    return [self update: query flag: MONGO_UPDATE_BASIC withOperation: operation inCollection: collection andError: error];
}

- (BOOL) upsert:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    return [self update: query flag: MONGO_UPDATE_UPSERT withOperation: operation inCollection: collection andError: error];
}

- (BOOL) updateAll:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    return [self update: query flag: MONGO_UPDATE_MULTI withOperation: operation inCollection: collection andError: error];
}

- (BOOL) remove:(id)query fromCollection:(NSString*)collection withError:(NSError**)error {
    NSDictionary* to_remove = [MongoDBClient buildQuery: query];
    bson mongo_query;
    
    bsonFromDictionary(&mongo_query, to_remove);
    int result = mongo_remove(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] UTF8String], &mongo_query, NULL);
    bson_destroy(&mongo_query);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(self, error);
    return NO;    
}

- (NSUInteger) count:(id)query inCollection:(NSString*)collection withError:(NSError**)error {
    bson mongo_query;
    NSDictionary* to_count = [MongoDBClient buildQuery: query];
    
    bsonFromDictionary(&mongo_query, to_count);
    
    int result = mongo_count(&conn, [self.database UTF8String], [collection UTF8String], &mongo_query);
    
    if(result == MONGO_ERROR) {
        build_error(self, error);
    }
    
    return result;
}

-(id)aggregateCollection:(NSString *)collection pipeline:(NSArray *)pipeline withError:(NSError**)error {
	return [self aggregateCollection:collection pipeline:pipeline options:NULL withError:error];
}

-(id)aggregateCollection:(NSString *)collection pipeline:(NSArray *)pipeline options:(NSDictionary *)options withError:(NSError**)error {
	if (!options) { options = @{}; }
	bson mongo_cmd, mongo_result;
	bson_init(&mongo_cmd);
	add_object_to_bson(&mongo_cmd, @"aggregate", collection);
	add_object_to_bson(&mongo_cmd, @"pipeline", pipeline);
	for (NSString* key in options) {
		id obj = [options objectForKey: key];
		add_object_to_bson(&mongo_cmd, key, obj);
	}
	bson_finish(&mongo_cmd);

	int cmd_result = mongo_run_command(&conn, self.database.UTF8String, &mongo_cmd, &mongo_result);

	OrderedDictionary * result;
	if(cmd_result == MONGO_ERROR) {
		build_error(self, error);
	} else {
		result = [OrderedDictionary new];
		bson_iterator it;

		[result removeAllObjects];

		bson_iterator_init(&it, &mongo_result);
		fill_object_from_bson_ext(result, &it);
	}

	bson_destroy(&mongo_cmd);
	bson_destroy(&mongo_result);
	return result ? result[@"result"] : nil;
}

#pragma mark -
#pragma mark Cursor creation methods

- (MongoDbCursor*) cursorOnCollection:(NSString*)collection withError:(NSError**)error {
	return [[MongoDbCursor alloc] initWithClient:self collection:collection withError:error];
}


#pragma mark -
#pragma mark Private methods

- (mongo*) mongoConnection {
    return &conn;
}

@end


@implementation MongoDbCursor {
    MongoDBClient * mongo_client;
    mongo * conn;

	BOOL need_teardown;
	NSMutableDictionary * query; // 查询条件，包括排序
    bson _query;
	NSDictionary * columns; // 查询列
    bson _columns;
    int skip;
    int limit;
    
    mongo_cursor cursor;
}

-(id)initWithClient:(MongoDBClient*)client collection:(NSString*)collection withError:(NSError**)error {
	if (self = [super init]) {
        mongo_client = client;
        conn = [client mongoConnection];
		query = [NSMutableDictionary new];
        mongo_cursor_init(&cursor, conn, [[NSString stringWithFormat: @"%@.%@", client.database, collection] UTF8String]);
        skip = 0;
        limit = 0;
	}
	return self;
}

- (void)dealloc {
	if (need_teardown) { [self teardown]; } // 如果已经初始化需要清理
	mongo_cursor_destroy(&cursor);
}

// 初始化c形式变量
-(void)setup {
	NSLog(@"%@ %@ %d %d", query, columns, skip, limit);
	self->need_teardown = YES;
	bsonFromDictionary(&_query, query); // 初始化查询语句
	if (!columns) columns = @{}; // 初始化查询列
	bsonFromDictionary(&_columns, columns);
	mongo_cursor_set_fields(&cursor, &_columns);
	if (skip > 0) { mongo_cursor_set_skip(&cursor, skip); }
	if (limit > 0) { mongo_cursor_set_limit(&cursor, (int)limit); }
	mongo_cursor_set_query(&cursor, &_query);
}

// 清理c形式变量
-(void)teardown {
    bson_destroy(&_query);
    bson_destroy(&_columns);
    self->need_teardown = NO;
}

-(void)setQuery:(id)query {
	if (need_teardown) { return; }
	NSDictionary* to_find = [MongoDBClient buildQuery: query];
	self->query[@"query"] = to_find;
}

-(void)setSort:(NSDictionary *)sort {
	if (need_teardown) { return; }
	if (!query[@"query"]) { query[@"query"] = @{}; }
	self->query[@"orderby"] = sort;
}

-(void)setColumns:(NSDictionary *)columns {
	if (need_teardown) { return; }
	self->columns = columns;
}

-(void)setSkip:(int)skip {
	if (need_teardown) { return; }
	self->skip = skip;
}

-(void)setLimit:(int)limit {
	if (need_teardown) { return; }
	self->limit = limit;
}

-(NSArray *)toArray:(NSError**)error {
	NSMutableArray * result = [NSMutableArray new];

	for (id doc = [OrderedDictionary new];; doc = [OrderedDictionary new]) {
		if (![self next:doc withError:error]) { break; }
		[result addObject: doc];
	}
	
	return result;
}

- (BOOL) next:(OrderedDictionary*)doc withError:(NSError**)error {
	if (!need_teardown) { [self setup]; }
	if (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_iterator it;
		[doc removeAllObjects];
		
		bson_iterator_init(&it, &cursor.current);
		fill_object_from_bson_ext(doc, &it);
		
		return YES;
	}
	
	build_error(mongo_client, error);
	return NO;
}

@end
